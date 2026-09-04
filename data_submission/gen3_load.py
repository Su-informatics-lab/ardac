#!/usr/bin/env python3
"""
gen3_load - validate-first loader for Gen3 data commons.

Pipeline per node: read -> transform -> offline validate -> link check ->
regression guard -> _dry_run -> chunked submit -> count verify.

Nothing is submitted unless every gate before it passes.
Source files are never modified.
"""
from __future__ import annotations

import argparse
import base64
import json
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

import requests
import yaml

TSV_CT = "text/tab-separated-values"

# Most Gen3 nodes are keyed by submitter_id, but project uses 'code' and
# program uses 'name'. Link columns follow the target's key, so study.tsv
# carries 'projects.code', not 'projects.submitter_id'.
UNIQUE_KEY = {"project": "code", "program": "name"}


def unique_key(node: str) -> str:
    return UNIQUE_KEY.get(node, "submitter_id")


# --------------------------------------------------------------------------
# auth
# --------------------------------------------------------------------------
def _jwt_exp(tok: str) -> float:
    payload = tok.split(".")[1]
    payload += "=" * (-len(payload) % 4)
    return float(json.loads(base64.urlsafe_b64decode(payload))["exp"])


class Auth:
    """Exchanges a Gen3 API key for access tokens, refreshing before expiry."""

    def __init__(self, commons: str, cred_path: str):
        self.commons = commons.rstrip("/")
        path = Path(cred_path).expanduser()
        data = json.loads(path.read_text(encoding="utf-8-sig"))
        if "api_key" not in data:
            raise SystemExit("%s has no 'api_key' field" % path)
        self._api_key = data["api_key"]
        self._tok = None
        self._exp = 0.0
        key_exp = _jwt_exp(self._api_key)
        if key_exp < time.time():
            raise SystemExit(
                "API key expired %s. Create a new one: portal Profile -> Create API key."
                % time.strftime("%Y-%m-%d", time.gmtime(key_exp))
            )
        self.key_expires = key_exp
        # Gen3 API keys last 30 days. For a scheduled job this is the single
        # most likely cause of an unattended failure, so warn loudly in advance.
        days_left = (key_exp - time.time()) / 86400.0
        self.key_days_left = days_left
        if days_left < 7:
            print("WARNING: Gen3 API key expires in %.1f day(s), on %s. "
                  "Scheduled runs will start failing - mint a new key."
                  % (days_left, time.strftime("%Y-%m-%d", time.gmtime(key_exp))))

    def token(self) -> str:
        if self._tok and time.time() < self._exp - 120:
            return self._tok
        r = requests.post(
            self.commons + "/user/credentials/api/access_token",
            json={"api_key": self._api_key},
            timeout=60,
        )
        if r.status_code != 200:
            raise SystemExit("token exchange failed (%s): %s" % (r.status_code, r.text[:300]))
        self._tok = r.json()["access_token"]
        self._exp = _jwt_exp(self._tok)
        return self._tok

    def headers(self) -> dict:
        return {"Authorization": "Bearer " + self.token()}


