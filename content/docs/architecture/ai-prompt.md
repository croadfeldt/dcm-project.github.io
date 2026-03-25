# DCM Project — AI Model Prompt Script

**Purpose:** This script provides an AI model with the full context needed to participate effectively in DCM project work. It should be provided at the start of any AI-assisted session involving DCM architecture, documentation, code, or design work.

**Usage:** Paste this document into the AI model's context at the start of a session. Follow with the specific task or question.

**Maintainers:** Update this document whenever significant architectural decisions are made, new concepts are established, or open questions are resolved.

**Last Updated:** 2026-03

> **⚠️ Active Development Notice**
> The DCM data model, architecture, and specifications are under active development. Decisions documented here represent current best understanding — open questions are explicitly tracked and will be resolved over time. When working on DCM, always check the DISCUSSION-TOPICS.md for unresolved questions before making assumptions.

---

## SECTION 1 — PROJECT IDENTITY

You are assisting with the **DCM (Data Center Management)** project, an open-source strategic framework developed by the Red Hat FlightPath team developed by the Red Hat FlightPath Team.

**Key facts:**
- DCM is NOT a provisioning tool — it is a **governing framework**
- DCM is a **top-down orchestration and policy enforcement layer**
- DCM enables enterprises to achieve a "Private Cloud" / "Sovereign Cloud" experience with public cloud efficiencies on-premises
- DCM is **API-first, data-driven, and policy-governed**
- DCM is inspired by Kubernetes' declarative control plane model
- GitHub: https://github.com/dcm-project
- Website: https://dcm-project.github.io

**Authors:** Chris Roadfeldt (Principal Architect), Ryan Goodson (Senior Principal Architect), Adam Seeley (Global Director) — Red Hat FlightPath.

**Vision:** To make life better for all customers, internal teams, and future-looking entities.

**Mission:** Seamlessly manage the complete lifecycle of all data center infrastructure by providing a policy-governed, data-driven, and unified platform to enable and ensure sovereignty.

---

## SECTION 2 — THE PROBLEM DCM SOLVES

Organizations face these core challenges that DCM addresses:

1. **Fragmented Operations** — disparate tools, no unified management, functionality trapped in monoliths
2. **No Single Source of Truth** — multiple CMDBs diverge, no trustworthy representation of infrastructure state
3. **High Time-to-Market** — a single VM lifecycle may be managed by dozens of teams; firewall changes can take weeks
4. **The Private Cloud Gap** — "Private Cloud" ≠ "On-Premises Compute"; a true private cloud requires networking, storage, identity, catalog, FinOps, observability, auditing, and risk management
5. **Drift and State Discrepancy** — no reconciliation between discovered inventory and intended inventory
6. **Sovereignty Requirements** — organizations must enforce data residency, compliance, and operational control across their infrastructure

**The definitional clarification DCM makes:**
- Private Cloud ≠ On-Premises Compute
- Private Cloud > On-Premises IaaS
- Private Cloud = Hyperscale experience for on-premises infrastructure

---

## SECTION 3 — FOUNDATIONAL PRINCIPLES

These three constraints apply to ALL data, entities, and operations in DCM **universally and without exception:**

### 3.1 Declarative
Data describes **what something is or should be**, not how to achieve it. Every entity is a complete, self-describing statement of state. The procedures required to achieve that state are the concern of the Service Provider, not the data model.

### 3.2 Idempotent in Operation
Applying the same data to the same system multiple times must always produce the same result. No operation on DCM data should have different outcomes based on how many times it has been applied.

### 3.3 Immutable if Versioned
Once a version of any entity is published, it cannot be modified. Changes produce a new version. Previous versions remain intact and accessible forever.

---

## SECTION 4 — THE DCM DATA MODEL

**The data model is the most foundational element of DCM.** Everything in DCM acts on data in some way — reading, validating, triggering, enriching, gatekeeping, parsing, transforming, or comparing. The data model is the lingua franca — the API between all components.

### 4.1 Universal Identity Requirement
Every data object in DCM **must have a UUID**. This applies without exception to: resource definitions, catalog items, data layers, policies, policy sets, components, service providers, consumers, requests, and all other entities. UUIDs are used for provenance anchoring, dependency mapping, audit fidelity, and cross-state correlation.

### 4.2 The Four States
DCM tracks every resource through four distinct states. Together they provide complete visibility into what was wanted, what was asked for, what was built, and what actually exists.

| State | Description | Store | Created By |
|-------|-------------|-------|------------|
| **Intent** | What the consumer wants — raw declared desire before any processing | Intent Store | Consumer (Web UI / API) |
| **Requested** | Fully processed, policy-validated, enriched payload submitted to a provider | Request Store | Request Payload Processor |
| **Realized** | What was actually provisioned, returned by the provider in DCM unified format | Realized Store | Service Provider (via Denaturalization) |
| **Discovered** | What actually exists, as independently interrogated by a provider during discovery | Discovered Store | Service Provider (via Discovery) |

**Key operations across states:**
- **Drift Detection:** Discovered State vs. Realized State
- **Request Validation:** Requested State vs. Policy definitions
- **Intent Portability:** Intent State → re-process through current policies → new Requested State
- **Brownfield Ingestion:** Discovered State → enrichment → Realized State (lifecycle ownership)

**State lifecycle flow:**
```
Consumer Request → INTENT → (Policy Engine) → REQUESTED → (Service Provider) → REALIZED
                                                                                     ↕ compare
                                                              DISCOVERED ────────► Drift Detection
```

### 4.3 Field-Level Provenance and Data Lineage
This is a **structural requirement** of the data model — not a logging concern.

For any field, at any point in the pipeline, it must be possible to determine:
- What is the current value?
- Where did this value originate? (catalog item, layer, policy, consumer input, discovery)
- Has it been modified? If so — what changed it, which entity (by UUID), when, what was the previous value, and why?
- What is the complete chain of custody from origin to current value?

**Provenance is carried within the data object itself** — co-located with the data, not in an external log.

Every component that modifies data carries a **provenance obligation** — it must record its UUID, operation type, timestamp, and reason for every field it modifies. This is non-optional.

Conceptual provenance structure per field:
```yaml
field_name:
  value: <current value>
  metadata:
    override: <allow|constrained|immutable>
    basis_for_value: <human-readable — why this value was set>
    baseline_value: <original default before any override>
    locked_by_policy_uuid: <uuid — if constrained or immutable>
    locked_at_level: <global|tenant|user>
    constraint_schema: <JSON Schema — if constrained>
  provenance:
    origin:
      value: <original value>
      source_type: <catalog_item|base_layer|intermediate_layer|service_layer|policy|consumer|discovery|provider>
      source_uuid: <uuid>
      timestamp: <ISO 8601>
    modifications:
      - sequence: 1
        previous_value: <value before>
        modified_value: <value after>
        source_type: <policy|layer|component|provider>
        source_uuid: <uuid>
        operation_type: <enrichment|transformation|validation|gatekeeping|override|lock|grant>
        actor: <actor type that performed this>
        timestamp: <ISO 8601>
        reason: <human-readable>
```
The `metadata` block is set exclusively by the Policy Engine. `operation_type: lock` is used when a GateKeeper sets `override: immutable`. `operation_type: grant` is used when a trusted_grant is issued.

### 4.4 Universal Versioning
All entities, definitions, and data objects in DCM follow one versioning scheme: **Major.Minor.Revision**

| Component | Trigger |
|-----------|---------|
| **Major** | Breaking changes to the contract |
| **Minor** | Additive changes, backward compatible |
| **Revision** | Data/configuration changes, no contract impact |

This applies universally to: resource types, layers, policies, catalog items, provider registrations, registry entries, and all other definitions.

### 4.5 Universal Artifact Status Lifecycle
Every DCM artifact — layers, policies, resource types, catalog items, provider registrations — follows a five-status lifecycle:

| Status | Meaning | Applied? | Shadow? |
|--------|---------|---------|---------|
| `developing` | In development | No — dev mode only | No |
| `proposed` | Submitted for review/validation | No | Yes — policies shadow-execute against real traffic, output captured not applied |
| `active` | Live and governing | Yes | Yes — audit records |
| `deprecated` | Being phased out, replacement available | Yes — with warning | Yes |
| `retired` | End of life | No | No — terminal |

**Status transitions:** `developing → proposed → active → deprecated → retired`
Deprecated artifacts must include: replacement UUID, deprecation reason, migration guidance, sunset date.

**Previously:** The model had only `active → deprecated → retired`. The `developing` and `proposed` statuses were added to support the full artifact development workflow — especially the shadow execution validation model for policies.

### 4.6 Artifact Metadata Standard
Every DCM artifact carries a universal metadata block — applies to all artifacts without exception:
- `uuid` — immutable, DCM-assigned at creation
- `handle` — human-readable stable ID: `{domain}/{layer_type}/{name}` e.g. `platform/core/security-cpu-limits`
- `version` — Major.Minor.Revision
- `status` — five-status lifecycle (Section 4.5)
- `created_by` — audit record (who submitted): UUID optional + display_name required
- `owned_by` — accountability record (who is responsible, receives notifications): UUID optional + display_name required
- `created_via` — ingestion path: `pr | api | migration | system`
- `modifications` — append-only history of all changes with who/when/why

**Contact modes:** UUID+display_name when Identity Provider registered; display_name+email standalone/air-gapped. Both supported.

### 4.7 The Four Provider Types
All four provider types follow the same base contract (registration, health check, trust, provenance emission):

| Type | Purpose | DCM Owns Result? |
|------|---------|-----------------|
| **Service Provider** | Realizes resources — KubeVirt, VMware, AAP, Terraform | Yes |
| **Information Provider** | Serves authoritative external data DCM references but does not own | No — external system is authoritative |
| **Meta Provider** | Composes multiple providers into higher-order services | Yes |
| **Storage Provider** | Persists DCM state — GitOps stores, event streams, audit store, observability | Yes — DCM is authoritative |

---

## SECTION 5 — THE FOUR STATES AND STORAGE MODEL

### 5.1 The Four States

Every DCM entity exists across four independently maintained state records:

| State | Question | Store Type | Characteristics |
|-------|----------|------------|----------------|
| **Intent State** | What did the consumer ask for? | GitOps | Immutable, branched, PR reviewed, CI/CD triggered |
| **Requested State** | What was approved and dispatched? | GitOps | Immutable, committed, CD triggered, full provenance |
| **Realized State** | What did the provider actually build? | Event Stream | Append-only, entity-keyed stream, high-frequency |
| **Discovered State** | What actually exists right now? | Event Stream (ephemeral) | Machine-generated, drift detection source |

