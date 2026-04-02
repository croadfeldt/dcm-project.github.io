# Replace content with fixed, deduplicated architecture

**Closes PR #7** — this PR replaces the content from PR #7 with the complete, fixed architecture documentation. All review comments from PR #7 are addressed:

## Issues fixed from PR #7

- **@jenniferubah, @gabriel-farache:** Duplicate `data-model/` and `architecture/data-model/` directories → **eliminated**. Only `architecture/data-model/` exists now (55 docs with number prefixes).
- **@gabriel-farache:** Broken links to foundations, provider-contract, policy-contract, capabilities matrix → **all fixed**. Zero broken cross-references verified.
- **@gabriel-farache:** "links broken, I think all links should be reviewed" → **done**. Full automated cross-reference scan, zero broken links.
- **@machacekondra:** Slug duplicates (e.g., `foundations.md` duplicating `00-foundations.md`) → **removed**. 53 slug duplicates eliminated.
- **@machacekondra:** K8s operator SDK imperative vs declarative concern → addressed in updated `dcm-operator-sdk-api.md`
- **@pkliczewski:** Accreditation flow diagrams, data_classification ownership, GitOps handling → all clarified in updated docs

## What changed vs PR #7

- 116 duplicate files removed (55 flat data-model copy + 53 slug dupes + 8 spec slug dupes)
- Provider count: 11 → 12 (ITSM Provider added)
- Policy count: 7 → 8 (ITSM Action added)
- data_classification enum: 5 → 8 values (phi, pci, classified added)
- All OpenAPI YAMLs synced with canonical schemas
- Capabilities Matrix deduplicated (6 duplicate summary tables removed)
- All Discussion Topics marked Resolved with cross-references

## Content structure

```
content/
├── _index.md
└── docs/
    ├── architecture/
    │   ├── data-model/            ← 55 docs + _index.md (SINGLE location)
    │   └── specifications/        ← 15 specs + 4 OpenAPI YAMLs + _index.md
    ├── capabilities-matrix.md
    ├── DISCUSSION-TOPICS.md
    ├── taxonomy.md
    ├── project-overview.md
    ├── enhancements/
    ├── implementations/
    └── schemas/
static/
└── capabilities/
    └── DCM-Capabilities-Matrix.csv
```

## How to apply

This PR only touches `content/` and `static/`. No changes to `.github/workflows/`, `hugo.yaml`, `go.mod`, `go.sum`, `Makefile`, `assets/`, or `layouts/`.
