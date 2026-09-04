# data_submission

Submission tooling for loading ARDaC node TSVs into a Gen3 data commons.

This completes the chain that `data_generalization/` begins:

| Stage | Where | Produces |
|---|---|---|
| source data → node TSVs | `data_generalization/` (mapping notebooks) | node TSVs matching `node_template/` |
| **node TSVs → Gen3 commons** | **`data_submission/` (here)** | records in the graph |
| graph → Exploration tab | Gen3 ETL (admin-run) | Elasticsearch indices |

Validation-first: nothing is submitted unless every check before it passes, and
source files are never modified.

## Install

```
pip install -r requirements.txt
```

Save a Gen3 API key (portal → Profile → Create API key) to
`~/.gen3/credentials.json`. Keys last 30 days.

## Tools

### `gen3_pipeline.py` — orchestration

```
python gen3_pipeline.py preflight -c configs/pipeline.local.yaml   # validate all, load none
python gen3_pipeline.py run       -c configs/pipeline.local.yaml   # preflight → load → verify
python gen3_pipeline.py run       -c configs/pipeline.local.yaml --resume <run_id>
python gen3_pipeline.py status    -c configs/pipeline.local.yaml   # graph vs Exploration drift
```

- **Preflight-all-then-load.** Every node is validated before anything is
  submitted, so a bad file in a late tier cannot leave earlier tiers
  half-loaded.
- **Projected link resolution.** During preflight, parents that an earlier stage
  of the same run will create count as present — so seeding an empty commons
  validates correctly instead of failing on every child.
- **Provenance.** sha256, byte size, mtime and row counts of every source file
  are written to `runs/<run_id>/report.json`.
- **Resumability.** Completed nodes are checkpointed to `state.json`.
- **ETL drift detection.** Compares graph counts against the Guppy indices
  behind the Exploration tab.

### `gen3_load.py` — single-config loader

```
python gen3_load.py validate -c configs/single-node.local.yaml   # offline + graph checks
python gen3_load.py dryrun   -c configs/single-node.local.yaml   # + server _dry_run
python gen3_load.py load     -c configs/single-node.local.yaml   # + chunked submit
```

Each mode is a superset of the previous. `validate` and `dryrun` never write.

### `gen3_purge.py` — deletion

```
python gen3_purge.py census -c configs/purge.local.yaml
python gen3_purge.py plan   -c configs/purge.local.yaml
python gen3_purge.py purge  -c configs/purge.local.yaml --confirm-project <code>
```

**Gen3 deletion is permanent — no soft-delete, no trash, no undo.** `purge`
requires both the target host listed in the config's `allow_purge` (ships empty)
and `--confirm-project` typed to match the project code. Deletion runs
child-first, in an order computed from the dictionary.

## Checks performed

| Check | Catches |
|---|---|
| ragged lines | a literal tab inside a free-text field, which shifts every downstream column |
| required properties | missing or blank required fields |
| duplicate `submitter_id` | case-**sensitive**, so IDs differing only in case are not silently merged |
| enum + numeric values | values the dictionary rejects, reported with the allowed set |
| link resolution | parents that do not exist in the graph |
| regression guard | a populated field or link that the incoming file would blank |
| `_dry_run` | server-side validation, committing nothing |
| count verification | graph counts before and after |

### The regression guard

Sheepdog upserts on `submitter_id`, and **a blank field in an incoming file
overwrites a populated value in the graph with no error.** Reloading a stale
export over enriched records silently reverts them.

Before submitting, the guard compares every existing record against the file and
refuses if any populated scalar *or link* would be blanked:

```
575 existing record(s) will be UPDATED, not created
REGRESSION GUARD tripped:
  - 'days_to_test' is populated in the graph but blank in the file on 575 record(s)
  - 'labs (link)' is populated in the graph but blank in the file on 575 record(s)
  refusing to submit; pass --allow-regressions to override
```