### 5.2 Storage Architecture — Contract, Not Implementation

DCM defines store **contracts** — what capabilities, guarantees, and obligations each store must satisfy. Implementation technology is a deployment choice. Storage Provider is the fourth formal DCM provider type.

```
GitOps Stores:        Intent, Requested, Layers, Policies
Event Stream Stores:  Realized, Discovered, Audit events
Search Index:         Queryable projection of GitOps stores (non-authoritative)
Audit Store:          Compliance-grade, immutable, long-retention
Observability Store:  Time-series metrics, traces, logs
```

### 5.3 The Entity UUID — Universal Key
The entity UUID is assigned at Intent State creation and links the entity across all four states and all stores. Given an entity UUID, DCM can reconstruct the complete lifecycle history from any store.

### 5.4 CI/CD Integration
GitOps stores are the natural CI/CD integration point:
- **CI pipeline** fires on branch/update: policy pre-validation (dry run), cost estimation, sovereignty check, auto-approve evaluation — results posted as PR comments
- **CD pipeline** fires on merge: layer assembly, full policy evaluation (binding), provider dispatch
- **Third rail — direct API ingress**: bypasses PR workflow, not governance. Same pipeline, no human review unless required by policy.

### 5.5 Rehydration — Three Sources, Six Modes

Rehydration uses a prior state record as the starting point for a new request. Governance always applies — rehydration is a new request, not a shortcut.

**Three sources:** Intent Store (full assembly runs), Requested Store (assembly skipped, governance runs), Realized Store (provider fields stripped, assembly skipped, governance runs)

**Two axes — six modes:**

| Mode | re_evaluate | policy_version | Use Case |
|------|-------------|----------------|----------|
| Faithful | false | current | Same provider, current governance |
| Provider-Portable | true | current | New provider, current governance |
| Historical Exact | false | pinned | Same provider, historical governance (audit evidence) |
| Historical Portable | true | pinned | New provider, historical governance |

**Placement flag on Requested/Realized rehydration:**
```yaml
placement:
  re_evaluate: false   # Honor original provider selection (default)
  # re_evaluate: true  # Strip provider, run placement policies fresh
governance:
  apply_all_policies: true  # Always true — never skippable
  policy_version: current   # current | pinned (pinned requires elevated auth)
```

**Named concept:** Provider-Portable Rehydration — rehydration with provider selection re-evaluated through current placement policies and current provider landscape.

**Partial Q54 resolution:** Policies set placement constraints. The placement component selects the specific provider within those constraints. Policies never name a specific provider — that would be portability-breaking.

### 5.6 Audit, Provenance, and Observability — Three Distinct Concerns

| Concern | What It Is | Audience | Retention |
|---------|-----------|----------|-----------|
| **Provenance** | Field-level data lineage embedded in every payload | System | Permanent — part of the data |
| **Audit** | Compliance-grade queryable record of all actions | Auditors, Compliance | Regulatory period (7+ years FSI) |
| **Observability** | Real-time metrics, traces, logs | SRE, Platform Engineers | Operational window (90 days) |

Audit is a **separate component** fed by provenance events emitted by all Storage Providers (contractual obligation). Surfaced through the DCM API Gateway — not a separate endpoint.

All DCM capabilities — catalog, requests, entities, policies, audit, observability — are surfaced through a **unified API Gateway hierarchy**.

---

## SECTION 6 — DATA LAYERS AND THE ASSEMBLY PROCESS

### 6.1 What is a Layer?
A Layer is a **declarative, immutable, versioned unit of data** that contributes fields to a merged payload. Layers do not execute — they declare. Every layer has a UUID, follows universal versioning, is immutable once published, carries a parent entity reference, and contributes field-level provenance metadata for every field it sets.

### 6.2 Layer Types

| Layer Type | Scope | Ownership | Purpose |
|------------|-------|-----------|---------|
| **Base Layer** | Type-agnostic or type-scoped | DCM platform / implementor | Foundation entity — minimum required fields and defaults. Every chain starts here. |
| **Core Layers** | Type-agnostic by default | Infrastructure teams / implementors | Organizational, infrastructure, and contextual data applicable across all resource types (DC, Zone, Rack, Region, Environment) |
| **Intermediate / Customization Layers** | Type-agnostic or type-scoped | Organizational teams / domain owners | Organizational hierarchy and deployment context overrides stacked between Core and Service Layers |
| **Service Layers** | **Must be type-scoped** | Service Providers / service domain teams | Service-specific configuration for a specific Resource Type. Invalid without declared type scope. |
| **Request Layer** | Scoped to requested Resource Type | Consumer | Consumer's declared intent. Becomes Intent State on submission. Has higher precedence than all data layers. |
| **Policy Layers** | Scoped by policy domain | Policy creators / security / compliance | Governance layer — operates on the assembled payload after data layers are merged |

### 6.3 Service Layer Type Scope
Service Layers must declare their Resource Type scope and scope inheritance behavior:
```yaml
type_scope:
  resource_type_uuid: <uuid>
  resource_type_fully_qualified_name: <Category.ResourceType>
  scope_inheritance: <exact|descendants>
  # exact: applies only to the declared Resource Type
  # descendants: applies to the declared type and all child types via inheritance
```

### 6.4 Precedence Order
From lowest to highest precedence:
```
1. Base Layer                    (foundation defaults)
2. Core Layers                   (organizational and infrastructure context)
3. Intermediate/Customization    (organizational hierarchy overrides)
4. Service Layers                (service-specific configuration)
5. Request Layer                 (consumer intent — overrides all data layers)
6. Transformation Policies       (enrich / modify — additive)
7. Validation Policies           (pass/fail — no field modification)
8. GateKeeper Policies           (highest authority — overrides everything including consumer input)
```

### 6.5 Policy Layer Behavior
- **Validation** — checks data against rules, does not modify. Pass/fail. Failure rejects the request.
- **Transformation** — enriches or modifies the payload. Adds missing fields, applies standards. Recorded in provenance.
- **GateKeeper** — highest authority. Can override any field including consumer-declared values. Used for sovereignty constraints, security mandates, and hard compliance rules. All overrides recorded in provenance.

### 6.6 Assembly Process (Seven Steps)
1. **Intent Capture** — Request Layer stored as Intent State in Intent Store. No modification.
2. **Layer Resolution** — Processor identifies applicable layers by Resource Type and organizational context.
3. **Layer Merge** — Layers merged in precedence order. Each field records source layer UUID in provenance.
4. **Request Layer Application** — Consumer values applied last in data layer merge. Overrides recorded in provenance.
5. **Transformation Policies** — Enrich and modify payload. Provenance recorded per field.
6. **Validation Policies** — Check payload. Failures reject request with reason.
7. **GateKeeper Policies** — Hard overrides applied. Provenance recorded. Payload stored as Requested State.

### 6.7 Key Rules
- Core Layers are type-agnostic — applied to every request regardless of Resource Type
- Service Layers must be type-scoped — only applied when request Resource Type matches declared scope
- A Service Layer without a declared type scope is invalid and must be rejected
- Conflicting fields at same precedence: resolved by priority if declared; CONFLICT ERROR if not declared or equal
- Conflicts detected at **ingestion time** — not assembly time — all active layers are pre-validated conflict-free
- All layer modifications are recorded in field-level provenance

### 6.8 Layer Identity — Domain, Handle, Priority

**Layer Domain** — organizational home and authorization:

| Domain | Scope | Can Override |
|--------|-------|-------------|
| `system` | DCM built-in | Nothing above |
| `platform` | All tenants | tenant, service, provider |
| `tenant` | Single tenant | service, provider within tenant |
| `service` | Service Provider | provider |
| `provider` | Catalog Item | Nothing above |

**Layer Handle** — `{domain}/{layer_type}/{name}` — human-readable stable ID, unique in DCM, mirrors Git path.
Example: `platform/core/security-cpu-limits` → `dcm-layers/platform/core/security-cpu-limits/v1.2.0.yaml`

**Priority Schema** — deterministic conflict resolution:
- Format: `{int}.{int}.{int}...` — unlimited depth, higher value = higher priority
- `900.10` beats `800.10`; `900.20` beats `900.10`; no ceiling — infinite upward insertability
- Priority label: semantic context only, does not affect ordering
- Reference taxonomy (advisory, not enforced): 900=Compliance, 800=Security, 700=Sovereignty, 600=Operations, 500=Platform, 400=Service, 300=Organization, 200=Site, 100=Custom
- Organizations needing authority above all standard categories use `1000.*` or higher — no renumbering required

**Immutable ceiling model (Q51 resolved):**
- `override: immutable` (default) — protected by execution order; first policy to lock wins during this execution
- `override: immutable` + `immutable_ceiling: absolute` — protected against all future policies; attempted overrides are rejected and logged in audit

### 6.9 Artifact Metadata Standard

**Every DCM artifact** carries a universal artifact metadata block. Universal — not optional, not per-artifact.

**Five artifact statuses:**

| Status | Applied? | Shadow? | Key Behavior |
|--------|---------|---------|-------------|
| `developing` | No | No | Dev mode only |
| `proposed` | No | Yes (policies) | Shadow output captured for validation |
| `active` | Yes | Yes (audit) | Live and governing |
| `deprecated` | Yes (warning) | Yes | Replacement available |
| `retired` | No | No | Terminal — cannot be used |

**Key fields:** `created_by` (audit — who submitted), `owned_by` (accountability — who gets notified), `created_via` (pr/api/migration/system — audit quality), `modifications` (append-only history)

**Contact — two modes:** UUID+display_name when IdP registered; display_name+email in standalone/air-gapped mode. Both fully supported.

**Proposed shadow (policies):** Shadow output captured per request as `proposed_evaluation_record` — what the policy would have done, never applied. Feeds Validation Dashboard.

**Notifications to `owned_by.notification_endpoint`:** layer conflict, deprecation, provider deregistered, policy violation, drift, high-impact shadow, approaching sunset.

### 6.10 Field Override Control — Two Categories

**Structural Rules (Request Payload Processor — non-overridable DCM System behavior):**
- Layer immutability — a published version cannot be modified
- A child layer cannot remove a parent field — only override its value
- Layer precedence order is fixed — Base → Core → Intermediate → Service → Request → Policy
- Circular references and typeless Service Layers are always rejected

**Business Rules (Policy Engine — configurable):**
The Policy Engine is the **sole authority** for field override control. It sets override control metadata on fields using the standard policy mechanism. Data layers and the Request Payload Processor never set override control.

### 6.11 Field Override Control — Three Levels