# --------------------------------------------------------------------------
# client
# --------------------------------------------------------------------------
class Client:
    def __init__(self, auth: Auth, program: str, project: str):
        self.auth = auth
        self.base = auth.commons
        self.program = program
        self.project = project
        self.proj_url = "%s/api/v0/submission/%s/%s" % (self.base, program, project)
        self._dict_cache = {}
        self._sid_cache = {}

    def _req(self, method: str, url: str, tries: int = 3, **kw):
        last = None
        # Build headers ONCE. Popping inside the loop drops Content-Type on any
        # retry, and Sheepdog then parses a TSV body as JSON.
        base_headers = dict(kw.pop("headers", {}) or {})
        for attempt in range(tries):
            headers = dict(base_headers)
            headers.update(self.auth.headers())
            try:
                r = requests.request(method, url, headers=headers, **kw)
            except requests.RequestException as exc:
                last = exc
                time.sleep(2 * (attempt + 1))
                continue
            if r.status_code == 401 and attempt < tries - 1:
                self.auth._tok = None
                continue
            if r.status_code >= 500 and attempt < tries - 1:
                time.sleep(2 * (attempt + 1))
                continue
            return r
        raise SystemExit("request failed after %d tries: %s" % (tries, last))

    def dictionary(self, node: str) -> dict:
        if node not in self._dict_cache:
            r = self._req("GET", "%s/api/v0/submission/_dictionary/%s" % (self.base, node), timeout=60)
            if r.status_code != 200:
                raise SystemExit("no dictionary entry for '%s' (%s)" % (node, r.status_code))
            self._dict_cache[node] = r.json()
        return self._dict_cache[node]

    def graphql(self, query: str) -> dict:
        r = self._req(
            "POST",
            self.base + "/api/v0/submission/graphql",
            json={"query": query},
            timeout=300,
        )
        body = r.json()
        if body.get("errors"):
            raise SystemExit("graphql error: %s" % body["errors"])
        return body.get("data") or {}

    def count(self, node: str) -> int:
        return self.graphql("{ _%s_count }" % node)["_%s_count" % node]

    def submitter_ids(self, node: str, page: int = 2000) -> set:
        """
        Unique-key values for a node type currently in the graph. The key is
        submitter_id for most nodes, but 'code' for project and 'name' for
        program - see UNIQUE_KEY.
        """
        if node in self._sid_cache:
            return self._sid_cache[node]
        key = unique_key(node)
        # order_by_asc is REQUIRED: without a stable sort Postgres returns rows
        # in arbitrary order and offset paging silently skips and repeats them.
        out = set()
        offset = 0
        expected = self.count(node)
        while True:
            q = ('{ %s(first: %d, offset: %d, order_by_asc: "%s") '
                 '{ %s } }') % (node, page, offset, key, key)
            rows = self.graphql(q).get(node) or []
            if not rows:
                break
            out.update(r[key] for r in rows)
            offset += len(rows)
            if offset >= expected:
                break
        if len(out) != expected:
            raise SystemExit(
                "paging for '%s' returned %d unique %s values but the node "
                "count is %d - refusing to validate links against an incomplete set"
                % (node, len(out), key, expected)
            )
        self._sid_cache[node] = out
        return out

    def invalidate(self, node: str) -> None:
        self._sid_cache.pop(node, None)

    def submit(self, text: str, dry: bool = False):
        url = self.proj_url + ("/_dry_run" if dry else "")
        r = self._req(
            "POST",
            url,
            data=text.encode("utf-8"),
            headers={"Content-Type": TSV_CT},
            timeout=900,
        )
        try:
            return (r.status_code in (200, 201)), r.json()
        except ValueError:
            return False, r.text[:2000]


# --------------------------------------------------------------------------
# tsv
# --------------------------------------------------------------------------
@dataclass
class Table:
    header: list
    rows: list
    path: Path
    ragged: list = field(default_factory=list)

    def col(self, name: str) -> int:
        """Column index, tolerating the '*required' template prefix."""
        for i, h in enumerate(self.header):
            if h == name or h.lstrip("*") == name:
                return i
        return -1

    def value(self, row: list, name: str) -> str:
        i = self.col(name)
        return row[i] if 0 <= i < len(row) else ""

    def text(self) -> str:
        body = "\n".join("\t".join(r) for r in self.rows)
        return "\t".join(self.header) + "\n" + body + "\n"


def read_tsv(path: Path) -> Table:
    raw = path.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        raw = raw[3:]
    lines = raw.decode("utf-8").replace("\r\n", "\n").split("\n")
    header = lines[0].split("\t")
    rows, ragged = [], []
    for n, line in enumerate(lines[1:], start=2):
        if not line.strip():
            continue
        f = line.split("\t")
        if len(f) != len(header):
            ragged.append((n, len(f)))
        rows.append(f)
    return Table(header=header, rows=rows, path=path, ragged=ragged)


# --------------------------------------------------------------------------
# transforms
# --------------------------------------------------------------------------
def apply_transforms(tbl: Table, spec: dict, log) -> Table:
    """Drop link-id columns, exclude rows, blank columns. Disk is never touched."""
    keep = []
    for i, h in enumerate(tbl.header):
        is_link_id = ("." in h) and h.endswith("id") and not h.endswith(".submitter_id")
        if not is_link_id:
            keep.append(i)
    dropped = [tbl.header[i] for i in range(len(tbl.header)) if i not in keep]
    if dropped:
        log("    dropped link-id columns: %s" % ", ".join(dropped))

    header = [tbl.header[i] for i in keep]
    rows = [[r[i] if i < len(r) else "" for i in keep] for r in tbl.rows]
    out = Table(header=header, rows=rows, path=tbl.path, ragged=tbl.ragged)

    for rule in spec.get("exclude_rows") or []:
        ci = out.col(rule["column"])
        if ci < 0:
            raise SystemExit("exclude_rows: no column '%s'" % rule["column"])
        vals = set(rule["values"])
        before = len(out.rows)
        out.rows = [r for r in out.rows if (r[ci] if ci < len(r) else "") not in vals]
        log("    excluded %d rows where %s in %s"
            % (before - len(out.rows), rule["column"], sorted(vals)))

    for cname in spec.get("blank_columns") or []:
        ci = out.col(cname)
        if ci < 0:
            log("    WARN blank_columns: no column '%s'" % cname)
            continue
        n = 0
        for r in out.rows:
            if ci < len(r) and r[ci] != "":
                r[ci] = ""
                n += 1
        log("    blanked %d values in '%s'" % (n, cname))

    return out


