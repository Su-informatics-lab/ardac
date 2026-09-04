#!/usr/bin/env python3
"""
gen3_pipeline - end-to-end orchestration for Gen3 submissions.

Adds, on top of gen3_load:

  * PREFLIGHT-ALL-THEN-LOAD. Every node is validated before anything is
    submitted, so a bad file in tier 6 does not leave tiers 1-5 half-loaded.
  * Projected link resolution. During preflight, parents that an EARLIER stage
    of this same run will create are counted as present - so seeding an empty
    commons validates correctly instead of failing on every child.
  * Provenance. sha256, row count and mtime of every source file, recorded in
    a run report.
  * Resumability. Completed nodes are checkpointed; --resume skips them.
  * ETL drift detection. Compares graph counts against the Guppy/Elasticsearch
    indices that power the Exploration tab and reports staleness. The ETL
    itself is admin-run and cannot be triggered through the API.

Usage:
    python gen3_pipeline.py preflight -c pipeline.yaml
    python gen3_pipeline.py run       -c pipeline.yaml
    python gen3_pipeline.py run       -c pipeline.yaml --resume 20260902T101500Z
    python gen3_pipeline.py status    -c pipeline.yaml
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
import time
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen3_load import (  # noqa: E402
    Auth, Client, Table, read_tsv, apply_transforms, validate,
    check_regressions, dry_run, submit_chunked, check_order, _links,
    unique_key,
)


def utc_stamp() -> str:
    return time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for block in iter(lambda: fh.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


class Run:
    """A pipeline run: its directory, log, state and report."""

    def __init__(self, root: Path, run_id: str):
        self.id = run_id
        self.dir = root / run_id
        self.dir.mkdir(parents=True, exist_ok=True)
        self.log_path = self.dir / "run.log"
        self.state_path = self.dir / "state.json"
        self.report_path = self.dir / "report.json"
        self.state = (
            json.loads(self.state_path.read_text(encoding="utf-8"))
            if self.state_path.exists() else {"completed": {}}
        )
        self._fh = self.log_path.open("a", encoding="utf-8")

    def log(self, msg: str = "") -> None:
        print(msg)
        self._fh.write(str(msg) + "\n")
        self._fh.flush()

    def done(self, node: str, info: dict) -> None:
        self.state["completed"][node] = info
        self.state_path.write_text(json.dumps(self.state, indent=1), encoding="utf-8")

    def is_done(self, node: str) -> bool:
        return node in self.state["completed"]

    def write_report(self, report: dict) -> None:
        self.report_path.write_text(json.dumps(report, indent=1), encoding="utf-8")


# --------------------------------------------------------------------------
def prepare(spec: dict, base_dir: Path, log) -> tuple:
    """Read + transform one node's source file. Returns (Table, provenance)."""
    src = Path(spec["file"]).expanduser()
    if not src.is_absolute():
        src = base_dir / src
    if not src.exists():
        raise FileNotFoundError(src)
    raw = read_tsv(src)
    log("    source: %s (%d rows, %d cols)" % (src.name, len(raw.rows), len(raw.header)))
    tbl = apply_transforms(raw, spec, log)
    prov = {
        "path": str(src),
        "sha256": sha256(src),
        "bytes": src.stat().st_size,
        "mtime": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(src.stat().st_mtime)),
        "rows_in_file": len(raw.rows),
        "rows_after_transform": len(tbl.rows),
    }
    return tbl, prov