**Design Principle: Simple by default, powerful when needed. Use only the level you need.**

**Level 1 — No declaration (default)**
Field is fully overridable by any actor. Zero configuration. Covers the majority of fields.

**Level 2 — Simple declaration**
Single `override` property — sufficient for most governed fields:
- `override: allow` — explicit allow (same as default, self-documenting)
- `override: constrained` — any actor can override within `constraint_schema`
- `override: immutable` — no actor can override at any level

**Level 3 — Matrix declaration**
Full per-actor permission matrix for fields requiring nuanced governance:

```yaml
override_matrix:
  default: allow
  inheritance: restrict_only
  actors:
    - actor: policy.global    # can_expand: true
    - actor: policy.tenant    # can_expand: true (within global ceiling)
    - actor: policy.user      # can_expand: false
    - actor: consumer_request # can_expand: false
    - actor: process_resource # permission: deny by default
    - actor: provider         # can_expand: false
    - actor: sre_override     # can_expand: false
    - actor: admin_override   # can_expand: true (within scope)
  trusted_grants:
    - granted_to_uuid: <uuid>
      actor_type: process_resource
      permission: allow
      granted_by_policy_uuid: <uuid>
      expires: <ISO 8601 — optional>
```

**Where declared:** Resource Type Specification sets the ceiling. Catalog Item can only restrict further. Policy Engine applies at runtime within those bounds.

**Expansion rules:** `policy.global`, `policy.tenant`, `admin_override` can grant expansion. `policy.user`, `consumer_request`, `provider` can never expand. `process_resource` and `sre_override` denied by default — require trusted grant.

**Actor extensibility:** Custom actors default to `deny`, require explicit grants, follow universal versioning and deprecation model.

---

## SECTION 7 — RESOURCE TYPE HIERARCHY AND SERVICE CATALOG

The Resource Type Hierarchy is how DCM achieves **resource portability** — expressing what a consumer needs independently of which specific provider delivers it.

### 7.1 The DCM Resource Type Registry
- DCM maintains an official registry of standard Resource Types
- Registry is **open** — community and implementors can propose new types
- All registry entries are **vendor-neutral by hard requirement**
- Exception: `exclusive` classification where one provider is the sole implementor
- Registry entries are versioned, immutable once published, and can be deprecated

### 7.2 Four Hierarchy Levels

**Level 1 — Resource Type Category** (broadest)
Organizational container. Examples: `Compute`, `Network`, `Storage`, `Platform`, `Security`, `Observability`, `Data`

**Level 2 — Resource Type** (abstract)
Defines a class of resource. Must be vendor-neutral. Examples: `Compute.VirtualMachine`, `Network.FirewallRule`

**Level 3 — Resource Type Specification** (standard contract)
The data contract for a Resource Type — all fields with types, constraints, and portability classifications.

**Level 4 — Provider Catalog Item** (concrete)
A specific provider's implementation of a Resource Type Specification.

### 7.3 Portability Classification
Every field in every Resource Type Specification carries a portability classification:

| Classification | Meaning | Portability |
|---|---|---|
| `universal` | All providers must support it | Fully portable |
| `conditional` | Some providers support it | Portable to supporting providers |
| `provider-specific` | One provider only | Portability-breaking — must be marked |
| `exclusive` | One provider for entire tech stack | Not applicable — declared |

**Hard requirements:**
- All `universal` fields MUST be supported by ALL implementing providers
- `provider-specific` fields MUST be marked portability-breaking
- Consumers MUST be warned when their request contains portability-breaking fields
- Portability warning enforcement is **organizational policy**: `block` | `warn` | `allow`

### 7.4 Inheritance
Resource Types support inheritance. Rules:
- Child inherits ALL parent fields — none can be removed or redefined
- Child may add new fields
- Child portability can only be equal to or more restrictive than parent
- Each level is independently versioned with parent UUID reference

### 7.5 Request Resolution — Specificity Narrowing
Provider selection is **never explicit**. It emerges from progressive specificity:
```
Resource Type declared        → matches all providers for that type
Universal fields specified    → still matches all providers
Conditional fields specified  → narrows to supporting providers
Provider-specific fields used → narrows to single provider (portability warning issued)
Placement/sovereignty applied → final provider selected by Policy Engine
```

---

## SECTION 8 — RESOURCE/SERVICE ENTITIES

### 8.1 Core Terminology

| Term | Definition |
|------|-----------|
| **Resource/Service Request** | What a consumer submits to DCM — the declared intent to consume a resource or service. The consumer side of the transaction. |
| **Resource/Service Entity** | The "thing" produced by a provider as a result of fulfilling a request — the allocation made real. The provider side of the transaction. |

### 8.2 DCM as Authoritative Owner — Always
DCM is ALWAYS the system of record for Resource/Service Entity data. DCM is ALWAYS authoritative for the resource definition. DCM ALWAYS owns the lifecycle. This applies regardless of the operational ownership model.

Providers are **custodians** of the underlying infrastructure — they are not the system of record.

### 8.3 Four Ownership Models

| Model | Description | Example |
|-------|-------------|---------|
| **Allocation** | Provider retains internal ownership. Consumer owns the Entity (the allocation). Provider has reclaim rights on decommission. | VM, Container, IP Address |
| **Whole Allocation** | Entire resource allocated as indivisible unit. Provider retains ownership. Consumer has exclusive use. Not subdivided or shared. | Dedicated Bare Metal (provider-owned) |
| **Full Transfer** | Provider transfers complete ownership to consumer's DCM Tenant. Consumer controls full lifecycle including decommission. | Transferred Bare Metal, Licensed asset |
| **Hybrid Transfer** | Ownership can transfer multiple times. Current owner is always exactly one DCM Tenant. Every transfer is tracked and auditable. | Bare Metal reallocated between tenants |

Every Provider Catalog Item must declare which ownership model(s) it supports.

### 8.4 Resource/Service Entity Lifecycle
```
REQUESTED → PENDING → PROVISIONING → REALIZED → OPERATIONAL
                                                      │
                                          ┌───────────┼───────────┐
                                          ▼           ▼           ▼
                                      DEGRADED   MAINTENANCE  SUSPENDED
                                                      │
                                                DECOMMISSIONING → DECOMMISSIONED
```
`DECOMMISSIONED` is the only terminal state. Records are retained permanently and are immutable.

### 8.5 Process Resource Entities
A distinct entity class for ephemeral execution resources — automation jobs, playbooks, pipelines, workflows.
- Ephemeral lifecycle — exists for duration of execution
- Execution record retained permanently after terminal state
- Must belong to a DCM Tenant
- Must be in provenance chain of any Resource/Service Entity they affect
- Lifecycle: `REQUESTED → INITIATED → EXECUTING → COMPLETED | FAILED | CANCELLED`

### 8.6 Provider Capacity Model — Three Modes
- **Mode 1 — Dynamic Query**: DCM queries provider on-demand during request processing
- **Mode 2 — Provider Registration (preferred)**: Provider registers capacity on configurable schedule — default minimum twice daily
- **Mode 3 — Provider Denial (mandatory)**: Provider validates fulfillment capability before executing. Denies with `INSUFFICIENT_RESOURCES`. Triggers immediate DCM capacity rating update.

All three modes are always available. Mode 3 is mandatory for all providers.

### 8.7 Provider Lifecycle Events
Any provider event affecting Resource/Service Entity availability or operational characteristics MUST be reported to DCM immediately. This is a non-negotiable contractual obligation.

When DCM receives a provider event, the Policy Engine evaluates and determines response:
`ALERT | REVERT | UPDATE_DEFINITION | INVESTIGATE | DECOMMISSION | ESCALATE`

DCM acts as the **Tenant advocate** — protecting Tenant interests in all provider interactions.

---

## SECTION 9 — SERVICE DEPENDENCIES

### 9.1 Why Dependencies Must Be Declared in Advance
Dependencies must be declared in the data model — not discovered at runtime. This is required for:
- **Auditability** — complete dependency graph known before execution
- **Cost Analysis** — full resource footprint known before provisioning
- **Placement** — Policy Engine needs complete resource footprint for optimal placement
- **Idempotency** — same request always produces same dependency graph

### 9.2 Hybrid Dependency Declaration Model

**Type-Level Dependencies (Resource Type Specification)**
- Portable and provider-agnostic
- Apply to all Provider Catalog Items implementing that Resource Type
- Use Resource Type UUIDs — not provider-specific references
- Required for all implementations

**Provider-Specific Dependencies (Provider Catalog Item)**
- Provider-specific additions beyond type-level dependencies
- Must be marked `portability_breaking: true`
- Visible to Policy Engine and consumers as portability warnings

### 9.3 Dependency Types and Cardinality

| Type | Behavior |
|------|---------|
| `hard` | Must be realized before/alongside dependent. Failure fails dependent. |
| `soft` | Preferred but not blocking. Failure recorded but does not block. |
| `conditional` | Required only if specific request payload conditions are met. |

| Cardinality | Description |
|-------------|-------------|
| `one_to_one` | Exactly one dependency resource required |
| `one_to_many` | One or more dependency resources required |
| `one_to_optional` | Zero or one dependency resource |
| `one_to_range` | Specific numeric range required |

### 9.4 Dependency Graph
When a request is processed, a complete **Dependency Graph** is constructed — all resources that must be created including all transitive dependencies. Each resource appears exactly once. Circular references are invalid.

The graph is attached to the Requested State. Nodes updated to REALIZED as providers fulfill each dependency.

### 9.5 Dependency Payload Passing
When a dependency is realized, its Realized State payload is passed to the dependent provider. The dependent resource's Requested State payload is enriched with the dependency entity's UUID and relevant realized data. Recorded in field-level provenance with `source_type: dependency_payload`.

### 9.6 Failure Handling — Configurable per Request or Policy

| Mode | Behavior |
|------|---------|
| `fail_all` | Any hard dependency failure fails entire request. Partially realized nodes decommissioned. |
| `fail_dependent` | Failure fails only the dependent and its dependents. Independent branches continue. |
| `retry` | Failed dependencies retried with same or alternative provider. |
| `partial_complete` | Request marked partially complete. Failed nodes flagged for retry or manual intervention. |

### 9.7 Rehydration and Dependencies
Rehydration uses **Intent State** — not Realized State — to reconstruct the dependency graph. This ensures current policies and standards are applied. Resources can be rehydrated to a different provider as long as type-level dependencies are satisfiable.

---

## SECTION 10 — RESOURCE GROUPING AND TENANCY

### 10.1 DCM Tenant — Mandatory First-Class Ownership