# --------------------------------------------------------------------------
# schema helpers
# --------------------------------------------------------------------------
def _as_list(v):
    return v if isinstance(v, list) else [v]


def _links(schema: dict):
    out = []
    for l in schema.get("links") or []:
        if l.get("subgroup"):
            for sg in l["subgroup"]:
                out.append((sg["name"], sg["target_type"], bool(sg.get("required"))))
        else:
            out.append((l["name"], l["target_type"], bool(l.get("required"))))
    return out


def _link_names(schema: dict) -> set:
    return set(n for n, _, _ in _links(schema))


# --------------------------------------------------------------------------
# validation
# --------------------------------------------------------------------------
def validate(client: Client, node: str, tbl: Table, log) -> list:
    schema = client.dictionary(node)
    props = schema.get("properties", {})
    link_names = _link_names(schema)
    errs = []

    # 1. structural corruption - the stray-tab class
    if tbl.ragged:
        shown = ", ".join("line %d has %d fields" % (n, c) for n, c in tbl.ragged[:5])
        errs.append(
            "%d malformed line(s); expected %d fields [%s] - "
            "likely a literal tab inside a free-text field"
            % (len(tbl.ragged), len(tbl.header), shown)
        )

    # 2. required properties
    for req in schema.get("required") or []:
        if req in link_names or req == "type":
            continue
        ci = tbl.col(req)
        if ci < 0:
            errs.append("missing required column '%s'" % req)
            continue
        blank = sum(1 for r in tbl.rows if not (r[ci] if ci < len(r) else ""))
        if blank:
            errs.append("required property '%s' blank on %d row(s)" % (req, blank))

    # 3. duplicate submitter_id - case-SENSITIVE on purpose
    si = tbl.col("submitter_id")
    if si < 0:
        errs.append("missing 'submitter_id' column")
    else:
        seen, dup = set(), set()
        for r in tbl.rows:
            v = r[si] if si < len(r) else ""
            if v in seen:
                dup.add(v)
            seen.add(v)
        if dup:
            errs.append("%d duplicate submitter_id(s), e.g. %s" % (len(dup), sorted(dup)[:3]))

    # 4. enum + numeric validation against the live dictionary
    for pname, pdef in props.items():
        if not isinstance(pdef, dict):
            continue
        ci = tbl.col(pname)
        if ci < 0:
            continue
        allowed = pdef.get("enum")
        ptype = pdef.get("type")
        bad = {}
        for r in tbl.rows:
            v = r[ci] if ci < len(r) else ""
            if v == "":
                continue
            if allowed:
                if v not in allowed:
                    bad[v] = bad.get(v, 0) + 1
            elif ptype and "number" in _as_list(ptype):
                try:
                    float(v)
                except ValueError:
                    bad[v] = bad.get(v, 0) + 1
        if bad:
            top = sorted(bad.items(), key=lambda kv: -kv[1])[:3]
            detail = ", ".join("%r x%d" % (v, c) for v, c in top)
            hint = ""
            if allowed:
                head = ", ".join(str(a) for a in allowed[:8])
                hint = " | allowed: %s%s" % (head, "..." if len(allowed) > 8 else "")
            errs.append("'%s' has %d invalid value(s): %s%s"
                        % (pname, sum(bad.values()), detail, hint))

    # 5. link resolution against the live graph
    for lname, target, required in _links(schema):
        key = unique_key(target)
        ci = tbl.col("%s.%s" % (lname, key))
        if ci < 0 and key != "submitter_id":
            ci = tbl.col(lname + ".submitter_id")   # tolerate either spelling
        if ci < 0:
            if required:
                errs.append("missing required link column '%s.%s' -> %s"
                            % (lname, key, target))
            continue
        referenced = set(r[ci] for r in tbl.rows if ci < len(r) and r[ci])
        if not referenced:
            if required:
                errs.append("required link '%s' is empty on every row" % lname)
            continue
        existing = client.submitter_ids(target)
        missing = referenced - existing
        if missing:
            errs.append(
                "link '%s' -> %s: %d of %d parent(s) not in graph, e.g. %s (load '%s' first)"
                % (lname, target, len(missing), len(referenced), sorted(missing)[:3], target)
            )
        else:
            log("    link %s -> %s: all %d parents present" % (lname, target, len(referenced)))

    return errs


