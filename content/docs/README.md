# DCM — Data Center Management

Data Center Management (DCM) is an open-source governing framework for enterprise on-premises and sovereign cloud infrastructure. It provides a hyperscaler-like cloud experience — the operational model and self-service capabilities of a public cloud provider — on infrastructure that organizations own and control.

**GitHub:** https://github.com/dcm-project | **License:** Apache 2.0

---

## What DCM Is

DCM is the governing control plane that sits above provisioning tools, automation platforms, and infrastructure systems — making them coherent, governed, and self-service. It is not a deployment tool or a configuration manager. It is the management plane that connects them.

**[Full project description →](project-overview.md)** — what DCM is, what it does, why, who benefits, and where it operates.

---

## Architecture in One Sentence

DCM is built on three foundational abstractions — **Data**, **Provider**, and **Policy** — connected by a policy-driven event loop. Every concept maps to one of these three. See [00-foundations.md](data-model/00-foundations.md).

---

## Documentation Structure

### Foundation Documents (read these first)

| Document | Purpose |
|----------|---------|
| [project-overview.md](project-overview.md) | What DCM is, what it does, who it benefits, where it operates |
| [00-foundations.md](data-model/00-foundations.md) | The three abstractions — Data, Provider, Policy |
| [00-design-priorities.md](data-model/00-design-priorities.md) | Design priority framework — decision hierarchy for all contributors |
| [A-provider-contract.md](data-model/A-provider-contract.md) | Unified Provider base contract + 11 typed extensions |
| [B-policy-contract.md](data-model/B-policy-contract.md) | Unified Policy base contract + 7 output schemas |

### Data Model (55 documents)

| Range | Coverage |
|-------|---------|
| 00–05 | Context, foundations, entity types, four states, layering, ownership, resource types |
| 06–12 | Resource/service entities, dependencies, grouping, relationships, information providers, storage providers, audit |
| 13–19 | Ingestion, policy profiles, universal groups, universal audit, deployment, webhooks, auth providers |
| 20–27 | Registry governance, advanced information providers, federation, notifications, operational models, control plane, accreditation, governance matrix |
| 28–35 | Federated contribution, scoring model, meta provider, credential provider, authority tier, event catalog, API versioning, session revocation |
| 36–42 | Internal component auth, scheduled requests, dependency graph, self-health, standards catalog, operational reference, ITSM integration |
| 43–49 | Provider callback auth, Kessel evaluation, consistency review, workload analysis, accreditation monitor, location topology, implementation specifications |
| A, B | Unified Provider Contract, Unified Policy Contract |

### Specifications (15 documents)

Consumer API · Admin API · Operator Interface · OPA Integration · Flow GUI · Admin GUI · Consumer GUI · Provider GUI · Registration · Examples · Use Case Examples · Kubernetes Compatibility · Operator SDK · RHDH Integration · CNCF Strategy

### Example Implementations

| Path | Purpose |
|------|---------|
| [implementations/example-01-summit-demo/](implementations/example-01-summit-demo/) | Summit 2026 Demo — Intelligent Placement, Rehydration, Application as a Service on OpenShift |


### AI Model Prompt

[DCM-AI-PROMPT.md](DCM-AI-PROMPT.md) — load into any AI model to provide full project context. 103 sections covering the complete architecture, all decisions, implementation guidance, and working instructions.

---

## Key Numbers

| Metric | Value |
|--------|-------|
| Foundational abstractions | 3 (Data, Provider, Policy) |
| Provider types | 11 (unified base contract + typed capability extensions) |
| Policy types | 7 (unified base contract + typed output schemas) |
| Entity lifecycle states | 4 (Intent · Requested · Realized · Discovered) |
| Capabilities | 299 across 38 domains |
| Data model documents | 55 |
| Specifications | 15 |
| Consumer API paths | 63 |
| Admin API paths | 57 |
| Unresolved architectural questions | 0 |

---

## Core Principles

1. **Declarative** — data describes desired state, not procedures
2. **API-First** — every capability available via standard AEP-aligned API
3. **Policy-Governed** — all business logic through the Policy Engine, never hard-coded
4. **Idempotent** — applying the same data multiple times produces the same result
5. **Immutable if Versioned** — published versions never change; changes produce new versions
6. **Provider-Agnostic** — DCM defines contracts, not implementations
7. **GitOps-Native** — intent and policy artifacts are Git-native
8. **Federated** — all authorized actor types contribute within permitted scope
9. **Compliance by Construction** — audit trail, provenance, and sovereignty enforcement are structural

---

## Capabilities Matrix

[DCM-Capabilities-Matrix.md](DCM-Capabilities-Matrix.md) — 299 capabilities across 38 domains including: Identity and Access, Service Catalog, Request Lifecycle, Provider Contract, Resource Lifecycle, Drift Detection, Policy Management, Data Layer, Information Integration, Ingestion, Audit, Observability, Storage, Federation, Platform Governance, Accreditation, Zero Trust, Governance Matrix, Scoring Model, Meta Provider, Credential Provider, Authority Tier, Event Catalog, API Versioning, Session Revocation, Internal Component Auth, Scheduled Requests, Dependency Graph, Self-Health, Operational Reference, Web Interfaces, ITSM Integration, Provider Callback Auth, Workload Analysis, Accreditation Monitoring, and Location Topology.

---

## How DCM Works

DCM's runtime is a **policy-driven event loop**: every data state change triggers Policy Engine evaluation, policies produce typed outputs (approve/halt/enrich/route/recover), outputs invoke Providers or produce new Data, and new Data triggers new events. There is no hard-coded pipeline — the pipeline is the sum of active Policies.

A request flows through: **intent declared** → **layer assembly** (Core Layers + Service Layers + Transformation Policies inject and lock required fields) → **policy evaluation** (Validation, GateKeeper, Placement) → **Requested State written** → **dispatch to Provider** (Naturalization → execution → Denaturalization) → **Realized State written** → **ongoing drift monitoring**.

Every business rule is a Policy artifact stored in Git, versioned, tested in shadow mode before activation, and enforced deterministically. Adding a new approval step, changing placement rules, or building a named workflow requires writing a policy — not changing code.

Providers wrap existing automation (Ansible, Terraform, vendor APIs). They implement one base contract and translate between DCM's unified data model and their native format. Organizations do not replace their automation — they govern it.

**[Full technical walkthrough →](project-overview.md#how-dcm-works)**

---

## Ethos

Four design priorities — applied in order when they conflict:

1. **Security is the baseline.** Security properties are present in every profile. Profiles control enforcement strictness and operational burden — not whether the property applies. The `minimal` profile is "security with minimal overhead" — not "minimal security."

2. **The governed path must also be the easy path.** Self-service is how governance scales. If consuming resources through DCM is harder than raising a ticket, teams route around it. The entire scoring, auto-approval, and visual policy authoring system exists to make the governed path the path of least resistance.

3. **Compliance is constructed, not audited.** Audit evidence, field-level provenance, and sovereignty enforcement are structural products of every operation — not reconstructed from logs after the fact. An auditor can answer "who touched this data and when" directly from DCM's audit store.

4. **No silent behavior.** Every operation produces an observable artifact. Every state transition produces an audit record. Every policy decision produces a typed output. When something goes wrong, "what happened and why" is always answerable from the system's own output.

**[Full ethos document →](project-overview.md#ethos)**

---


## Contributing

DCM is open-source. Community contributions welcome via GitHub at https://github.com/dcm-project