Every Resource/Service Entity must belong to exactly one DCM Tenant. This is a **non-overridable DCM System Policy**.

Tenant provides: ownership, isolation, cost attribution, policy scope, drift detection scope, rehydration scope, audit scope, sovereignty boundary.

**Ownership vs Consumption:** A resource belongs to one Tenant (owner) but can be consumed by multiple Tenants via the Service Catalog. Consumption is tracked through service requests — not Tenant membership.

### 10.2 Resource Groups — Flexible Composable Grouping

Resource Groups function like **structured tags** — a resource accumulates group memberships describing its context from multiple dimensions simultaneously.

**Two classes — equal capability:**
- **DCM Default Resource Group** — built-in, standard grouping mechanism
- **Custom Resource Group** — implementor-defined, tied to business structures (CostCenter, BusinessUnit, RegulatoryScope, etc.)

Both implement the same **Resource Group Interface**.

### 10.3 Multi-Group Membership
A resource can belong to multiple groups across all classes. Membership constraints are configurable per group definition:
- `exclusive: true` — resource can only belong to one group of this type at a time
- `exclusive: false` — resource can belong to multiple groups of this type
- Organizational policies can further restrict multi-group membership

### 10.4 Nesting
Groups that declare `nesting: true` can contain other groups as members. Nesting is configurable per group definition. Circular nesting is invalid. Child groups inherit policy scope from parent groups.

### 10.5 DCM System Policies for Grouping

| Policy | Rule |
|--------|------|
| `TEN-001` | Every Resource/Service Entity must belong to exactly one DCM Tenant |
| `TEN-002` | A Tenant must exist before resources can be created in it |
| `GRP-003` | Circular nesting in Resource Groups is invalid |
| `GRP-004` | Custom Resource Groups must implement the full Resource Group Interface |
| `GRP-005` | Exclusive membership groups must reject violating membership requests |

---

## SECTION 11 — ENTITY RELATIONSHIPS

### 11.1 Design Principle
**Single model. Minimum variance. Simple by default.** Every relationship in DCM — VM requires storage, application contains web server, resource references Business Unit — uses the same structure. No separate binding mechanism, no separate dependency graph, no separate business data association. One universal model.

### 11.2 Universal Relationship Structure
Every relationship is a first-class data object with its own UUID. Recorded **bidirectionally** — on both participating entities. The same `relationship_uuid` appears on both sides.

```yaml
relationship:
  relationship_uuid: <uuid — same on both sides>
  this_entity_uuid: <uuid>
  this_role: <role this entity plays>
  related_entity_uuid: <uuid of related entity or external reference>
  related_entity_type: <internal|external>
  related_entity_role: <role the related entity plays>
  information_provider_uuid: <uuid — if external>
  information_type: <e.g., Business.BusinessUnit — if external>
  relationship_type: <see types below>
  nature: <constituent|operational|informational>
  lifecycle_policy:
    on_related_destroy: <destroy|retain|detach|notify>
    on_related_suspend: <suspend|retain|detach|notify>
    on_related_modify: <cascade|ignore|notify>
  status: <active|suspended|terminated>
  provenance: <standard provenance>
```

### 11.3 Relationship Types (fixed vocabulary)

| Type | Inverse | Meaning |
|------|---------|---------|
| `requires` | `required_by` | Cannot function without the related entity |
| `depends_on` | `dependency_of` | Uses the related entity but can degrade without it |
| `contains` | `contained_by` | Logical container for the related entity |
| `references` | `referenced_by` | References without owning or requiring |
| `peer` | `peer` | Equal relationship |
| `manages` | `managed_by` | Has lifecycle management authority |

### 11.4 Relationship Nature

| Nature | Lifecycle Policy | Example |
|--------|-----------------|---------|
| `constituent` | Required | VM requires its boot disk |
| `operational` | Required | Web server depends on load balancer |
| `informational` | Not applicable | Resource references its Business Unit |

### 11.5 Lifecycle Policy Authority
```
Resource Type Specification default (lowest)
  → Provider Catalog Item default
    → Consumer declaration
      → DCM System Policy (non-overridable)
```

### 11.6 Relationship Roles
Standard roles: `compute`, `storage`, `networking`, `security`, `database`, `web`, `app`, `cache`, `queue`, `pipeline`, `identity`, `monitoring`, `business_unit`, `cost_center`, `product_owner`, `regulatory_scope`

Custom roles: extensible — organizations register domain-specific roles (e.g., `trading_engine`, `risk_calculator`). Semantic labels only — do not affect system behavior.

### 11.7 Where Relationships Are Declared
- **Resource Type Specification** — declares possible relationships (ceiling)
- **Catalog Item** — declares actual relationships for an offering (can only restrict)
- **Request time** — consumer declares instance relationships
- **External data** — same model for Business Unit, Cost Center, Person, etc.

### 11.8 Bundled Declaration Expansion
When consumer bundles storage/networking in a compute request:
1. **Processor** creates Resource/Service Entity stubs (PENDING) with UUIDs
2. **Processor** creates bidirectional Relationship records
3. **Processor** applies lifecycle policy hierarchy
4. **Policy Engine** validates binding type and lifecycle policy
5. **Service Provider** provisions natively, returns realized payloads in DCM format
6. **DCM** updates entities PENDING → REALIZED, activates relationships

### 11.9 The Entity Relationship Graph
All relationships form a traversable graph. Used for: rehydration (full graph traversal), cost rollup (accumulates across constituent relationships), drift detection (discovered vs realized graph comparison), decommission ordering (lifecycle policies at each edge), placement (pre-realization footprint), impact analysis (change propagation).

### 11.10 Supersedes Dependency Graph
The Entity Relationship model unifies the previously separate dependency graph concept. The dependency graph IS the relationship graph at pre-realization time — same structure, different lifecycle state.

---

## SECTION 12 — INFORMATION PROVIDERS

### 12.1 Purpose
Information Providers are a first-class DCM provider type that serves authoritative external data DCM needs to reference but does not own (HR systems, finance systems, CMDBs). DCM references but never caches or owns external data.

### 12.2 Four Provider Types

| Type | Purpose | DCM Owns Result? |
|------|---------|-----------------|
| **Service Provider** | Realizes resources — KubeVirt, VMware, AAP, etc. | Yes |
| **Information Provider** | Serves authoritative external data DCM references but does not own | No — external system is authoritative |
| **Meta Provider** | Composes multiple providers into higher-order services | Yes |
| **Storage Provider** | Persists DCM state — GitOps stores, event streams, audit, observability | Yes — DCM is authoritative |

All four provider types follow the same base contract: registration, health check, trust, and provenance emission obligation.

### 12.3 Same Contract as Service Providers
Information Providers follow the same registration, health check, trust, and capacity model as Service Providers where applicable. Capacity = query capacity (requests/sec). Naturalization/Denaturalization = translating native format to DCM unified format.

### 12.4 Standard vs Extended Data
- **Standard data** — DCM-defined fields. Used for lookups, policy evaluation, operational decisions. Portable across all implementations.
- **Extended data** — organization-defined fields. Carried in payload for downstream consumers. DCM core does not rely on extended data for operational decisions.

### 12.5 Stable External Key Model
```yaml
external_entity_reference:
  uuid: <dcm-generated — stable internal anchor>
  external_uuid: <stable uuid from external system>
  information_provider_uuid: <uuid>
  information_type_name: Business.BusinessUnit
  lookup_method:
    primary_key: external_uuid
    fallback_keys:
      - field: code
        value: "BU-PAY"
  display_name: <non-authoritative — UI convenience only>
  verification:
    last_verified: <ISO 8601>
    verification_status: <verified|stale|unverifiable|deactivated>
```
DCM UUID wraps external UUID — if external system changes its UUID, only this record changes. All relationships remain valid.

### 12.6 Three-Mode Verification
- **Mode 1** — DCM-initiated scheduled verification (configurable frequency)
- **Mode 2** — Information Provider push (contractual obligation — same as SP lifecycle events)
- **Mode 3** — On-demand verification fallback when reference is stale

### 12.7 Information Types in the Registry
Same DCM registry as Resource Types — distinguished by category prefix:
- `Business.*` — BusinessUnit, CostCenter, ProductOwner
- `Identity.*` — Person, ServiceAccount, Group
- `Compliance.*` — RegulatoryScope, AuditFramework
- `Operations.*` — Runbook, SLA, SupportContract

---

## SECTION 13 — KUBERNETES SUPERSET STRATEGY

### 13.1 Position
DCM is a **superset of Kubernetes** — extending Kubernetes' declarative, controller-based model upward to provide unified management across multiple clusters, infrastructure types, and organizational boundaries. Kubernetes manages the execution plane. DCM manages the management plane.

### 13.2 What DCM Adds Beyond Kubernetes

| Capability | Kubernetes | DCM |
|------------|-----------|-----|
| Scope | Single cluster | Multi-cluster, multi-infrastructure |
| Tenancy | Namespace isolation | First-class Tenant ownership model |
| Policy | RBAC + admission webhooks | Full Policy Engine — Validation/Transformation/GateKeeper |
| Data lineage | Not provided | Field-level provenance on all data |
| Cost attribution | Not provided | Full lifecycle cost analysis |
| Drift detection | Controller reconciles | Four-state model — Intent/Requested/Realized/Discovered |
| Service catalog | Not provided | Self-service catalog with RBAC-governed presentation |
| Sovereignty | Not provided | Placement constraints, compliance evidence |
| Non-Kubernetes resources | Not provided | VMware, bare metal, OpenStack managed through same model |

### 13.3 Operator Integration — The Adapter Pattern
Kubernetes operators become DCM Service Providers through the DCM Operator Interface Specification. The pattern:
```
DCM Control Plane → Operator Adapter (Service Provider) → Kubernetes Operator → Cluster
```
The adapter handles Naturalization (DCM Requested State → Kubernetes CR) and Denaturalization (CR status → DCM Realized State).

### 13.4 Native Support Strategy
Goal: influence the Kubernetes operator ecosystem to adopt DCM as a superset. Three-phase approach:
1. **Generic Operator Adapter** — declarative field mappings, no operator changes needed
2. **DCM Operator SDK** — Go library, adds DCM support with minimal code changes, one day to Level 1
3. **Upstream contributions** — contribute DCM support directly to priority operators (KubeVirt, CloudNativePG, Strimzi, Cert-Manager)