def preflight(client: Client, cfg: dict, nodes: list, base_dir: Path, log) -> tuple:
    """
    Validate every node before loading any. Parents created by earlier stages of
    this run count as present, so seeding an empty commons validates correctly.
    """
    projected: dict = {}   # node type -> submitter_ids that WILL exist
    prepared: list = []
    problems: list = []

    def real_ids(node: str) -> set:
        client._sid_cache.pop(node, None)
        return client.submitter_ids(node)

    for spec in nodes:
        name = spec["name"]
        log("\n--- preflight: %s ---" % name)
        try:
            tbl, prov = prepare(spec, base_dir, log)
        except FileNotFoundError as exc:
            problems.append("%s: source file not found: %s" % (name, exc))
            continue

        # regression guard needs the REAL current state of this node type
        own_real = real_ids(name)
        client._sid_cache[name] = own_real
        reg = check_regressions(client, name, tbl, log)
        if reg and not cfg.get("allow_regressions"):
            for r in reg:
                problems.append("%s: %s" % (name, r))

        # link validation uses projected parent sets
        for _, target, _ in _links(client.dictionary(name)):
            if target == name:
                continue
            if target not in projected:
                projected[target] = set(real_ids(target))
            client._sid_cache[target] = projected[target]

        errs = validate(client, name, tbl, log)
        for e in errs:
            problems.append("%s: %s" % (name, e))
        if not errs:
            log("    validation passed")

        si = tbl.col(unique_key(name))
        new_ids = set(r[si] for r in tbl.rows if si < len(r)) if si >= 0 else set()
        projected[name] = set(own_real) | new_ids
        prepared.append((spec, tbl, prov))

    # projections must not leak into the load phase
    client._sid_cache.clear()
    return prepared, problems


def etl_drift(client: Client, log) -> dict:
    """Compare graph counts against the Guppy indices behind Exploration."""
    try:
        res = client._req(
            "POST", client.base + "/guppy/graphql",
            json={"query": '{ __type(name: "Aggregation") { fields { name } } }'},
            timeout=120).json()
        types = [f["name"] for f in res["data"]["__type"]["fields"]]
    except Exception as exc:
        log("    could not reach Guppy: %s" % str(exc)[:120])
        return {}
    drift = {}
    for t in types:
        try:
            q = "{ _aggregation { %s { _totalCount } } }" % t
            r = client._req("POST", client.base + "/guppy/graphql",
                            json={"query": q}, timeout=120).json()
            indexed = r["data"]["_aggregation"][t]["_totalCount"]
        except Exception:
            continue
        try:
            graph = client.count(t)
        except SystemExit:
            continue
        drift[t] = {"graph": graph, "indexed": indexed, "stale": graph != indexed}
    return drift


# --------------------------------------------------------------------------
def cmd_status(client: Client, log) -> int:
    log("=== graph vs Exploration index ===")
    drift = etl_drift(client, log)
    if not drift:
        return 1
    log("%-22s %10s %10s   %s" % ("TYPE", "GRAPH", "INDEXED", "STATE"))
    stale_any = False
    for t, d in sorted(drift.items()):
        state = "STALE" if d["stale"] else "in sync"
        stale_any = stale_any or d["stale"]
        log("%-22s %10d %10d   %s" % (t, d["graph"], d["indexed"], state))
    if stale_any:
        log("\nThe Exploration tab is out of date. The ETL is admin-run and cannot")
        log("be triggered through the API - ask the Gen3 ops team to run it.")
    else:
        log("\nExploration is in sync with the graph.")
    return 0


