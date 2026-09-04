#!/usr/bin/env python3
"""
gen3_purge - delete graph entities from a Gen3 project, safely.

Gen3 deletion is PERMANENT. There is no soft-delete, no trash, no undo.

Default mode is 'plan', which writes nothing. Actually deleting requires
typing the project code via --confirm-project, and the target commons must be
listed in the config's allow_purge list.

Deletion runs child-first: Sheepdog refuses to delete a node that still has
children, so the order is computed from the dictionary rather than hardcoded.
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen3_load import Auth, Client, _links  # noqa: E402


# --------------------------------------------------------------------------
def census(client: Client, nodes: list) -> dict:
    """Counts for every node type, in one batched query."""
    out = {}
    step = 40
    for i in range(0, len(nodes), step):
        chunk = nodes[i:i + step]
        q = "{ " + " ".join("_%s_count" % n for n in chunk) + " }"
        data = client.graphql(q)
        for n in chunk:
            out[n] = data.get("_%s_count" % n, 0)
    return out


def all_node_types(client: Client) -> list:
    sch = client._req(
        "GET", client.base + "/api/v0/submission/_dictionary/_all", timeout=120
    ).json()
    return sorted(
        n for n in sch
        if not n.startswith("_")
        and n not in ("program", "project", "root", "data_release", "metaschema")
    )


def deletion_order(client: Client, nodes: list) -> list:
    """
    Child-first ordering. An edge target -> source means 'target is a parent of
    source', so every source must be deleted before its target.
    """
    parents = {n: set() for n in nodes}
    for n in nodes:
        for _, target, _ in _links(client.dictionary(n)):
            if target in parents:
                parents[n].add(target)

    ordered, remaining = [], dict(parents)
    while remaining:
        # a node is safe to delete once nothing left still names it as a parent
        free = [n for n in remaining if not any(n in p for p in remaining.values())]
        if not free:
            # cycle (shouldn't happen in a Gen3 dictionary) - fall back
            ordered.extend(sorted(remaining))
            break
        for n in sorted(free):
            ordered.append(n)
            remaining.pop(n)
    return ordered


def entity_ids(client: Client, node: str, page: int = 1000) -> list:
    """Every entity UUID for a node type, using a stable sort."""
    out, offset = [], 0
    expected = client.count(node)
    while len(out) < expected:
        q = ('{ %s(first: %d, offset: %d, order_by_asc: "submitter_id") '
             '{ id } }') % (node, page, offset)
        rows = client.graphql(q).get(node) or []
        if not rows:
            break
        out.extend(r["id"] for r in rows)
        offset += len(rows)
    uniq = list(dict.fromkeys(out))
    if len(uniq) != expected:
        raise SystemExit(
            "collected %d unique ids for '%s' but count is %d - refusing to "
            "delete from an incomplete set" % (len(uniq), node, expected)
        )
    return uniq


def delete_ids(client: Client, ids: list, batch: int, log) -> tuple:
    deleted = failed = 0
    for i in range(0, len(ids), batch):
        part = ids[i:i + batch]
        url = "%s/entities/%s" % (client.proj_url, ",".join(part))
        r = client._req("DELETE", url, timeout=600)
        if r.status_code in (200, 204):
            deleted += len(part)
        else:
            failed += len(part)
            log("      batch %d-%d FAILED HTTP %s: %s"
                % (i, i + len(part) - 1, r.status_code, r.text[:200]))
        done = min(i + batch, len(ids))
        if (i // batch) % 10 == 0 or done == len(ids):
            log("      %d/%d deleted (failed=%d)" % (done, len(ids), failed))
    return deleted, failed


# --------------------------------------------------------------------------
def main() -> int:
    ap = argparse.ArgumentParser(description="Safely purge a Gen3 project graph")
    ap.add_argument("mode", choices=["census", "plan", "purge"],
                    help="census = counts only; plan = counts + deletion order; "
                         "purge = actually delete (requires --confirm-project)")
    ap.add_argument("-c", "--config", required=True)
    ap.add_argument("--only", nargs="*", help="limit to these node types")
    ap.add_argument("--confirm-project", help="type the project code exactly, to delete")
    ap.add_argument("--batch", type=int, default=100)
    ap.add_argument("--drop-project", action="store_true",
                    help="also delete the (now empty) project and program records")
    args = ap.parse_args()

    cfg = yaml.safe_load(Path(args.config).read_text(encoding="utf-8"))
    commons, program, project = cfg["commons"], cfg["program"], cfg["project"]
    client = Client(Auth(commons, cfg["credentials"]), program, project)

    print("commons : %s" % commons)
    print("project : %s-%s" % (program, project))
    print("mode    : %s" % args.mode)

    nodes = args.only or [n for n, v in census(client, all_node_types(client)).items() if v]
    counts = census(client, nodes)
    order = deletion_order(client, [n for n in nodes if counts.get(n)])

    print("\n=== BEFORE ===")
    total = 0
    for n in order:
        print("  %-28s %8d" % (n, counts[n]))
        total += counts[n]
    print("  %-28s %8d" % ("TOTAL", total))
    try:
        st = client._req("GET", client.base + "/index/_stats", timeout=60).json()
        print("  object storage: fileCount=%s totalFileSize=%s bytes"
              % (st.get("fileCount"), st.get("totalFileSize")))
    except Exception:
        pass

    if args.mode == "census":
        return 0

    print("\n=== DELETION ORDER (child-first) ===")
    print("  " + " -> ".join(order))
    if args.drop_project:
        print("  then: project %s, program %s" % (project, program))

    if args.mode == "plan":
        print("\nplan only - nothing deleted. To execute:")
        print("  python gen3_purge.py purge -c %s --confirm-project %s"
              % (args.config, project))
        return 0

    # ---- guards ----
    allowed = cfg.get("allow_purge") or []
    if commons not in allowed:
        print("\nREFUSING: %s is not in the config's allow_purge list." % commons)
        print("Add it deliberately to permit deletion against this host.")
        return 1
    if args.confirm_project != project:
        print("\nREFUSING: --confirm-project must be exactly '%s'." % project)
        return 1

    print("\n!!! PERMANENTLY DELETING %d entities from %s-%s at %s"
          % (total, program, project, commons))
    print("!!! Gen3 has no undo. Starting in 5s; Ctrl-C to abort.")
    time.sleep(5)

    for n in order:
        print("\n--- %s (%d) ---" % (n, counts[n]))
        ids = entity_ids(client, n)
        d, f = delete_ids(client, ids, args.batch, print)
        client.invalidate(n)
        print("    deleted=%d failed=%d remaining=%d" % (d, f, client.count(n)))

    if args.drop_project:
        for url, label in (("%s/api/v0/submission/%s/%s" % (client.base, program, project), "project"),
                           ("%s/api/v0/submission/%s" % (client.base, program), "program")):
            r = client._req("DELETE", url, timeout=120)
            print("drop %-8s HTTP %s %s" % (label, r.status_code, r.text[:150]))

    after = census(client, nodes)
    print("\n=== AFTER ===")
    tot_after = 0
    for n in order:
        print("  %-28s %8d" % (n, after.get(n, 0)))
        tot_after += after.get(n, 0)
    print("  %-28s %8d" % ("TOTAL", tot_after))
    print("\nremoved %d of %d entities" % (total - tot_after, total))
    json.dump(after, open("census_after.json", "w"), indent=1)
    return 0 if tot_after == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