It also warns when a link column is absent from the file but populated in the
graph. Only columns that are blank *somewhere* in the incoming file are queried,
which keeps the check tractable on node types with tens of thousands of records.

## Gen3 behaviours worth knowing

These were all found the hard way; each is handled in the code.

- **Paginating GraphQL without a sort is unsafe.** Postgres returns rows in
  arbitrary order, so offset paging skips and repeats them — a naive collector
  returned roughly two thirds of a 76k-row node. Always `order_by_asc`, and
  verify the collected set size against the node count.
- **`project` is keyed by `code`, `program` by `name`**, not `submitter_id`.
  Link columns follow the target's key, so `study.tsv` carries `projects.code`.
- **`id` is settable on data nodes** (preserving UUIDs from a previous export)
  but **not** on `project`; project UUIDs are derived deterministically and
  match anyway.
- **`_dry_run` may fail on UPDATES.** Some deployments return
  `service failure - try again later` whenever the payload touches existing
  entities, so every legitimate re-submission looks like a failure. The loader
  detects this and falls back to a *schema probe*: a few rows submitted under
  synthetic `submitter_id`s, which hit the create path and exercise the same
  validation. Dry runs write nothing, so the probe leaves no trace.
- **Chunks are atomic** — one bad row rejects its whole chunk.
- **`program` and `project` must exist before any node loads.** Create once:

  ```
  PUT /api/v0/submission/       {"type":"program","name":"...","dbgap_accession_number":"..."}
  PUT /api/v0/submission/<prog> {"type":"project","code":"...","name":"...",
                                 "dbgap_accession_number":"..."}
  ```

- **The ETL cannot be triggered through the API** (`/job/*` is blocked). Loading
  data and making it visible in Exploration are two separate events; ask the
  Gen3 ops team to run the ETL. `gen3_pipeline.py status` reports the drift.
- **API keys expire after 30 days.** The tools refuse to start on an expired key
  and warn when fewer than 7 days remain — the most likely cause of an
  unattended scheduled run failing.

## Configuration

See `configs/*.example.yaml`. Copy to `*.local.yaml` (gitignored) and fill in
real hosts and paths.

```yaml
commons: https://<your-gen3-host>
program: ARDaC
project: AlcHepNet
credentials: ~/.gen3/credentials.json
base_dir: /path/to/node/tsvs      # relative file: paths resolve from here
run_dir: runs
chunk_size: 500

nodes:                             # ORDER MATTERS - parents before children
  - name: molecular_test
    file: molecular_test.tsv
    chunk_size: 200
    blank_columns: [molecular_analysis_method]
    exclude_rows:
      - column: laboratory_test
        values: [<assay owned by another submission>]
```

| Key | Effect |
|---|---|
| `blank_columns` | clear a column the dictionary rejects |
| `exclude_rows` | drop rows another submission owns, preventing an upsert from reverting them |
| `chunk_size` | rows per request; per-node override |

| Flag | Effect |
|---|---|
| `--only A B` | limit to these nodes |
| `--force` | proceed despite load-order warnings |
| `--allow-regressions` | submit even if values would be erased |
| `--no-regression-check` | skip the guard entirely (not recommended) |
| `--resume <run_id>` | pipeline only; skip nodes already completed |

## Known dictionary gaps

- `molecular_analysis_method` has no `ELISA` value; the enum is genomics-only
  (FISH, PCR, WGS, IHC, …). ELISA assays must blank the field via
  `blank_columns` until the dictionary is updated, then reload to populate it.

## Notes

- Never commit credentials, participant data, or `runs/` output. See
  `.gitignore`.
- Source files are never modified. Transforms are applied in memory.
- Only the Gen3 submission API is used — no SDK dependency. File uploads
  (BAM, FASTQ, images) follow a different path entirely: Fence presigned URL →
  object storage → indexd GUID → a metadata node referencing the `object_id`.
  That is not covered here.