### 13.5 Conformance Levels
- **Level 1** — Registration + health + basic status reporting. One day with SDK. Unlocks: catalog, health monitoring, basic cost tracking.
- **Level 2** — + Capacity + lifecycle events + full realized payloads + field mappings. 2-3 days. Unlocks: placement, drift detection, cross-cluster management.
- **Level 3** — + Sovereignty + provenance + discovery + decommission confirmation. 3-5 days. Unlocks: full audit chain, brownfield ingestion, sovereignty enforcement.

### 13.6 CNCF Strategy
Target CNCF Sandbox submission. FSI consortium (leading FSI consortium members) provides multi-organization adopter evidence. Key artifacts needed before submission: DCM Operator Interface Spec v1.0, SDK v0.1.0, KubeVirt Level 2 reference implementation, conformance test suite, governance model.

### 13.7 Key Kubernetes-to-DCM Concept Mappings
| Kubernetes | DCM |
|-----------|-----|
| CRD | Resource Type Specification |
| Custom Resource | Requested State → Realized State |
| Reconciliation loop | Realization + Drift Detection |
| Namespace | DCM Tenant boundary |
| ownerReference | Entity Relationship (contains/contained_by) |
| Finalizers | Lifecycle policy enforcement |
| Labels/Annotations | DCM entity metadata |
| Kubernetes conditions | DCM lifecycle states |

---

## SECTION 14 — WEBHOOK INTEGRATION

### 14.1 Purpose
Webhooks provide a **push-based notification model** for consumers, providers, and external systems that cannot or do not poll DCM. They complement the API-first model and Message Bus by enabling real-time outbound event notifications.

### 14.2 Architectural Position
Webhooks are an **Egress capability** — outbound notifications from DCM to external systems. They fit within the existing Egress zone alongside the Messaging Protocol and Interoperability API.

### 14.3 Core Use Cases

| Audience | Example Events |
|----------|---------------|
| **Consumer/CI-CD** | Resource request transitions to REALIZED; Entity enters DEGRADED state; dependency graph node fails |
| **Provider** | New request payload dispatched; discovery request initiated; decommission requested |
| **External Systems** | ITSM notification on request create/update/complete; FinOps platform on Entity realization/decommission |
| **Operational** | Provider capacity below threshold; unsanctioned change detected; GateKeeper policy fired |
| **Compliance** | Sovereignty constraint applied; ownership transfer initiated/completed; audit-relevant policy triggered |

### 14.4 Key Design Principles (Established)
- Webhook events are **typed and versioned** — consistent with DCM universal versioning model
- Webhook payloads carry **provenance information** — sufficient context to trace back to the originating request, entity, and policy
- **Policy Engine integration** — the Policy Engine can fire webhooks as a response action (alongside ALERT, REVERT, UPDATE_DEFINITION, etc.)
- Webhook registrations are **scoped** — consumer-facing webhooks registered via Consumer API; provider-facing webhooks registered via Provider Registration
- Events should align with a **DCM Event Type Registry** — extensible, versioned, following the same registry model as Resource Types

### 14.5 Open Design Questions
See [DISCUSSION-TOPICS.md — TOPIC-001](DISCUSSION-TOPICS.md) for the full list of design questions. Key unresolved items:
- Webhook registration model and API
- Full event taxonomy and registry structure
- Payload format — full state vs reference + event type
- Authentication model for outbound webhook calls
- Retry and reliability obligations
- Ordering guarantees
- Relationship to the Message Bus
- Whether provider webhook support is mandatory in the Provider Contract
- Tenant vs platform-level scoping

### 14.6 Status
**Under active discussion** — see DISCUSSION-TOPICS.md TOPIC-001. Do not make implementation assumptions until design questions are resolved.

---

## SECTION 15 — DCM ARCHITECTURE COMPONENTS

### 15.1 The Five Domains
DCM is organized into five horizontal domains from bottom to top:

| Domain | Persona | Content |
|--------|---------|---------|
| **Data Center Domain** | CIO | Physical infrastructure — Compute, GPU, RAM, Storage, Networking, HSM |
| **Resource Domain** | SRE | Declarative resources — VMs, containers, pods, clusters, external IPs |
| **Control Plane Domain** | CTO | Policy, Validate & Placement, Audit, Orchestration |
| **Application Domain** | Engineering | Data Center Pipeline, CI/CD |
| **Value Domain** | Line of Business | Software Build & Deploy, business outcomes |

### 15.2 Control Plane Components

| Component | Purpose |
|-----------|---------|
| **API Gateway** | Central clearing house — ingress for consumers, egress to providers |
| **Job Queue** | Manages asynchronous task execution |
| **Request Payload Processor** | Assembles, enriches, and merges data layers into complete request payload |
| **Policy Engine** | Validates, transforms, gates, and enriches data based on policy definitions |
| **IDM / IAM** | Authentication and identity — source of truth for personas and RBAC |
| **Service Catalog** | Presents available services/resources per RBAC policy |
| **Orchestration** | Coordinates multi-step workflows and manages request lifecycle |
| **Cost Analysis** | Tracks service costs throughout the full resource lifecycle |
| **Audit** | Records all operations — reads provenance intrinsic to data objects |
| **Observability** | Monitoring, logging, and metrics |
| **Resource Discovery** | Interrogates providers to discover existing resource state |
| **Message Bus** | Async communication between control plane and external systems |

### 15.3 Data Stores — Storage Provider Model

All DCM stores are **Storage Providers** — DCM defines the contract, implementors choose the technology. Four store contract types:

| Contract Type | Stores | Key Characteristics |
|--------------|--------|-------------------|
| **GitOps Store** | Intent, Requested, Layer, Policy | Branch/PR/merge semantics, immutable history, CI/CD hooks, Search Index companion |
| **Event Stream Store** | Realized, Discovered, Audit events | Append-only, entity-keyed streams, replayable, high-throughput |
| **Audit Store** | Compliance audit records | Compliance-grade, immutable, long-retention (7+ years FSI), hash-verified |
| **Observability Store** | Metrics, traces, logs | Time-series, short-to-medium retention, OpenTelemetry format |

**Search Index** — non-authoritative queryable projection of GitOps stores. Rebuilt from Git on demand. Git always wins on disagreement.

**DCM-internal caches** (Layer Cache, Policy Cache, Catalog Cache) — not Storage Providers. Non-authoritative, cache-aside pattern, invalidated on writes.

### 15.4 Consumer Ingress
- **Web UI** — web interface for human consumers
- **Consumer API** — API interface for programmatic consumers and external systems

### 15.5 Egress
- **Messaging Protocol** — protocol translation to external systems
- **Interoperability API** — common API spec and data model for Service Provider communication

---

## SECTION 16 — SERVICE PROVIDERS

### 16.1 Core Principle
DCM is **not concerned with how a provider accomplishes its work** — only with:
- The data that crosses the boundary (conformant data in, conformant data out)
- The trust and contractual obligations the provider has declared and honored

### 16.2 Naturalization and Denaturalization
- **Naturalization** — provider transforms DCM unified data into its own tool-specific format for execution
- **Denaturalization** — provider transforms tool-specific results back into DCM unified format for return to the control plane

### 16.3 Provider Contract Dimensions
Providers must honor a multi-dimensional contract:

**Data Contract**
- Accept DCM unified data format
- Return complete DCM unified data format (not just status codes)
- Implement Naturalization and Denaturalization

**Sovereignty Contract**
- Explicitly declare which sovereignty dimensions they can satisfy
- Declaration is binding — if declared, it must be delivered
- Sovereignty dimensions: Data/Content, Operational, Security/Compliance, Placement/Mobility

**Capability Contract**
- Declare which Resource Types they implement
- Declare which lifecycle operations they support (CRUD + Discovery)
- Declare what they do NOT support

**Lifecycle Contract**
- Support all declared lifecycle states
- Participate in Discovery when requested
- Report Realized State completely and accurately
- Handle drift detection requests

**Trust Contract** *(validation mechanism — to be detailed)*
- Providers must be validated and certified to participate
- Trust is established at onboarding
- Chain of trust must be maintained

**Compliance/Audit Contract**
- Maintain audit trail of actions taken
- Make audit data available to DCM in DCM unified format
- Must not take actions outside of DCM-initiated requests (for managed resources)

**SLA/Operational Contract**
- Response time expectations
- Availability requirements
- Error handling and reporting standards
- Retry and idempotency guarantees

### 16.4 Provider Types
- **Atomic Providers** — manage a single fundamental resource type (VM, IP, VLAN, container)
- **Meta Providers** — compose multiple providers as components of their own service
- **Process Providers** — purely process-based (no infrastructure resource, but a workflow or automation)
- **Real-world providers** are typically combinations of all three

---

## SECTION 17 — THE POLICY ENGINE

### 17.1 Purpose
The Policy Engine is the **single authoritative logic gate for all business rules** in DCM. It enforces governance without embedding business logic into the control plane. It is the **sole authority for field override control** — no other component sets override metadata on fields.

### 17.2 Policy Categories

| Category | Description | Modifies Data? | Example |
|----------|-------------|----------------|---------|
| **Transformation** | Enriches or modifies the payload. Adds missing fields, applies standards. All changes recorded in provenance. May set `override: constrained`. | Yes | Inject PCI-compliant cryptography standard |
| **Validation** | Checks payload against rules. Pass/fail — no field modification. Failure rejects request. | No | VM class allowed in DMZ Zone A |
| **GateKeeper** | Highest authority. Overrides any field including consumer input. Sets `override: immutable`. Halts execution. | Yes — overrides everything | Block request violating sovereignty |

### 17.3 Policy Hierarchy
Three-tier execution — Global first, User last. Within each tier sorted by priority (higher value = higher authority):

```
Global  (Super Admin) — runs first, highest authority
Tenant  (Tenant Admin) — runs second
User    (End User)    — runs last, lowest authority
```

A Global policy cannot be overridden by Tenant or User. Field locks set by higher-authority policies cannot be unlocked by lower-authority policies.

### 17.4 Policy Implementation
- **Engine:** OPA (Open Policy Agent) with Rego policy language
- **Storage:** GitOps — all policies in Git, versioned, immutable once published
- **Execution:** Stored-policy model — OPA pre-loads policies; evaluation calls pre-loaded modules
- **Outputs:** `rejected` (bool), `patch` (field mutations), `constraints` (JSON Schema locks), provider placement constraints (NOT direct provider naming)

### 17.5 Policy Rules
- Policies operate only on policy definition, core data, and request payload data
- Outcomes must be **deterministic** — same input always produces same output for a given version
- All modifications recorded in field-level provenance with policy UUID, tier level, and reason
- Policies follow the five-status lifecycle: `developing → proposed → active → deprecated → retired`