# --------------------------------------------------------------------------
# regression guard
# --------------------------------------------------------------------------
def check_regressions(client: Client, node: str, tbl: Table, log) -> list:
    """
    Sheepdog upserts on submitter_id, and a blank field in the incoming file
    OVERWRITES a populated value in the graph with no error. This catches that
    before it happens.
    """
    si = tbl.col("submitter_id")
    if si < 0:
        return []
    incoming = {}
    for r in tbl.rows:
        if si < len(r):
            incoming[r[si]] = r
    existing = client.submitter_ids(node) & set(incoming)
    if not existing:
        log("    no existing records touched - pure insert")
        return []

    schema = client.dictionary(node)
    link_names = _link_names(schema)
    scalar = [
        p for p, d in schema.get("properties", {}).items()
        if isinstance(d, dict)
        and p not in link_names
        and tbl.col(p) >= 0
        and p not in ("id", "type", "submitter_id", "project_id")
    ]
    # Links matter more than scalars here: severing labs/aliquots is the
    # failure mode that reverts a previous submission without any error.
    # Link columns follow the TARGET's unique key - projects.code, not
    # projects.submitter_id - so resolve the column name per target.
    link_col = {}
    for lname, target, _ in _links(schema):
        key = unique_key(target)
        ci = tbl.col("%s.%s" % (lname, key))
        if ci < 0 and key != "submitter_id":
            ci = tbl.col(lname + ".submitter_id")
            key = "submitter_id"
        link_col[lname] = (ci, key)
    links_present = [n for n, (ci, _) in link_col.items() if ci >= 0]
    links_absent = [n for n, (ci, _) in link_col.items() if ci < 0]

    log("    %d existing record(s) will be UPDATED, not created" % len(existing))

    # A column can only ERASE something if it is blank somewhere in the incoming
    # file. Columns that are fully populated cannot cause a regression, so there
    # is no reason to fetch them - this is what keeps the check tractable on
    # node types with tens of thousands of records.
    def has_blank(colname: str) -> bool:
        ci = tbl.col(colname)
        if ci < 0:
            return False
        return any((r[ci] if ci < len(r) else "") == "" for r in incoming.values())

    scalar = [p for p in scalar if has_blank(p)]
    links_present = [n for n in links_present
                     if has_blank("%s.%s" % (n, link_col[n][1]))]

    if not scalar and not links_present and not links_absent:
        log("    no column in this file is ever blank - nothing can be erased, "
            "regression check skipped")
        return []
    log("    checking %d field(s) that are blank somewhere: %s"
        % (len(scalar) + len(links_present) + len(links_absent),
           ", ".join(scalar + [n + " (link)" for n in links_present + links_absent]) or "-"))

    selection = list(scalar) + [
        "%s { %s }" % (n, unique_key(dict((a, b) for a, b, _ in _links(schema))[n]))
        for n in links_present + links_absent]
    losses = {}
    ids = sorted(existing)
    for i in range(0, len(ids), 200):
        batch = ids[i:i + 200]
        lit = ", ".join(json.dumps(x) for x in batch)
        q = "{ %s(submitter_id: [%s], first: %d) { submitter_id %s } }" % (
            node, lit, len(batch), " ".join(selection))
        for rec in client.graphql(q).get(node) or []:
            row = incoming.get(rec["submitter_id"])
            if row is None:
                continue
            for p in scalar:
                cur = rec.get(p)
                if cur not in (None, "") and tbl.value(row, p) == "":
                    losses[p] = losses.get(p, 0) + 1
            for ln in links_present:
                if (rec.get(ln) or []) and tbl.value(row, "%s.%s" % (ln, link_col[ln][1])) == "":
                    losses[ln + " (link)"] = losses.get(ln + " (link)", 0) + 1
            for ln in links_absent:
                if rec.get(ln) or []:
                    key = ln + " (link column absent from file)"
                    losses[key] = losses.get(key, 0) + 1

    return [
        "'%s' is populated in the graph but blank in the file on %d record(s) - "
        "submitting would erase it" % (p, n)
        for p, n in sorted(losses.items(), key=lambda kv: -kv[1])
    ]