def cmd_run(client: Client, cfg: dict, args, run: Run) -> int:
    base_dir = Path(cfg.get("base_dir", ".")).expanduser()
    nodes = [n for n in cfg["nodes"] if not args.only or n["name"] in args.only]
    report = {
        "run_id": run.id,
        "started": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "commons": cfg["commons"],
        "project": "%s-%s" % (cfg["program"], cfg["project"]),
        "mode": args.mode,
        "nodes": {},
    }

    run.log("commons : %s" % cfg["commons"])
    run.log("project : %s-%s" % (cfg["program"], cfg["project"]))
    run.log("run id  : %s" % run.id)
    run.log("mode    : %s" % args.mode)

    order_problems = check_order(client, [n["name"] for n in nodes], run.log)
    for p in order_problems:
        run.log("ORDER WARNING: %s" % p)
    if order_problems and not args.force:
        run.log("refusing to continue; reorder the config or pass --force")
        return 1

    run.log("\n########## PHASE 1: PREFLIGHT ##########")
    prepared, problems = preflight(client, cfg, nodes, base_dir, run.log)
    for spec, tbl, prov in prepared:
        report["nodes"][spec["name"]] = {"provenance": prov}

    if problems:
        run.log("\nPREFLIGHT FAILED - %d problem(s). NOTHING WAS SUBMITTED:" % len(problems))
        for p in problems:
            run.log("  - %s" % p)
        report["result"] = "preflight_failed"
        report["problems"] = problems
        run.write_report(report)
        return 1
    run.log("\npreflight clean: %d node(s) ready" % len(prepared))

    if args.mode == "preflight":
        report["result"] = "preflight_ok"
        run.write_report(report)
        run.log("preflight only - stopping.")
        return 0

    run.log("\n########## PHASE 2: LOAD ##########")
    failures = 0
    for spec, tbl, prov in prepared:
        name = spec["name"]
        if run.is_done(name):
            run.log("\n--- %s: already completed in this run, skipping ---" % name)
            continue
        run.log("\n--- load: %s ---" % name)
        if not dry_run(client, tbl, run.log):
            run.log("    DRY RUN FAILED - nothing submitted for this node")
            report["nodes"][name]["result"] = "dry_run_failed"
            failures += 1
            continue
        before = client.count(name)
        chunk = spec.get("chunk_size", cfg.get("chunk_size", 500))
        c, u, f = submit_chunked(client, tbl, chunk, run.log)
        client.invalidate(name)
        after = client.count(name)
        info = {"created": c, "updated": u, "failed": f,
                "count_before": before, "count_after": after}
        report["nodes"][name].update(info)
        run.log("    created=%d updated=%d failed=%d | count %d -> %d"
                % (c, u, f, before, after))
        if f:
            failures += 1
            report["nodes"][name]["result"] = "partial"
        else:
            report["nodes"][name]["result"] = "ok"
            run.done(name, info)

    run.log("\n########## PHASE 3: VERIFY ##########")
    drift = etl_drift(client, run.log)
    report["etl"] = drift
    stale = [t for t, d in drift.items() if d["stale"]]
    for t, d in sorted(drift.items()):
        run.log("  %-22s graph=%-8d indexed=%-8d %s"
                % (t, d["graph"], d["indexed"], "STALE" if d["stale"] else "in sync"))
    if stale:
        run.log("\n  Exploration is stale for: %s" % ", ".join(sorted(stale)))
        run.log("  Ask the Gen3 ops team to run the ETL; it has no API trigger.")

    report["result"] = "ok" if not failures else "failed"
    report["finished"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    run.write_report(report)
    run.log("\nreport: %s" % run.report_path)
    run.log("FINISHED WITH %d FAILED NODE(S)" % failures if failures else "ALL NODES OK")
    return 1 if failures else 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Gen3 submission pipeline")
    ap.add_argument("mode", choices=["preflight", "run", "status"])
    ap.add_argument("-c", "--config", required=True)
    ap.add_argument("--only", nargs="*")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--resume", help="run id to resume; completed nodes are skipped")
    args = ap.parse_args()

    cfg = yaml.safe_load(Path(args.config).read_text(encoding="utf-8"))
    client = Client(Auth(cfg["commons"], cfg["credentials"]), cfg["program"], cfg["project"])

    if args.mode == "status":
        return cmd_status(client, print)

    root = Path(cfg.get("run_dir", "runs")).expanduser()
    if not root.is_absolute():
        root = Path(args.config).resolve().parent / root
    run = Run(root, args.resume or utc_stamp())
    return cmd_run(client, cfg, args, run)


if __name__ == "__main__":
    sys.exit(main())