### 17.6 Policy Scope
- **Core Policies** — all DCM actions regardless of provider
- **Service Policies** — specific to a Service Provider's services
- **Organizational Policies** — defined by the implementing organization
- **Domain Policies** — scoped to a specific domain or business unit

### 17.7 Proposed Policy — Shadow Execution
When a policy is in `proposed` status it runs in **shadow mode** against real request traffic:
- Executes alongside active policies on every relevant request
- Output captured in `proposed_evaluation_record` — what it would have done
- Output is **never applied** to the actual request
- Feeds the Validation Dashboard for reviewer analysis before activation
- Impact categories: `none | low | medium | high | critical`
- Activation requires approval after review period

### 17.8 Policy and Override Control
The Policy Engine exclusively sets `override_control` metadata. Three levels (see Section 6.10–6.11):
- Level 1 — no declaration → fully overridable (default)
- Level 2 — simple `override: allow|constrained|immutable`
- Level 3 — full `override_matrix` with per-actor permissions and trusted grants

---

## SECTION 18 — KEY USE CASES

### 18.1 Datacenter Rehydration (Repave)
Reconstruct ALL required components and configurations from code after catastrophic failure (ransomware, DR event, mandatory 90-day repave). Industry benchmark: leading FSI organization 60-day repave. DCM must beat this. Key metric: TTR (Time to Recovery).

### 18.2 Intelligent Placement
Automated placement of resources and workloads based on metadata, policies from CMDB/CISO/platform teams. Consumer declares criteria (location, SLA, security zones) — DCM determines optimal placement automatically.

### 18.3 Application as a Service
Meta Service Provider that consumes application code and provides its full execution lifecycle. Consumer defines metadata for required technologies or SLAs — provider handles the rest.

### 18.4 Regional Sovereignty
Enforce workload placement within specific regions or sovereignty constraints. CISO/CCO-driven policy ensuring data residency and jurisdictional compliance.

### 18.5 Data Enrichment
System enriches consumer requests with ancillary implementation details the consumer should not need to know. Consumer declares intent — DCM fills in the details.

### 18.6 Greening the Brownfield
Bring existing unmanaged resources under DCM lifecycle management:
1. **Discovery** — provider interrogates existing resources, creates Discovered State payload
2. **Enrichment** — business data associated with discovered resources (owner, cost center, purpose)
3. **Lifecycle Ownership** — Discovered State promoted to Realized State; DCM assumes lifecycle management

---

## SECTION 19 — DIGITAL SOVEREIGNTY

DCM addresses four dimensions of digital sovereignty:

| Dimension | DCM Enabler | Impact |
|-----------|-------------|--------|
| **Data and Content Sovereignty** | Data Model, Policy Engine, Validated Providers | Data residency and jurisdictional compliance |
| **Operational Sovereignty** | Policy Engine | Sovereign Execution Posture, Hard Tenancy enforcement |
| **Security and Compliance Sovereignty** | Audit, GRC | Evidence for strict regional mandates |
| **Mobility, Placement, Modernization** | Policy Engine, Providers, Data Model | Automated placement, provider mobility, brownfield ingestion |

**Sovereign Execution Posture** — the target end state where all operations are governed, auditable, and compliant with sovereignty requirements. This is the north star concept of DCM.

---

## SECTION 20 — PERSONAS

| Persona | Primary Concern |
|---------|----------------|
| **Consumer** | Self-service access to resources and services |
| **Service Provider** | Exposing services through DCM catalog |
| **Auditor** | End-to-end transaction review and validation |
| **Policy Creator** | Defining and maintaining governance policies |
| **SRE** | Stability, uptime, drift reconciliation, brownfield management |
| **CTO** | Accelerate innovation, reduce risk, enable sovereignty |
| **CIO/MD** | Lifecycle management, agility, IT investment maximization |
| **CISO/CCO** | Sovereignty enforcement, compliance, risk reduction |
| **Application Owner** | Focus on application code, not infrastructure specifics |
| **Line of Business** | Business outcomes — new products, revenue, compliance |

---

## SECTION 21 — TERMINOLOGY GLOSSARY

| Term | Definition |
|------|-----------|
| **DCM** | Data Center Management — the framework itself |
| **Sovereign Execution Posture** | Target state where all operations are governed, auditable, and sovereignty-compliant |
| **Hard Tenancy** | Strict isolation between tenants at the infrastructure level |
| **UDM** | Unified Data Model — the centralized data schema and single source of truth |
| **Naturalization** | Converting UDM format to provider-specific format for execution |
| **Denaturalization** | Converting provider-specific results back to UDM format |
| **Greening the Brownfield** | Bringing existing unmanaged resources under DCM lifecycle management |
| **Intent Portability** | Replaying an Intent State through current policies to produce a new Requested State |
| **Resource Type** | Abstract, vendor-neutral definition of a class of resource |
| **Provider Catalog Item** | Concrete provider implementation of a Resource Type Specification |
| **Portability-Breaking** | A field or operation that ties a request to a specific provider |
| **CMDB** | Configuration Management Database — DCM aims to replace the fragmented multi-CMDB problem |
| **GRC** | Governance, Risk, and Compliance |
| **TTR** | Time to Recovery — key metric for rehydration use case |
| **MTTD** | Mean Time to Deploy or Detect |
| **MTTR** | Mean Time to Recovery/Repair |
| **FSI** | Financial Services Institution |
| **IaC** | Infrastructure as Code |
| **GitOps** | Managing infrastructure definitions through Git workflows |
| **CRUD** | Create, Read, Update, Delete — full lifecycle operations |
| **IPU** | In-Place Upgrade |
| **EOL** | End of Life |
| **Field-Level Provenance** | Structural mechanism carrying data lineage within each data object |
| **Data Lineage** | Complete chain of custody of any field value from origin through all modifications |
| **Base Layer** | Foundation entity for a resource — every layer chain starts here |
| **Core Layer** | Type-agnostic data layer carrying organizational and infrastructure context |
| **Service Layer** | Type-scoped data layer carrying service-specific configuration — must declare Resource Type scope |
| **Request Layer** | Consumer's declared intent — becomes Intent State on submission |
| **Layer Chain** | Ordered sequence of layers merged to produce an assembled payload |
| **Assembly Process** | Seven-step process by which the Request Payload Processor builds a Requested State payload |
| **GateKeeper Policy** | Highest-authority policy that can override any field including consumer input |
| **Transformation Policy** | Policy that enriches or modifies payload fields — all changes recorded in provenance |
| **Validation Policy** | Policy that checks payload against rules — pass/fail, no field modification |
| **Resource/Service Request** | What a consumer submits to DCM — declared intent to consume a resource or service |
| **Resource/Service Entity** | The "thing" produced by a provider fulfilling a request — the allocation made real |
| **DCM Tenant** | Mandatory first-class ownership boundary for all Resource/Service Entities |
| **Allocation Model** | Provider retains infrastructure ownership; consumer owns the Entity allocation |
| **Whole Allocation Model** | Entire resource allocated as indivisible unit; provider retains ownership |
| **Full Transfer Model** | Provider transfers complete ownership of underlying resource to consumer Tenant |
| **Hybrid Transfer Model** | Ownership can transfer multiple times; always exactly one owning Tenant |
| **Process Resource Entity** | Ephemeral execution resource — playbook, pipeline, workflow. Permanent execution record. |
| **Dependency Graph** | Complete map of all resources required to fulfill a request including transitive dependencies |
| **Type-Level Dependency** | Portable, provider-agnostic dependency declared at Resource Type Specification level |
| **Provider-Specific Dependency** | Additional dependency declared at Provider Catalog Item level — must be marked portability-breaking |
| **Resource Group** | Flexible composable grouping entity — functions like a structured tag |
| **Custom Resource Group** | Implementor-defined grouping entity with full parity to DCM Default Resource Group |
| **Tenant Advocate** | DCM's role in protecting Tenant interests in all provider interactions |
| **DCM System Policy** | Non-overridable policy built into DCM — cannot be disabled or overridden by organizational policy |
| **Webhook** | Push-based outbound notification from DCM to an external system triggered by a DCM event |
| **DCM Event Type** | A versioned, typed event that DCM can emit — follows universal versioning model |
| **Event Type Registry** | DCM-maintained registry of standard event types — extensible like the Resource Type Registry |
| **Webhook Registration** | Declaration by a consumer, provider, or external system of which DCM events they want to receive and where |
| **Discussion Topics** | Living document (DISCUSSION-TOPICS.md) capturing unresolved design decisions and topics requiring further discussion |
| **Override Preference** | Level 2 simple override declaration — single `override: allow|constrained|immutable` on a field |
| **Override Matrix** | Level 3 per-actor permission matrix for fields requiring nuanced governance |
| **Field Override Control** | Graduated mechanism (Levels 1-3) governing who can change what field, under what conditions |
| **Structural Layer Rules** | Non-configurable rules enforced by the Request Payload Processor — layer immutability, precedence order, chain integrity |
| **Business Override Rules** | Configurable override control rules enforced by the Policy Engine via override metadata |
| **Trusted Grant** | Explicit expansion of override permissions issued by a higher-authority actor to a specific entity UUID |
| **Actor Registry** | Extensible registry of override actors — built-in (policy.global, consumer_request, sre_override, etc.) plus custom actors |
| **Basis for Value** | Field metadata documenting why a particular value was set |
| **Baseline Value** | Field metadata recording the original default value before any override was applied |
| **Entity Relationship** | Universal bidirectional relationship between any two entities — internal or external |
| **Entity Relationship Graph** | Complete traversable graph of all entity relationships in DCM |
| **Relationship UUID** | UUID identifying a specific relationship — same on both sides of the bidirectional record |
| **Relationship Type** | Fixed vocabulary describing the nature of a relationship (requires, depends_on, contains, references, peer, manages) |
| **Relationship Role** | Semantic label describing the function a related entity serves (compute, storage, networking, business_unit, etc.) |
| **Relationship Nature** | Structural character of a relationship — constituent, operational, or informational |
| **Lifecycle Policy** | Declares what happens to an entity when its related entity changes state |
| **Bundled Declaration Expansion** | Processor mechanism expanding bundled fields (e.g., storage in VM request) into first-class entities and relationships |
| **Information Provider** | DCM provider type serving authoritative external data DCM references but does not own |
| **External Entity Reference** | Stable pointer record DCM uses to reference data in an external system |
| **Standard Data** | DCM-defined fields on an information type — used for lookups and operational decisions |
| **Extended Data** | Organization-defined fields added to an information type — carried in payload but not used for DCM core operations |
| **Information Type** | Registry entry for a category of external data (Business.BusinessUnit, Identity.Person, etc.) |
| **Stable External Key** | The external system's UUID used as the primary lookup anchor for an external entity reference |
| **Trust But Verify** | DCM's approach to external references — trusts external data is correct, verifies references remain valid |
| **DCM Operator Interface Specification** | The formal technical contract defining how Kubernetes operators integrate with DCM as Service Providers |
| **DCM Operator SDK** | Go library implementing the Operator Interface Specification — enables Level 1 conformance in one day |
| **Conformance Level** | The level of DCM integration an operator implements — Level 1 (basic), Level 2 (standard), Level 3 (full) |
| **Naturalization (Kubernetes)** | Translating DCM Requested State into a Kubernetes CR |
| **Denaturalization (Kubernetes)** | Translating Kubernetes CR status back into DCM Realized State format |
| **Unsanctioned Change** | A change to a DCM-managed CR that did not originate from a DCM request — detected via missing DCM request annotation |
| **Operator Adapter** | A component implementing the DCM Service Provider API on behalf of an operator that cannot be modified directly |
| **CNCF Sandbox** | The initial CNCF maturity level — target for initial DCM project submission |
| **Conformance Test Suite** | The test suite that validates an operator's implementation against the DCM Operator Interface Specification |
| **Intent State** | The immutable record of a consumer's original declaration — captured before any assembly or policy evaluation |
| **Requested State** | The fully assembled, policy-processed, provider-ready payload — the authoritative record of what DCM instructed a provider to build |
| **Realized State** | The provider-confirmed record of what was actually built — append-only event stream keyed by entity UUID |
| **Discovered State** | What DCM observes actually existing through active discovery — ground truth for drift detection |
| **Storage Provider** | The fourth formal DCM provider type — the interface through which DCM persists and streams all state data |
| **GitOps Store** | Storage Provider type for Intent and Requested State — branch, PR, merge, CI/CD hook semantics |
| **Event Stream Store** | Storage Provider type for Realized and Discovered State — append-only, entity-keyed, replayable |
| **Search Index** | Queryable projection of GitOps stores — explicitly non-authoritative, rebuilt from Git on demand |
| **Provider-Portable Rehydration** | Rehydration with provider selection re-evaluated through current placement policies |
| **Faithful Rehydration** | Rehydration honoring the original provider selection from the source record |
| **Pinned Policy Version** | Rehydration using policies as of a specific historical timestamp — requires elevated authorization |
| **Audit Component** | Separate DCM component aggregating provenance events from all stores — compliance-grade, long-retention |
| **Observability Store** | Time-series metrics, traces, and logs — operational, not compliance-grade |
| **Third Rail** | Direct API ingress path — bypasses PR workflow, never bypasses governance |
| **Unsanctioned Change** | A resource modification not traceable to a DCM request — triggers UNSANCTIONED_CHANGE event |
| **Layer Domain** | Organizational and architectural home of a layer — system, platform, tenant, service, provider |
| **Layer Handle** | Human-readable stable identifier for a layer — format: domain/layer_type/name |
| **Priority Schema** | Hierarchical dotted-notation priority system for deterministic layer conflict resolution |
| **Priority Value** | Numeric dotted-notation priority — higher value wins; no ceiling, infinitely insertable in both directions |
| **Immutable Ceiling** | `immutable_ceiling: absolute` — explicit declaration that a field lock cannot be overridden by any future higher-priority policy; the nuclear option for true non-negotiables |
| **Priority Label** | Semantic context for a priority value — human-readable, does not affect ordering |
| **Reference Priority Taxonomy** | DCM's advisory priority category ranges — not enforced, organizations adopt/adapt/ignore |
| **Artifact Metadata** | Universal metadata block on every DCM artifact — identity, ownership, creation, modification history, contact |
| **created_by** | Artifact metadata field — the audit record of who physically submitted the artifact |
| **owned_by** | Artifact metadata field — the accountability record of who is responsible and receives notifications |
| **created_via** | Artifact metadata field — ingestion path: pr, api, migration, system |
| **Proposed Shadow Execution** | Policy artifact in proposed status executing against real traffic — output captured, never applied |
| **Proposed Evaluation Record** | Shadow output record for a proposed policy — what it would have done on a real request |
| **Validation Dashboard** | Review interface showing aggregate shadow output for proposed policies before activation |