# --------------------------------------------------------------------------
# dry run + submit
# --------------------------------------------------------------------------
def summarize_errors(payload: dict, limit: int = 6) -> list:
    buckets = {}
    for e in payload.get("entities") or []:
        for err in e.get("errors") or []:
            key = "%s: %s" % (",".join(err.get("keys") or ["?"]), err.get("message", ""))
            uk = e.get("unique_keys") or [{}]
            sid = uk[0].get("submitter_id", "?") if uk else "?"
            buckets.setdefault(key, []).append(sid)
    out = []
    for msg, sids in sorted(buckets.items(), key=lambda kv: -len(kv[1]))[:limit]:
        out.append("    [%d rows] %s\n        e.g. %s" % (len(sids), msg, ", ".join(sids[:3])))
    for te in (payload.get("transactional_errors") or [])[:3]:
        out.append("    [transaction] %s" % te)
    return out


def schema_probe(client: Client, tbl: Table, log, n: int = 5) -> bool:
    """
    Sheepdog on some deployments cannot _dry_run an UPDATE and returns
    'service failure'. Dry runs write nothing, so we can still exercise server
    validation by submitting a few rows under synthetic submitter_ids that hit
    the create path. Same columns, same value domains - so a pass proves the
    schema is acceptable. Nothing is ever written.
    """
    si = tbl.col("submitter_id")
    if si < 0 or not tbl.rows:
        return False
    idc = tbl.col("id")
    marker = "__probe_%d" % int(time.time())
    probe = []
    for r in tbl.rows[:n]:
        row = list(r)
        row[si] = row[si] + marker
        if idc >= 0:
            row[idc] = ""
        probe.append(row)
    text = "\t".join(tbl.header) + "\n" + "\n".join("\t".join(r) for r in probe) + "\n"
    ok, payload = client.submit(text, dry=True)
    if ok and isinstance(payload, dict) and not payload.get("entity_error_count"):
        log("    schema probe passed (%d synthetic rows, nothing written)" % len(probe))
        return True
    log("    schema probe FAILED:")
    if isinstance(payload, dict):
        for line in summarize_errors(payload):
            log(line)
    else:
        log("      %s" % str(payload)[:400])
    return False


def dry_run(client: Client, tbl: Table, log) -> bool:
    ok, payload = client.submit(tbl.text(), dry=True)
    if not ok or not isinstance(payload, dict):
        # Known Sheepdog limitation: _dry_run cannot process updates to
        # existing entities. Offline validation and the regression guard have
        # already run; fall back to a create-path schema probe.
        if "service failure" in str(payload):
            log("    server dry run unavailable for UPDATES on this deployment "
                "(Sheepdog: 'service failure')")
            return schema_probe(client, tbl, log)
        log("    DRY RUN transport failure: %s" % str(payload)[:400])
        return False
    ec = payload.get("entity_error_count", 0)
    tc = payload.get("transactional_error_count", 0)
    log("    dry run: create=%s update=%s entity_errors=%s tx_errors=%s"
        % (payload.get("created_entity_count"), payload.get("updated_entity_count"), ec, tc))
    if ec or tc:
        for line in summarize_errors(payload):
            log(line)
        return False
    return True


def submit_chunked(client: Client, tbl: Table, chunk: int, log):
    created = updated = failed = 0
    total = len(tbl.rows)
    head = "\t".join(tbl.header)
    n = 0
    for off in range(0, total, chunk):
        n += 1
        part = tbl.rows[off:off + chunk]
        text = head + "\n" + "\n".join("\t".join(r) for r in part) + "\n"
        ok, payload = client.submit(text)
        if ok and isinstance(payload, dict):
            created += payload.get("created_entity_count", 0)
            updated += payload.get("updated_entity_count", 0)
            bad = payload.get("entity_error_count", 0)
            failed += bad
            if bad:
                log("    chunk %d rows %d-%d: %d entity error(s)" % (n, off, off + len(part) - 1, bad))
                for line in summarize_errors(payload, limit=2):
                    log(line)
        else:
            failed += len(part)
            log("    chunk %d rows %d-%d: FAILED %s" % (n, off, off + len(part) - 1, str(payload)[:300]))
        done = min(off + chunk, total)
        if n % 10 == 0 or done == total:
            log("    %d/%d submitted (created=%d updated=%d failed=%d)"
                % (done, total, created, updated, failed))
    return created, updated, failed


