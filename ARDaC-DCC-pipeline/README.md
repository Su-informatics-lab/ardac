# ARDaC / AlcHepNet DCC Data Submission Pipeline

Code used by the IU Data Coordinating Center (DCC) to transform AlcHepNet
observational (OBS) and randomized-trial (RCT) source datasets into the
node-level TSV files submitted to the **ARDaC** data commons
(project `ARDaC-AlcHepNet`).

> **No participant-level data is stored in this repository.** All clinical,
> biospecimen and submission files live outside the repo and are excluded by
> `.gitignore`. See [Data layout](#data-layout).

---

## Repository layout

```
ARDaC-DCC-pipeline/
├── notebooks/     Python (Jupyter) notebooks — one per submission node
├── sas/           Legacy SAS scripts that produced the source CSV extracts
├── templates/     Empty node submission templates (headers only)
├── schema/        ARDaC dictionary schema (molecular_test.yaml)
├── requirements.txt
└── .gitignore
```

## Pipeline

Notebooks are numbered in the order they are normally run. Each writes a
`*_DCC_data_release_v<version>.tsv` submission file plus a `QC_*.tsv` file
listing records that could not be mapped.

| # | Notebook | Node | Produces |
|---|----------|------|----------|
| 01 | `01_case_node_mapping.ipynb` | `case` | OBS + RCT case node, incl. `aki_status`, `days_to_aki`, `days_to_death`, 90/180-day survival & AKI flags |
| 02 | `02_demographic_node_mapping.ipynb` | `demographic` | OBS + RCT demographic node |
| 03 | `03_audit_node_mapping.ipynb` | `audit` | OBS + RCT AUDIT questionnaire node |
| 04 | `04_followup_node_mapping.ipynb` | `follow_up` | OBS + RCT follow-up node |
| 05 | `05_followup_index_date.ipynb` | `follow_up` | Converts follow-up dates to days-since-index-date |
| 06 | `06_followup_addon.ipynb` | `follow_up` | Adds follow-up records required by newly shipped aliquots |
| 07 | `07_aliquot_inventory.ipynb` | `aliquot` | Aliquot node from the AlcHepNet sample inventory |
| 08 | `08_aliquot_shipped.ipynb` | `aliquot` | Aliquot node for shipped specimens, `labs.submitter_id` mapped from the *Sent to* PI |
| 09 | `09_molecular_test_mapping.ipynb` | `molecular_test` | Assay results for Mehal (ACE, Renin), Liangpunsakul (ORM1), Nagy (urine), Schnabl (AhR) |
| 10 | `10_molecular_test_szabo.ipynb` | `molecular_test` | Szabo anakinra / serum IL-1RA results |

### SAS scripts (`sas/`)

Upstream of the notebooks. They read the study SAS datasets and export the
OBS/RCT CSV extracts the notebooks consume.

| Script | Purpose |
|--------|---------|
| `Data for Qing_v2.sas` | Main study-data extraction |
| `CreateCSV.sas` | Exports SAS datasets to CSV |
| `AHN Data Converter.sas` / `Converter.sas` | Format/label conversion helpers |
| `GenerateDataDictionary.sas` | Builds the OBS/RCT data dictionaries |

## Data layout

The notebooks use relative paths against a data tree kept **outside** this
repository (locally: `ARDaC_organized/data/`):

```
data/
├── raw/
│   ├── ahn_source_datasets/    OBS/RCT final datasets, CSV extracts, SAS data
│   ├── biospecimen/            AlcHepNet sample inventory, shipped specimens
│   ├── pi_submissions/         Per-PI assay result files
│   └── clinical_supplemental/  Infection, liver transplant, survival extracts
├── releases/vX.Y.Z/            Submission TSVs + QC files per release
└── reference/                  Data dictionaries, node templates, PI mapping
```

Point the path constants at the top of each notebook at your local copy
before running.

## Setup

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
jupyter lab
```

## Release history

| Release | Date | Change |
|---------|------|--------|
| v1.0.0 | 2022–2023 | Initial case / demographic / follow-up / aliquot / molecular_test submission |
| v2.0.0 | 2024-12 | Rebuilt OBS + RCT nodes from the 2024 final datasets |
| v2.0.1 | 2025-05 | Follow-up dates converted to days since index date |
| v2.0.2 | 2025-05 | Added `aki_status` to the `case` node |
| v2.0.3 | 2025-05 | Added `days_to_aki`, `days_to_death`, 90/180-day survival & AKI flags; removed subject 31014 |
| v2.0.4 | 2025-06 | OBS AKI onset = earliest of `akions1dat`/`akions2dat`/`akions3dat` |
| v2.0.5 | 2025-07 | Aliquot node built from the sample inventory and shipped-specimen list |
| v2.0.6 | 2025-07 | Standardised `lab` node institution names |
| v2.0.7 | 2025-07 | `molecular_test` node for Mehal, Liangpunsakul, Nagy, Schnabl |
| v2.0.8 | 2025-07 | Follow-up add-on records for newly shipped aliquots |
| v2.0.9 | 2025-07 | `lab` node rebuilt from the institution↔PI mapping |
| v2.0.10 | 2025-07-31 | `lab` node consolidated per PI; aliquot `labs.submitter_id` remapped from *Sent to* |
| v2.0.11 | 2025-08-08 | OBS + RCT `case` node — `days_to_aki` corrections |
| v2.0.12 | 2025-08-12 | Szabo `molecular_test` node; `case_obs` survival/AKI flag backfill |

Full per-release notes: `docs/release_notes/` in the local data tree.

## Conventions

- Node files: `<node>_<cohort>_DCC_data_release_v<major>-<minor>-<patch>.tsv`
- QC files: `QC_<node>_...tsv` — unmapped records with a `reason` column
- Submission templates in `templates/` define the exact column order ARDaC expects
- Notebook outputs are stripped before commit (they can contain participant rows)

## Notes for maintainers

- Releases **v2.0.11** and **v2.0.12** included `case_obs` corrections that were
  applied without a committed notebook. If those steps need to be reproducible,
  they should be added to `01_case_node_mapping.ipynb`.
- Notebooks currently contain some absolute paths
  (`/Users/.../DCC_data_release_v2.0.0/raw_data/...`). Converting these to
  relative paths against `data/` is the main outstanding cleanup.