---

## SECTION 22 — OPEN QUESTIONS

These items are explicitly unresolved. Do not make assumptions about them — flag them and ask for guidance.

| # | Question | Area |
|---|----------|------|
| 1 | Where should data caches live? (Shore, Ship, Enclave, all?) | Data Model |
| 2 | Should cache synchronization be push, pull, or both? | Data Model |
| 3 | Which cache is authoritative when caches diverge? | Data Model |
| 4 | What mechanism maintains consistency across distributed caches? | Data Model |
| 5 | Should the data model allow embedded target-technology-specific data bundles? | Data Model |
| 6 | How are the four states represented physically? | Data Model |
| 7 | Performance impact of field-level provenance at scale — optimization strategies? | Data Model |
| 8 | Should provenance metadata be inline or in a linked provenance document? | Data Model |
| 9 | What is the governance model for proposing new Resource Types to the registry? | Catalog |
| 10 | Should the registry support a formal review/approval workflow? | Catalog |
| 11 | What is the minimum sunset period for deprecated definitions? | Catalog |
| 12 | Should version constraints in requests be strictly enforced or advisory? | Catalog |
| 13 | How are conflicts resolved when multiple providers satisfy all narrowing criteria equally? | Catalog |
| 14 | Should the registry be distributed or centralized? Sovereignty implications? | Catalog |
| 15 | Trust validation mechanism for provider certification | Providers |
| 16 | Audit vs. Observability — are these truly separate components? | Control Plane |
| 17 | Message Bus — should it be exposed as consumer ingress or egress only? | Control Plane |
| 18 | GateKeeper vs. Validation policy distinction — needs better examples | Policy Engine |
| 19 | How are conflicting Service Layers at the same precedence level resolved? | Data Layers | ✅ Resolved — priority schema + ingestion conflict detection |
| 20 | Should Core Layers be ordered within their precedence level? | Data Layers | ✅ Resolved — priority schema provides deterministic ordering |
| 21 | Can a consumer explicitly exclude a layer from their request? | Data Layers |
| 22 | How are Service Layers registered and versioned relative to their Service Provider registration version? | Data Layers |
| 23 | Should assembly support conditional layer inclusion — a layer only applied if a specific field value is present? | Data Layers |
| 24 | How does the layer chain interact with service dependencies — does each dependent service get its own chain? | Data Layers |
| 25 | For Hybrid Transfer — what is the maximum number of ownership transfers allowed? | Entities |
| 26 | For Whole Allocation of bare metal — how is indivisibility enforced at the provider level? | Entities |
| 27 | Should capacity confidence ratings trigger automatic actions (e.g., LOW triggers Mode 1 query)? | Entities |
| 28 | For Process Resources — should there be a maximum execution time before DCM escalates? | Entities |
| 29 | How does SUSPENDED state interact with cost analysis — is a suspended Entity still billable? | Entities |
| 30 | How are dependency graphs versioned relative to catalog item versions? | Dependencies |
| 31 | Should the dependency graph be stored as a separate entity or embedded in the request payload? | Dependencies |
| 32 | How are cross-tenant dependencies handled? | Dependencies |
| 33 | Should there be a maximum dependency graph depth? | Dependencies |
| 34 | How does the dependency graph interact with the Meta Provider model? | Dependencies |
| 35 | Should DCM maintain a registry of well-known custom group types? | Grouping |
| 36 | How does group membership interact with sovereignty — can a group span sovereignty boundaries? | Grouping |
| 37 | When a Tenant is decommissioned, what happens to its resources and group memberships? | Grouping |
| 38 | Should Resource Groups support time-bounded membership? | Grouping |
| 39 | How are group-level policies inherited by nested child groups — opt-in or opt-out? | Grouping |
| 40 | Webhook registration model — Consumer API, Provider Registration, or dedicated Webhook API? | Webhooks |
| 41 | Full DCM event taxonomy and whether it should be a versioned registry | Webhooks |
| 42 | Webhook payload format — full state payload vs reference + event type | Webhooks |
| 43 | Webhook authentication model for outbound calls | Webhooks |
| 44 | Webhook retry and reliability obligations | Webhooks |
| 45 | Webhook ordering guarantees | Webhooks |
| 46 | Relationship between webhooks and the Message Bus | Webhooks |
| 47 | Should provider webhook support be mandatory in the Provider Contract? | Webhooks |
| 48 | Tenant vs platform-level webhook scoping | Webhooks |
| 49 | Should webhook registrations declare which payload schema version they expect? | Webhooks |
| 50 | Should override_preference be declarable in layer definitions as a hint to the Policy Engine? | Override Control |
| 51 | When immutable is set by a Global policy, can a higher-priority Global policy still override it? | Override Control | ✅ Resolved — execution order makes default immutable effectively absolute; immutable_ceiling: absolute provides explicit forward-looking protection |
| 52 | Should constraint_schema on a constrained field be visible to consumers in the Service Catalog UI? | Override Control |
| 53 | Enhancement gaps: storage/networking bundling vs. dependency model — V1 simplification or new concept needed? | Enhancements |
| 54 | Enhancement gaps: selected_provider as policy output vs. placement component concern | Enhancements |
| 55 | Enhancement gaps: migration path from V1 (no Tenant) to Tenant-mandatory | Enhancements |
| 56 | Enhancement gaps: should editable field concept from Catalog Item Schema be incorporated into Resource Type Spec? | Enhancements |
| 57 | How are relationship conflicts resolved — two policies declare different lifecycle policies for the same relationship? | Entity Relationships |
| 58 | Should relationship roles be validated against the role registry at request time, or is validation advisory? | Entity Relationships |
| 59 | How does the relationship graph interact with multi-tenant scenarios — can a relationship cross Tenant boundaries? | Entity Relationships |
| 60 | Should there be a maximum relationship graph depth? | Entity Relationships |
| 61 | How are shared entities represented — an entity required by multiple parents? | Entity Relationships |
| 62 | How are conflicting Information Provider push events handled — two providers claim authority for the same record? | Information Providers |
| 63 | Should Information Providers support write-back — DCM updating external records via the provider? | Information Providers |
| 64 | How is the extended schema versioned when a provider adds or removes extended fields? | Information Providers |
| 65 | Should DCM maintain a registry of well-known Information Providers to simplify onboarding? | Information Providers |
| 66 | How does Information Provider verification interact with air-gapped environments? | Information Providers |
| 67 | Should CNCF submission be for DCM as a whole or for the Operator Interface Specification as a standalone standard? | CNCF Strategy |
| 68 | Which FSI consortium members will be named as public adopters in the CNCF submission? | CNCF Strategy |
| 69 | How does the Namespace-to-Tenant mapping work for clusters with pre-existing namespaces? | Kubernetes Compatibility |
| 70 | How does DCM interact with Kubernetes admission webhooks — duplicate or complement Policy Engine? | Kubernetes Compatibility |
| 71 | Should the Kubernetes Information Provider be a built-in DCM component or separately deployed? | Kubernetes Compatibility |
| 72 | How does DCM interact with managed Kubernetes services (EKS, GKE, AKS) where cluster management is outside user control? | Kubernetes Compatibility |
| 73 | Should the SDK support non-Go operator frameworks via a language-agnostic REST adapter? | SDK Design |
| 74 | How should the SDK handle DCM endpoint unavailability — queue events locally or drop? | SDK Reliability |
| 75 | Should the entity UUID be preserved or regenerated on rehydration? | Four States |
| 76 | For pinned policy version rehydration — what is the minimum authorization level? | Four States |
| 77 | How are concurrent rehydration requests for the same entity handled? | Four States |
| 78 | Should the Discovered Store retain full history or only a configurable window? | Four States |
| 79 | Git repository structure for Intent and Requested stores — deferred pending Q54 | Storage |
| 80 | Should Storage Providers support multi-region replication as a declared capability? | Storage |
| 81 | How are Storage Provider failures handled — failover, queuing, or rejection? | Storage |
| 82 | Should the Search Index be a separate Storage Provider or bundled with GitOps store? | Storage |
| 83 | Should the Audit Store be a specialized Storage Provider or a general Event Stream Store? | Audit |
| 84 | Should DCM provide a default observability dashboard or only the telemetry? | Observability |
| 85 | Should the background conflict validation job run on schedule or be event-triggered? | Data Layers |
| 86 | What is the minimum validation review period for a proposed policy before activation? | Policy Engine |
| 87 | Should the proposed shadow evaluation record be stored in the Audit Store or a separate validation store? | Storage |
| 88 | Should organizations be able to define their own artifact status extensions beyond the five standard statuses? | Artifact Metadata |