# --------------------------------------------------------------------------
# load order
# --------------------------------------------------------------------------
def check_order(client: Client, node_names: list, log) -> list:
    seen = set()
    problems = []
    for n in node_names:
        for _, target, required in _links(client.dictionary(n)):
            if required and target in node_names and target not in seen:
                problems.append("'%s' requires '%s', which is configured later" % (n, target))
        seen.add(n)
    if not problems:
        log("load order OK: %s" % " -> ".join(node_names))
    return problems


# --------------------------------------------------------------------------
# driver
# --------------------------------------------------------------------------
def run(cfg: dict, args) -> int:
    log = print
    auth = Auth(cfg["commons"], cfg["credentials"])
    client = Client(auth, cfg["program"], cfg["project"])
    log("commons : %s" % cfg["commons"])
    log("project : %s-%s" % (cfg["program"], cfg["project"]))
    log("api key valid until %s"
        % time.strftime("%Y-%m-%d %H:%M UTC", time.gmtime(auth.key_expires)))
    log("mode    : %s" % args.mode)

    nodes = [n for n in cfg["nodes"] if not args.only or n["name"] in args.only]
    if not nodes:
        log("no matching nodes in config")
        return 1

    problems = check_order(client, [n["name"] for n in nodes], log)
    for p in problems:
        log("ORDER WARNING: %s" % p)
    if problems and not args.force:
        log("refusing to continue; reorder the config or pass --force")
        return 1

    base_dir = Path(cfg.get("base_dir", ".")).expanduser()
    failures = 0

    for spec in nodes:
        name = spec["name"]
        src = Path(spec["file"]).expanduser()
        if not src.is_absolute():
            src = base_dir / src
        log("\n=== %s ===" % name)
        if not src.exists():
            log("    SKIP - file not found: %s" % src)
            failures += 1
            continue

        tbl = read_tsv(src)
        log("    source: %s (%d rows, %d cols)" % (src.name, len(tbl.rows), len(tbl.header)))
        tbl = apply_transforms(tbl, spec, log)

        errs = validate(client, name, tbl, log)
        if errs:
            log("    VALIDATION FAILED (%d problem(s)):" % len(errs))
            for e in errs:
                log("      - %s" % e)
            failures += 1
            continue
        log("    validation passed")

        if not args.no_regression_check:
            reg = check_regressions(client, name, tbl, log)
            if reg:
                log("    REGRESSION GUARD tripped:")
                for r in reg:
                    log("      - %s" % r)
                if not args.allow_regressions:
                    log("      refusing to submit; pass --allow-regressions to override")
                    failures += 1
                    continue

        if args.mode == "validate":
            continue

        if not dry_run(client, tbl, log):
            log("    DRY RUN FAILED - nothing submitted")
            failures += 1
            continue

        if args.mode == "dryrun":
            log("    dry run only - stopping before submit")
            continue

        before = client.count(name)
        chunk = spec.get("chunk_size", cfg.get("chunk_size", 500))
        c, u, f = submit_chunked(client, tbl, chunk, log)
        client.invalidate(name)
        after = client.count(name)
        log("    RESULT created=%d updated=%d failed=%d" % (c, u, f))
        log("    graph count %d -> %d" % (before, after))
        if f:
            failures += 1

    log("")
    if failures:
        log("FINISHED WITH %d FAILED NODE(S)" % failures)
        return 1
    log("ALL NODES OK")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Validate-first Gen3 loader")
    ap.add_argument("mode", choices=["validate", "dryrun", "load"],
                    help="validate = offline+graph checks; dryrun = + _dry_run; load = + submit")
    ap.add_argument("-c", "--config", required=True)
    ap.add_argument("--only", nargs="*", help="limit to these node names")
    ap.add_argument("--force", action="store_true", help="ignore load-order warnings")
    ap.add_argument("--allow-regressions", action="store_true",
                    help="submit even if blank fields would erase populated values")
    ap.add_argument("--no-regression-check", action="store_true")
    args = ap.parse_args()

    cfg = yaml.safe_load(Path(args.config).read_text(encoding="utf-8"))
    for k in ("commons", "program", "project", "credentials", "nodes"):
        if k not in cfg:
            raise SystemExit("config missing '%s'" % k)
    return run(cfg, args)


if __name__ == "__main__":
    sys.exit(main())
