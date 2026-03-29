---
title: "DCM Documentation Index"
type: docs
weight: 0
---

Data Center Management (DCM) is an open-source governing framework for enterprise on-premises and sovereign cloud infrastructure. It provides a hyperscaler-like cloud experience on infrastructure that organizations own and control.

**GitHub:** https://github.com/dcm-project

---

## Architecture in One Sentence

DCM is built on three foundational abstractions — **Data**, **Provider**, and **Policy** — connected by a policy-driven event loop. Every concept maps to one of these three. See [00-foundations.md](data-model/00-foundations.md).

---

## Documentation Structure

### Foundation Documents (read these first)
| Document | Purpose |
|----------|---------|
| [00-foundations.md](data-model/00-foundations.md) | The three abstractions — Data, Provider, Policy |
| [A-provider-contract.md](data-model/A-provider-contract.md) | Unified Provider base contract + 11 typed extensions |
| [B-policy-contract.md](data-model/B-policy-contract.md) | Unified Policy base contract + 7 output schemas |

### Data Model (28 documents)
| Range | Coverage |
|-------|---------|
| 00–05 | Context, entity types, four states, layering, examples, ownership, resource types |
| 06–11 | Resource/service entities, dependencies, grouping, relationships, information providers, storage providers |
| 12–17 | Audit, ingestion, policy profiles, universal groups, universal audit, deployment |
| 18–23 | Webhooks, auth providers, registry governance, advanced information providers, federation, notifications |
| 24–28 | Operational models, control plane components, accreditation, governance matrix, federated contribution |

### Specifications (10 documents)
Consumer API · Admin API · Operator Interface · OPA Integration · Flow GUI · Registration · Examples · Kubernetes Compatibility · Operator SDK · CNCF Strategy

### AI Model Prompt
[DCM-AI-PROMPT.md](DCM-AI-PROMPT.md) — paste into any AI model to provide full project context. 62 sections, 4,330 lines.

---

## Key Numbers

| Metric | Value |
|--------|-------|
| Foundational abstractions | 3 (Data, Provider, Policy) |
| Provider types | 11 (unified base contract + typed capability extensions) |
| Policy types | 7 (unified base contract + typed output schemas) |
| Control plane components | 9 |
| Four lifecycle states | Intent · Requested · Realized · Discovered |
| Capabilities | 126 across 20 domains |
| Data model documents | 33 (28 numbered + 3 foundation + 2 examples) |
| Specifications | 10 |
| Unresolved questions | 0 |

---

## Core Principles

1. **Declarative** — data describes desired state, not procedures
2. **API-First** — every capability available via standard API
3. **Policy-Governed** — all business logic through the Policy Engine, never hard-coded
4. **Idempotent** — applying the same data multiple times produces the same result
5. **Immutable if Versioned** — published versions never change; changes produce new versions
6. **Provider-Agnostic** — DCM defines contracts, not implementations
7. **GitOps-Native** — intent and policy artifacts are Git-native
8. **Federated by Default** — all authorized actor types contribute within permitted scope
9. **Easy to use · Easy to implement · Easy to extend**

---

## Capabilities Matrix

[DCM-Capabilities-Matrix.md](DCM-Capabilities-Matrix.md) — 126 capabilities across 20 domains including: Identity and Access, Service Catalog, Request Lifecycle, Provider Contract, Resource Lifecycle, Drift Detection, Policy Management, Data Layer, Information Integration, Ingestion, Audit, Observability, Storage, Federation, Platform Governance, Accreditation, Zero Trust, Governance Matrix, Drift Reconciliation, and Federated Contribution.

**Minimum viable end-to-end set:** 21 capabilities (IAM-001 → AUD-001 critical path).

---

## Contributing

DCM is open-source. Community contributions welcome via GitHub at https://github.com/dcm-project