---

## SECTION 23 — DOCUMENTATION STRUCTURE

DCM documentation follows a hierarchical structure:

```
dcm-docs/ (internal working docs)
├── README.md
├── DCM-AI-PROMPT.md                       # This file
├── DISCUSSION-TOPICS.md
├── data-model/                            # → website: /docs/architecture/data-model/
│   ├── 00-context-and-purpose.md          ✅
│   ├── 02-four-states.md                  ✅
│   ├── 03-layering-and-versioning.md      ✅
│   ├── 05-resource-type-hierarchy.md      ✅
│   ├── 06-resource-service-entities.md    ✅
│   ├── 07-service-dependencies.md         ✅
│   ├── 08-resource-grouping.md            ✅
│   ├── 09-entity-relationships.md         ✅
│   ├── 10-information-providers.md        ✅
│   ├── 11-storage-providers.md            ✅
│   └── 12-audit-provenance-observability.md ✅
└── specifications/                        # → website: /docs/architecture/specifications/
    ├── dcm-operator-interface-spec.md     ✅
    ├── 11-kubernetes-compatibility.md     ✅
    ├── dcm-operator-sdk-api.md            ✅
    └── cncf-strategy.md                  ✅

Website structure (Hugo / Hextra):
content/
├── _index.md                              # Homepage — 4 bottom cards
└── docs/
    ├── _index.md                          # Docs index
    ├── architecture/
    │   ├── _index.md                      # Architecture section — 3 cards
    │   ├── overview.md                    # High Level Design ✅
    │   ├── data-model/
    │   │   ├── _index.md                  # Data Model section — 11 cards
    │   │   └── (11 data model docs)       ✅
    │   └── specifications/
    │       ├── _index.md                  # Specifications section — 4 cards
    │       └── (4 specification docs)     ✅
    └── enhancements/
        ├── _index.md
        └── (existing enhancement stubs — unchanged)
```

---

## SECTION 24 — WORKING INSTRUCTIONS FOR AI MODELS

When working on this project, follow these instructions:

1. **Data model is foundational** — all design decisions must be evaluated against their impact on the data model first
2. **Four states are always relevant** — when designing any component or flow, identify which states it reads from and writes to
3. **Provenance is non-negotiable** — any component that modifies data must record provenance; never design around this requirement
4. **UUIDs everywhere** — every entity, definition, and data object must have a UUID; never reference by name alone
5. **Portability first** — when designing resource types or catalog items, start with universal fields; justify any deviation toward conditional or provider-specific
6. **Policy over hardcoding** — business logic belongs in the Policy Engine, not in component code
7. **Declarative over procedural** — data describes state, not steps; procedures belong in providers
8. **Universal versioning** — every definition is versioned using Major.Minor.Revision; never create an unversioned definition
9. **Universal artifact lifecycle** — every definition must support the five-status lifecycle: `developing → proposed → active → deprecated → retired`; never design an artifact with only the old three-status model
10. **Flag open questions** — do not make assumptions about unresolved items; surface them and ask
11. **Documentation format** — Markdown, hierarchical structure, following the established document style
12. **Provider agnosticism** — DCM does not care how providers accomplish their work; only the data contract matters
13. **Layer type scoping** — Core Layers are type-agnostic; Service Layers must always be type-scoped; a Service Layer without a declared type scope is always invalid
14. **GateKeeper is supreme** — GateKeeper policies can override anything including consumer input; this is by design for sovereignty and security enforcement; never design around it
15. **DCM always owns the data** — regardless of operational ownership model, DCM is always the authoritative system of record for all Resource/Service Entity data and lifecycle
16. **Tenant is mandatory** — every Resource/Service Entity must belong to exactly one Tenant; this is a non-overridable DCM System Policy; no exceptions
17. **Ownership vs consumption** — a resource belongs to one Tenant (owner) but can be consumed by multiple Tenants via the Service Catalog; never conflate ownership and consumption
18. **Dependencies declared in advance** — all dependencies must be declared in the data model before execution; provider-discovered runtime dependencies are not acceptable
19. **Process Resources need provenance** — if a Process Resource modifies an Infrastructure Entity, that Entity's provenance must reference the Process Resource UUID
20. **Two-tier policies** — DCM System Policies are non-overridable; Organizational Policies are configurable; never design a System Policy as organizational or vice versa
21. **Check DISCUSSION-TOPICS.md first** — before designing any component or capability, check the discussion topics document for active or parked topics that may affect the design; never proceed on a topic marked 🔴 Blocking without resolution
22. **Webhooks are unresolved** — webhook integration is under active design (DISCUSSION-TOPICS.md TOPIC-001); do not make implementation assumptions about webhook mechanics, payload format, authentication, or retry behavior until design questions are resolved; webhooks ARE confirmed as an Egress capability with Policy Engine integration
23. **Override control belongs to Policy Engine** — the Request Payload Processor enforces structural layer rules only; field-level override control (allow/constrained/immutable) is set exclusively by the Policy Engine; never design around this boundary
24. **Enhancement gaps are tracked** — DISCUSSION-TOPICS.md TOPIC-011 documents compatibility gaps between existing enhancement documents and the data model; when working on components covered by those enhancements, check TOPIC-011 for known gaps that need resolution
25. **Single relationship model** — all entity relationships use the universal bidirectional model in doc 09; never create a separate binding or dependency mechanism; the entity relationship graph supersedes the dependency graph concept
26. **Information Providers are not Service Providers** — Information Providers serve data DCM references but does not own; DCM never caches external data authoritatively; only `display_name` is cached non-authoritatively for UI convenience
27. **Standard data only for operational decisions** — DCM core only relies on standard information type fields for lookups, policy evaluation, and operational decisions; extended fields are carried in payloads but never used for DCM core operations
28. **DCM is a Kubernetes superset, not a replacement** — Kubernetes manages the execution plane; DCM manages the management plane; operators become DCM Service Providers through the Operator Interface Specification; never design DCM as competing with Kubernetes
29. **Operator adapter pattern** — when an operator cannot be modified directly, an adapter implements the DCM Service Provider API on its behalf; the adapter handles Naturalization (DCM → CR) and Denaturalization (CR status → DCM); this is the standard pattern for existing operators
30. **Conformance levels gate capabilities** — Level 1 operators get catalog and basic monitoring; Level 2 adds placement and drift detection; Level 3 adds sovereignty and brownfield ingestion; always check what level an operator has declared before assuming capabilities are available
31. **Storage Providers define contracts, not implementations** — DCM specifies what a store must do; implementors choose the technology; never reference a specific technology (Kafka, Git, Elasticsearch) as a DCM requirement — reference the store type and contract instead
32. **Governance is never skippable in rehydration** — all relevant policies always apply regardless of rehydration source, mode, or urgency; the only variable is current vs pinned policy version, and pinned requires elevated authorization
33. **Audit and Observability are separate concerns** — Audit is compliance-grade, long-retention, persona-restricted; Observability is operational, short-retention, SRE-accessible; never conflate them or design them as the same component
34. **All DCM capabilities surface through the API Gateway** — Audit, Observability, Catalog, Requests, Entities, Policies all live in a unified API hierarchy; there are no separate endpoints outside the Gateway
35. **The Search Index is non-authoritative** — if Search Index and GitOps store disagree, Git always wins; the Search Index is a performance layer only; it can be cleared and rebuilt from Git at any time
36. **All artifacts carry artifact metadata** — layers, policies, resource types, catalog items, provider registrations, entity definitions — everything. No artifact is exempt from the universal metadata block
37. **created_by ≠ owned_by** — created_by is the audit record of who submitted the artifact; owned_by is the accountability record of who is responsible and receives notifications; these may be different people/teams
38. **Conflicts are resolved at ingestion, not assembly** — all active layers in DCM are pre-validated conflict-free; the assembly process never encounters an ambiguous merge; if a conflict is found at ingestion, the PR is blocked until resolved
39. **Priority schema is advisory for categories, mandatory for ordering** — the reference taxonomy (900=Compliance, 800=Security, etc.) is advisory and organizations may adapt it; however, the numeric comparison rule is always enforced and always deterministic
40. **Proposed status enables shadow validation** — policy artifacts in proposed status execute in shadow mode against real traffic; output is captured in proposed_evaluation_record but never applied; this is the required validation step before activation

---

*This prompt script is a living document. Update it whenever architectural decisions are made or open questions are resolved.*
