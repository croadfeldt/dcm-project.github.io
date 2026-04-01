---
title: "Capabilities Map"
type: docs
weight: 8
---

The DCM Capabilities Map is an interactive reference of the 95 foundational capabilities required for DCM to perform lifecycle management. Each capability maps to three perspectives: **Consumer**, **Service Provider**, and **Platform/Admin**.

## Using the Map

- **Domain cards** — click any of the 15 domain cards to filter to that capability area; click again to clear
- **Search** — matches against capability IDs, names, descriptions, and dependencies; search `IAM-001` to find all capabilities that depend on authentication
- **Perspective filter** — extract the implementation checklist for a specific role
- **Table / Cards** toggle — dense comparison view or individual capability cards
- **MVP badges** — the 21 capabilities on the minimum viable critical path
- **Dependency tags** — clickable in table view; jumps to that capability
- **CSV download** — built into the map; also available as a [direct download](/capabilities/DCM-Capabilities-Matrix.csv)

## Capability Domains

| Prefix | Domain | Capabilities |
|--------|--------|-------------|
| IAM | Identity and Access Management | 7 |
| CAT | Service Catalog | 7 |
| REQ | Request Lifecycle Management | 10 |
| PRV | Provider Contract and Realization | 9 |
| LCM | Resource Lifecycle Management | 7 |
| DRF | Drift Detection and Remediation | 5 |
| POL | Policy Management | 7 |
| LAY | Data Layer Management | 5 |
| INF | Information and Data Integration | 6 |
| ING | Ingestion and Brownfield Management | 4 |
| AUD | Audit and Compliance | 5 |
| OBS | Observability and Operations | 5 |
| STO | Storage and State Management | 6 |
| FED | DCM Federation and Multi-Instance | 5 |
| GOV | Platform Governance and Administration | 7 |

## MVP Critical Path — 21 Capabilities

The minimum viable set for an end-to-end DCM lifecycle demonstration:

```
IAM-001 → IAM-002 → IAM-003 → IAM-007 → CAT-001
  → REQ-001 → REQ-002 → REQ-003 → REQ-004 → REQ-005 → REQ-006 → REQ-007
    → PRV-001 → PRV-002 → PRV-003 → PRV-004 → PRV-005
      → LCM-001 → DRF-001 → DRF-002 → AUD-001
```

## Downloads

| Format | Use |
|--------|-----|
| [CSV](/capabilities/DCM-Capabilities-Matrix.csv) | Import into Jira, Confluence, Notion, Airtable |
| [Standalone Map](/capabilities/map.html) | Full-page interactive map |
| [Markdown Reference](/docs/capabilities-matrix) | Full matrix with dependency map |

## Interactive Map

<div style="position:relative;width:100%;height:900px;border:1px solid rgba(255,255,255,0.1);border-radius:8px;overflow:hidden;margin-top:24px;">
<iframe
  src="/capabilities/map.html"
  style="width:100%;height:100%;border:none;"
  title="DCM Capabilities Map"
  loading="lazy">
</iframe>
</div>
