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

### 6.1 Layers vs Policies — The Clear Distinction

**Layers are data.** They carry static configuration, defaults, metadata, and context assembled into the request payload. A layer answers: "what values should these fields have?" Layers are passive — they declare values but do not execute logic. They come first in assembly (Steps 1-4).

**Policies are logic.** They evaluate the assembled payload and enforce rules, inject derived values, and make decisions. A policy answers: "given this data, is it valid? what should change? should this proceed?" Policies execute — they run code. They come after layers (Steps 5-9).

**The flow is strictly unidirectional:**
```
Steps 1-4: LAYERS assembled → merged payload produced (data)
Steps 5-9: POLICIES execute → payload evaluated and acted upon (logic)
```

**The decision rule:** Value that should appear in payload → Layer. Rule about whether payload is correct → Policy. Value derived by evaluating payload → Policy (Transformation type).

**What belongs in layers:** infrastructure defaults, organizational context, service configuration defaults, compliance metadata, business context labels.

**What belongs in policies:** validation rules, compliance enforcement, derived value injection, placement constraints, approval gates, security enforcement.

A policy that repeatedly injects the same static value into every request → that value belongs in a layer. A layer that contains conditional logic → that logic belongs in a policy.

### 6.2 Layer Domain Model (mirrors Policy domain)

| Domain | Authority | Can Override |
|--------|----------|-------------|
| `system` | DCM built-in — highest | Nothing above system |
| `platform` | Platform team | tenant, service, provider |
| `tenant` | Tenant Admin | service, provider within Tenant |
| `service` | Service Provider | provider |
| `provider` | Provider owner | Nothing above provider |
| `request` | Consumer — lowest | Nothing above request |

### 6.3 The Full Layer Structure

Every layer carries: artifact_metadata (standard), domain + priority (authority), concern_tags (discoverability), compatibility (resource_types, versions, profile_constraints), activation_condition (Q23 — conditional inclusion), fields with per-field override metadata (override: allow/constrained/immutable, basis_for_value), and usage context (description, applies_when, excludes_when, conflicts_with).

**activation_condition** — layer only included if condition evaluates true during Step 2. Conditions reference: request fields, tenant attributes, resource type fields, resolved core layer fields, ingress fields. Enables role-specific layers, GPU-only layers, PCI-scope-only layers.

### 6.4 Layer Groups

Layer Groups are `DCMGroup` with `group_class: layer_grouping` — cohesive collections of related layers. Same model as Policy Groups. Enables discovery ("show me all PCI compliance layers"), composition, and governance.

### 6.5 Consumer Layer Exclusion (Q21)

Consumers declare `layer_exclusions` with mandatory reason. Excluded layers removed in Step 2, produce no fields, cannot satisfy validation requirements. GateKeeper policies may declare layers non-excludable (LAY-001).

### 6.6 Service Layer Versioning (Q22)

Service Layers independently versioned. Providers declare semver compatibility constraints (`^1.0.0`, `~1.2`). Cache entries carry version — invalidated when registered version changes (LAY-002).

### 6.7 Conditional Layer Inclusion (Q23)

`activation_condition` on layer evaluated in Step 2. False → layer excluded. Conditions reference request, tenant, resource type, core layer, and ingress fields. Recorded in assembly provenance (LAY-003).

### 6.8 Dependency Layer Chains (Q24)

Each service dependency has its own independent layer chain. Inherits parent's resolved placement fields (read-only). Does NOT inherit parent consumer declarations or type-specific layers. Layer exclusions declarable per-dependency (LAY-004).

### 6.9 The Nine-Step Assembly Process

Step 1 (Intent Capture) → Step 2 (Layer Resolution — with exclusions and activation_conditions) → Step 3 (Layer Merge — priority ordering, field-level provenance) → Step 4 (Request Layer Application) → Step 5 (Pre-Placement Policies: Transformation → Validation → GateKeeper) → Step 6 (Placement Engine Loop: reserve query + loop policy phase per candidate) → Step 7 (Post-Placement Policies) → Step 8 (Requested State Storage) → Step 9 (Provider Dispatch)

### 6.10 Layer System Policies
- `LAY-001` — Consumer layer exclusions with mandatory reason; GateKeeper can lock layers as non-excludable
- `LAY-002` — Service Layers independently versioned; semver compatibility on provider; cache invalidation on version change
- `LAY-003` — activation_condition on layers evaluated in Step 2; results recorded in provenance
- `LAY-004` — Each dependency has own layer chain; inherits parent resolved placement; no consumer declaration inheritance

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

## SECTION 10 — UNIVERSAL GROUP MODEL AND TENANCY

> The Universal Group Model (document 15-universal-groups.md) supersedes the separate Tenant and Resource Group models for new implementations. All existing constructs map 1:1 to `group_class` values. Existing UUIDs and API surfaces are preserved.

### 10.1 Universal Group Structure
Every grouping construct in DCM is a `DCMGroup` with:
- `group_class` — determines system behavior (see 10.2)
- `group_subclass` — advisory label, no system behavior
- `member_types_permitted` — what can be a member
- `exclusivity` — one or many groups of this class per member
- `enforcement_model` — advisory | enforced | mandatory (tenant_boundary: profile-governed)
- `lifecycle_policy` — on_group_destroy: **detach (default)** | notify | cascade | retain
- `former_group_membership` records retained permanently after detach
- `group_destruction_record` retained in Audit Store permanently
- Time-bounded membership: `valid_from / valid_until` on every membership

### 10.2 Group Classes

| group_class | Purpose | enforcement |
|-------------|---------|------------|
| `tenant_boundary` | Ownership/isolation boundary (replaces Tenant) | profile-governed |
| `resource_grouping` | Flexible entity tagging (replaces Resource Groups) | advisory |
| `policy_collection` | Policy cohesion unit (replaces Policy Group) | advisory |
| `policy_profile` | Deployment configuration (replaces Policy Profile) | enforced |
| `layer_grouping` | Related layers for a context | advisory |
| `composite` | Cross-type organizational unit | configurable |
| `federation` | Peer-group association (federated Tenants) | advisory |

### 10.3 DCM Tenant — tenant_boundary group_class
Every resource entity must belong to exactly one `tenant_boundary` group (GRP-001). Provides: ownership, isolation, cost attribution, policy scope, drift detection scope, rehydration scope, audit scope, sovereignty boundary.

**Structurally locked invariants** (cannot be overridden by any policy):
- One tenant_boundary group per resource — always
- Constituent relationships never cross tenant_boundary boundaries — at any nesting level

**Profile-governed enforcement:** `minimal` profile → advisory; `standard`/`prod`/`fsi`/`sovereign` → mandatory. A GateKeeper policy fires when advisory tenancy detected in prod/fsi/sovereign deployment (GRP-011).

### 10.4 Nested Tenants
A `tenant_boundary` group can have `parent_group_uuid` pointing to another `tenant_boundary` group. The parent-child relationship is a governance and cost relationship — NOT ownership transfer.

**Parent can:** aggregate cost, apply governance overlay, query aggregate audit, declare child lifecycle policies  
**Parent cannot:** own child resources, cross child isolation boundaries, override more-restrictive child policies

**Governance inheritance — most restrictive wins (GRP-009):**
```
Most restrictive policy at ANY nesting level wins
  Child policies that are more restrictive than parent → child wins
  Parent policies cascade where child has no policy or is less restrictive
  Platform policies govern all tenant_boundary groups
```

### 10.5 Federated Tenants
A `federation` group contains peer `tenant_boundary` groups. Enables shared policy application, cross-federation visibility, and consolidated reporting. Does NOT grant governance authority — member Tenants remain independent (GRP-010).

### 10.6 Composite Groups
A `composite` group permits all member types — resource entities, policies, layers, and other groups. Enables "everything about Payments" as one organizational unit.

Policy targeting composite groups defaults to all member types. Declare `member_type_filter` to narrow. Policy linting warns if composite is targeted without filter (GRP-012).

### 10.7 GRP System Policies
GRP-001 through GRP-014. Key: GRP-001 (one tenant_boundary per resource), GRP-003 (no circular nesting), GRP-005 (detach is default on destroy), GRP-006 (resource in leaf Tenant always), GRP-009 (most restrictive wins in nesting), GRP-011 (advisory tenancy in prod triggers notification), GRP-013 (former_group_membership permanent), GRP-014 (destruction record permanent).

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

### 11.11 Lifecycle Policy Conflict Resolution (Q57 resolved)
Lifecycle policy fields on relationships are **just fields**. They carry the same `override` metadata, the same provenance obligations, and resolve under the same Policy Engine authority hierarchy as any other DCM field. No special case — minimum variance.

**Priority schema governs conflicts within a tier.** Highest numeric priority runs first. First policy to set `override: immutable` on a lifecycle policy field locks it. `immutable_ceiling: absolute` applies for compliance mandates that must survive future policy changes.

**Ingestion conflict detection applies.** Two policies declaring conflicting lifecycle policies without priority differentiation → CONFLICT ERROR at ingestion.

**DCM System Policies:**
- `REL-008` — A `constituent` relationship lifecycle policy may not be set to `ignore` for `on_related_destroy`
- `REL-009` — Lifecycle policy conflicts between policies are resolved by the standard Policy Engine authority hierarchy — no special case

### 11.12 Relationship Type × Nature Matrix (valid combinations)

The two relationship dimensions form an explicit matrix. Invalid combinations are rejected by the Policy Engine at request time (REL-013).

| | `constituent` | `operational` | `informational` |
|---|---|---|---|
| **`requires`** | ✅ Core constituent | ✅ Hard operational dependency | ❌ Invalid |
| **`depends_on`** | ✅ Soft constituent | ✅ **Allocated resource cell** | ✅ Awareness |
| **`contains`** | ✅ Ownership container | ⚠️ Rare — justify explicitly | ❌ Invalid |
| **`references`** | ❌ Invalid | ❌ Invalid | ✅ **Business context cell** |
| **`peer`** | ❌ Invalid | ✅ Operational peers | ✅ Informational peers |
| **`manages`** | ✅ Component management | ✅ Operational management | ✅ Audit management |

- `operational` + `depends_on` = **allocated resource cell** — cross-tenant allocations live here
- `informational` + `references` = **business context cell** — Business Unit, Cost Center etc.

### 11.13 Cross-Tenant Relationships (Q59 resolved)

Relationship **nature** governs cross-tenant permissions:

| Nature | Cross-Tenant? | Rule |
|--------|--------------|------|
| `constituent` | ❌ Never | REL-010 |
| `operational` | ✅ With dual authorization | REL-011 |
| `informational` | ✅ Unless deny_all | REL-012 |

**Hard tenancy declaration** on Tenant entity:
```yaml
hard_tenancy:
  cross_tenant_relationships: operational_only
  # deny_all | operational_only | informational_only | allow_all
```

### 11.14 Allocated Resource Model (Q59 extension, Q61 partial)

An **Allocated Resource** is a pre-defined discrete slice of a parent resource made available by the owning Tenant for consuming Tenants to claim. It becomes a **first-class entity** in the consuming Tenant's scope with its own UUID, lifecycle, and governance.

**Relationship:** `depends_on` + `operational` + `cross_tenant: true` + `allocation_uuid`

**Parent pre-defines** `available_allocations` — consuming Tenant claims → DCM creates allocated entity + relationship → parent tracks in `active_allocations` with `notification_endpoint`.

**Lifecycle events** propagate from parent to all active allocations per each allocation's `parent_lifecycle_policy`:
`on_parent_destroy | on_parent_suspend | on_parent_maintenance | on_parent_degrade | on_parent_capacity_change`

**System policies:** REL-013 (invalid matrix combinations rejected), REL-014 (claim requires available allocation record)

### 11.15 Shared Resource Model — Same-Tenant (Q61 resolved)

A **Shared Resource** is an entity within a single Tenant that has active relationships from multiple parent entities. DCM maintains `active_relationship_count` — the number of active constituent/operational relationships. Informational relationships never count (REL-016).

**`sharing_model` on entity:**
```yaml
sharing_model:
  shareable: true
  sharing_scope: tenant
  active_relationship_count: 3   # DCM-maintained
  minimum_relationship_count: 0
  on_last_relationship_released: <destroy | retain | notify>
```

**`shareability` on Resource Type Specification:**
- `shareability.allowed: true` — instances can have multiple active relationships
- `shareability.allowed: false` (e.g., `Compute.BootDisk`) — second relationship rejected (REL-017)
- `max_active_relationships` — optional cap (e.g., license seat limits)

**Destruction deferral (REL-015):** Destructive lifecycle actions on shared resources are deferred until `active_relationship_count` reaches `minimum_relationship_count`. Deferred destruction is recorded in `deferred_destruction_record`.

### 11.16 Lifecycle Action Hierarchy — Save Overrides Destroy (REL-018)

When multiple relationships produce different lifecycle action recommendations on a shared resource, the most conservative action wins:

```
retain > notify > suspend > detach > cascade > destroy
```

`retain` always beats `destroy` — the save_overrides_destroy rule. Applies automatically per REL-018.

**Conflict detection (REL-019):** When recommendations differ, a `lifecycle_conflict_record` is created:
- Severity `info` — hierarchy resolved cleanly (e.g., retain beats destroy non-adjacent)
- Severity `warning` — adjacent levels or `notify` is the winning action — notifications sent
- Severity `critical` — immutable lifecycle lock overridden by REL-018 — platform admin notified

**Unified model:** Same-tenant sharing (`active_relationship_count`) and cross-tenant allocation (`active_allocations`) are the same reference-counting concept at different scopes. Both defer destructive actions until the last relationship/allocation is released.

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

**Query Contract**
- Support `reserve_query` — atomic: verify constraints + return metadata + place hold
- Support `capacity_query` (informational, no hold)
- Support `metadata_query` (informational, no hold)
- Declare which query types and metadata fields are supported in provider registration
- Complete missing metadata in realized payload or discovery loop
- `reserve_query` response must include `missing_metadata` for any requested fields not returned

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
- **Process Providers** — purely process-based workflow or automation
- **Policy Providers** — supply policies; Mode 4 evaluates/enriches via black box query
- **Message Bus Providers** — bidirectional bridge to external message buses (Kafka, AMQP, NATS, etc.)
- **Credential Providers** — resolve secrets from external stores (Vault, AWS SM, Azure KV, CyberArk, etc.)
- **Auth Providers** — authenticate identities and resolve permissions (OIDC, LDAP, AD, FreeIPA, etc.)
- **Real-world providers** are typically combinations of the above

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

### 17.9 Policy Placement Phase
Every policy declares when in the assembly process it executes:
- `pre` — before placement (default) — no provider context
- `loop` — inside the placement loop — has reserve query response data
- `post` — after placement confirmed — has full placement block
- `both` — pre and post

### 17.10 Policy Required Context
Policies declare what fields they need and what to do when fields are absent:
```yaml
required_context:
  - field: placement.provider_metadata.sovereignty_certifications
    if_absent: <gatekeep | warn | skip>
    if_absent_reason: <human-readable>
```
If no policy declares `required_context` for an absent field → `implicit_approval` recorded in `policy_gap_record`. The system has no implicit opinion beyond what policies state.

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

### 18.6 Greening the Brownfield — Unified Ingestion Model
Bring existing unmanaged infrastructure under DCM lifecycle management using the unified ingestion model (see Section 20 and data model document 13-ingestion-model.md). The same three-step pattern applies to both brownfield ingestion and V1 migration:

```
1. INGEST   — bring the entity into DCM with whatever identity/metadata is available
2. ENRICH   — associate business data, ownership, Tenant assignment, relationships
3. PROMOTE  — transition from holding state to full DCM lifecycle ownership
```

**Brownfield flow:** Service Provider performs discovery → DCM identifies unmanaged Discovered State records → Entity stubs created (state: INGESTED, Tenant: `__transitional__`) → Business data and Tenant assigned → Promotion authorized → Discovered State promoted to Realized State → Drift detection active from this point.

**V1 Migration flow:** V1 resources inventoried → Auto-assignment attempted via signals (resource groups, business unit, request history) → Auto-assignable resources assigned in bulk → Manually assignable resources surfaced in admin queue → Orphaned resources assigned to `__transitional__` → Enrichment and promotion → Migration complete when `__transitional__` Tenant is empty.

**Key concepts:**
- `__transitional__` Tenant — system-managed holding area for unassigned ingested entities. Cannot be deleted or used for new provisioning. Governance policy enforces max residency and escalation.
- `ingestion_record` — provenance record on every ingested entity: source, confidence, assignment method, enrichment history, promotion timestamp
- Ingestion confidence: `high` (strong signal) | `medium` (inferred) | `low` (orphaned)
- Entities in `INGESTED` or `ENRICHING` state cannot be parents for allocated resource claims or hard dependencies for new requests

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

## SECTION 20 — INGESTION MODEL

The Ingestion Model is the **unified mechanism for bringing entities that exist outside DCM's lifecycle control into DCM governance**. It covers V1 Migration, Brownfield Discovery, and Manual Import — all follow the same pattern.

### 20.1 Three-Step Pattern
```
INGEST  → ENRICH  → PROMOTE  → OPERATIONAL
```

### 20.2 Ingestion Lifecycle States

| State | Tenant | New Requests? | Parent for Allocations? | New Relationships? |
|-------|--------|--------------|------------------------|-------------------|
| `INGESTED` | `__transitional__` or assigned | No | No | Informational only |
| `ENRICHING` | Assigned | No | No | Operational (read-only) |
| `PROMOTED` | Assigned | Yes | Yes | All types |

### 20.3 The `__transitional__` Tenant
System-managed holding Tenant for unassigned ingested entities:
- Cannot be deleted, renamed, or used for new resource provisioning
- Governance policy enforces `max_residency_days` and escalation action
- Hard tenancy: `operational_only` by default
- `created_via: system` — artifact metadata

### 20.4 Ingestion Record
Every ingested entity carries an `ingestion_record` in provenance:
- `ingestion_source` — `v1_migration | brownfield_discovery | manual_import`
- `assigned_tenant_uuid` — real Tenant or null if still in `__transitional__`
- `assignment_method` — `auto | manual | transitional`
- `assignment_signal` — human-readable description of what drove auto-assignment
- `ingestion_confidence` — `high | medium | low`
- `enrichment_status` — `pending | partial | complete`
- `enrichment_history` — append-only log of all enrichment actions
- `promoted_at` — when entity reached PROMOTED state

### 20.5 Auto-Assignment Signal Priority
DCM attempts auto-assignment in this order (configurable):
1. Explicit ownership metadata (high confidence)
2. Resource group membership (high confidence)
3. Request history (high confidence)
4. Network/location context (medium confidence)
5. Naming convention (medium confidence)
6. Provider context (medium confidence)
7. No signal → `__transitional__` (low confidence)

### 20.6 V1 Migration (Q55 resolved)
V1 resources have no `tenant_uuid`. V2 requires one (TEN-001). Migration uses the ingestion model:
- Pre-migration analysis pass classifies all V1 resources: `auto_assignable | manually_assignable | orphaned`
- Auto-assignable → bulk Tenant assignment + ingestion record
- Manually assignable → admin queue for human review and assignment
- Orphaned → `__transitional__` Tenant + governance timer
- Migration complete when `__transitional__` Tenant is empty

### 20.7 Brownfield Ingestion
Unmanaged discovered entities follow the same ingestion model:
- Service Provider discovery creates Discovered State records
- DCM identifies unmanaged Discovered State records (no matching Realized State)
- Entity stubs created (state: INGESTED, source: brownfield_discovery)
- Enriched → promoted → Discovered State becomes initial Realized State
- Drift detection active from promotion forward

### 20.8 DCM System Policies for Ingestion

| Policy | Rule |
|--------|------|
| `ING-001` | Every ingested entity must be assigned to one Tenant — real or `__transitional__` — before V2 eligibility |
| `ING-002` | Entities in `INGESTED` or `ENRICHING` state may not be parents for allocated resource claims |
| `ING-003` | `__transitional__` Tenant cannot be deleted, renamed, or used for new provisioning |
| `ING-004` | Every ingested entity must carry an `ingestion_record` in provenance |
| `ING-005` | Entities in `__transitional__` beyond `max_residency_days` must trigger configured escalation |
| `ING-006` | Brownfield entities may not be promoted without explicit actor authorization |
| `ING-007` | At brownfield promotion, Discovered State is promoted to Realized State — DCM assumes lifecycle ownership |

---

## SECTION 21 — POLICY ORGANIZATION: GROUPS, PROFILES, AND POLICY PROVIDERS

### 21.1 Three-Level Policy Organization
```
Policy Profile     — complete use-case configuration (composed of groups)
  │
Policy Groups      — single-concern policy collections (composed of policies)
  │
Policies           — individual Transformation / Validation / GateKeeper rules
  │  optionally sourced from
Policy Providers   — external authoritative policy sources (fifth provider type)
```

### 21.2 Policy Groups
A **Policy Group** is a cohesive collection of policies addressing a single identifiable concern.

**Concern types:** `technology | compliance | sovereignty | business | operational | security`

**Key fields:** `handle` (domain/group/name), `concern_type`, `concern_tags`, `extends` (inherits parent), `policies` (constituent policies), `activation_scope` (resource types, tenant tags, regions), `conflicts_with` (explicit conflict declarations), `source` (local or policy_provider)

**DCM built-in groups include:** core-minimal, dev-defaults, ephemeral-resources, audit-basic, audit-compliance, data-classification, cost-governance, sla-enforcement, hard-tenancy, explicit-cross-tenant, zero-trust, encryption-baseline, pci-dss, gdpr-eu, nist-800-53, iso-27001, fsi-audit, lifecycle-ttl-enforcement, air-gap, kubevirt, openstack, vmware

### 21.3 Policy Profiles
A **Policy Profile** is a complete DCM configuration for a specific use case composed of Policy Groups.

**Six DCM built-in profiles (least to most restrictive):**

| Profile | Handle | Tenancy | Enforcement | Cross-Tenant | Audit |
|---------|--------|---------|-------------|-------------|-------|
| `minimal` | `system/profile/minimal` | Optional — auto-created | Advisory only | allow_all | None |
| `dev` | `system/profile/dev` | Recommended | Warn only | operational_only | Basic 90-day |
| `standard` | `system/profile/standard` | Required | Blocking | explicit_only | Compliance-grade |
| `prod` | `system/profile/prod` | Required | Blocking + SLA | explicit_only | Compliance-grade |
| `fsi` | `system/profile/fsi` | Hard tenancy | Blocking | explicit_only | 7-year retention |
| `sovereign` | `system/profile/sovereign` | Hard tenancy | Blocking | deny_all | 10-year retention |

**Profile inheritance chain:** `system/profile/sovereign` extends `system/profile/fsi` extends `system/profile/prod` extends `system/profile/standard` extends `system/profile/dev` extends `system/profile/minimal`

**Profile activation levels (more specific wins):**
```yaml
installation_config:  default_profile: minimal
platform_config:      active_profile: prod; minimum_tenant_profile: dev
tenant_config:        active_profile: fsi  # must be >= minimum_tenant_profile
```

**Profile shadow validation:** proposed profiles run in shadow mode before activation — same as proposed policies.

### 21.4 Policy Provider (Fifth Provider Type)
A **Policy Provider** is a fifth DCM provider type — an external authoritative source supplying policies into DCM or evaluating/enriching data via external logic.

**Four delivery modes:**

| Mode | Name | `delivery.mode` value | Logic Lives In |
|------|------|----------------------|---------------|
| 1 | DCM Native Push/Pull | `push` / `pull` / `webhook` | DCM Policy Engine |
| 2 | OPA/Rego Bundle | `opa_bundle` | DCM Policy Engine (OPA) |
| 3 | External Schema (naturalization) | `external_schema` | DCM Policy Engine (post-translation) |
| 4 | Black Box Query-Enrichment | `black_box_query` | External provider — opaque to DCM |

**Modes 1-3** deliver policy rules. **Mode 4** is a query-response interface — DCM sends data, external system evaluates and/or enriches, returns structured result.

**Mode 4 can:**
- **Evaluate** — return pass/fail, score, or recommendation
- **Enrich** — inject additional fields into the payload (risk scores, compliance citations, cost predictions, org context, case references)
- **Both** — multi_factor result combining decision + enrichment

**Mode 4 governance requirements:**
- Data sovereignty check before ANY query is sent (BBQ-001, BBQ-003)
- Data minimization — only declared fields sent (BBQ-002)
- Full audit record per query-response cycle (BBQ-004) including `audit_token` for cross-system correlation
- Default failure behavior is `gatekeep` — unknown is not safe (BBQ-005)
- Injected enrichment fields carry standard field-level provenance with `source_type: black_box_provider` + `audit_token` (BBQ-007)
- Override control applies to injected fields — GateKeeper can refuse enrichment (BBQ-008)
- Mode 4 enrichment providers require minimum `transformation` trust level (BBQ-009)

**Trust levels (all modes):**
- `trusted` → GateKeeper authority (dual approval elevation required)
- `verified` → Transformation/Validation only; Mode 4 enrichment minimum
- `untrusted` → advisory only

**`on_update` (Modes 1-3):** `proposed` (shadow validation) | `active` (immediate — trusted only)
**On provider failure:** policies deprecated with configurable sunset; Mode 4 → `on_unavailable` behavior fires

### 21.5 Lifecycle Time Constraints
First-class field on any resource entity. Follow standard data model precedence and override control.

**Two types:**
- `ttl` — ISO 8601 duration relative to reference_point (created_at | realization_timestamp | last_modified)
- `expires_at` — absolute ISO 8601 timestamp

When both declared, earliest wins (LTC-004). GateKeeper can lock as `override: immutable`.

**`on_expiry` actions:** `destroy | suspend | notify | review`

Expiry enforcement is a DCM control plane function — not a provider concern. Failed expiry action → `PENDING_EXPIRY_ACTION` state + escalation (LTC-005).

### 21.6 Cross-Tenancy Authorization — Explicit_Only Default
Default stance is now **`explicit_only`** — informational sharing is NOT open by default. Every cross-tenant relationship of any nature requires an explicit `cross_tenant_authorization` record.

**Authorization specifies who/what/when/where:**
```yaml
cross_tenant_authorization:
  authorized_consumer_tenant_uuid: <uuid>    # WHO
  permitted_fields: [field1, field2]         # WHAT — empty = all fields
  valid_from/valid_until: <ISO 8601>         # WHEN
  permitted_in_regions: [eu-west]            # WHERE
  authorization_level: <tenant_global | resource_specific | field_specific>
  # Hierarchy: field_specific > resource_specific > tenant_global (more specific wins)
```

All cross-tenant authorization decisions are policy-driven and DCM-enforced (XTA-004).

### 21.7 Rehydration Tenancy Controls
Tenancy controls, sovereignty directives, and cross-tenant authorizations **always use current policies during rehydration — cannot be pinned**.

**`policy_version: pinned`** governs resource configuration policies only. Tenancy/sovereignty always current.

When rehydration conflicts with current tenancy controls → entity enters **PENDING_REVIEW** state:
- Allocation not automatically released
- Notifications: entity owner, both Tenant admins, platform admin
- Resolution: re_authorize | release | escalate
- A policy may declare automatic resolution behavior (RHY-004)

### 21.8 System Policy Summary

**LTC:** LTC-001 through LTC-005 — lifecycle time constraint enforcement  
**XTA:** XTA-001 through XTA-005 — cross-tenancy authorization model  
**RHY:** RHY-001 through RHY-004 — rehydration tenancy controls  
**DEP:** DEP-001 through DEP-003 — cross-tenant dependency rules  
**BBQ:** BBQ-001 through BBQ-009 — Mode 4 black box query-enrichment governance

---

## SECTION 22 — UNIVERSAL GROUP MODEL

DCM collapses all grouping constructs into a single **DCMGroup** entity with `group_class` metadata. One mental model, one API, one registry. See `15-universal-groups.md` for the complete model.

### 22.1 Group Classes

| group_class | Replaces | member_types_permitted | exclusivity |
|-------------|---------|----------------------|------------|
| `tenant_boundary` | Tenant | resource_entity, group | one (structural lock) |
| `resource_grouping` | Resource Group | resource_entity | many |
| `policy_collection` | Policy Group | policy | many |
| `policy_profile` | Policy Profile | group | many |
| `layer_grouping` | Layer grouping | layer | many |
| `provider_grouping` | Provider collections | provider | many |
| `composite` | (new) | all types | many |
| `federation` | (new) | group (tenant_boundary) | many |

### 22.2 Structural Invariants (non-overridable)
- `GRP-INV-001` — resource_entity belongs to exactly one tenant_boundary group
- `GRP-INV-002` — constituent relationships cannot cross tenant_boundary boundaries
- `GRP-INV-003` — destroying parent tenant_boundary requires explicit resolution of all children first
- `GRP-INV-004` — resource in child tenant_boundary belongs to child — never parent
- `GRP-INV-005` — circular group membership invalid
- `GRP-INV-006` — group cannot be a member of itself

### 22.3 Composite Groups
`member_types_permitted: [resource_entity, policy, layer, group, provider]`. Policies targeting composite groups apply to all member types by default. Narrow with `member_type_filter`.

### 22.4 Nested Tenants
`tenant_boundary` group with `parent_group_uuid`. Parent has governance overlay and cost rollup — not ownership. Policy inheritance direction is profile-governed (opt_in for minimal/dev/fsi/sovereign; opt_out for standard/prod).

### 22.5 Federated Tenants
`federation` group containing `tenant_boundary` groups as peers. Members remain fully independent. Enables shared governance, consolidated reporting, scoped cross-member visibility.

### 22.6 API Backward Compatibility
`GET /tenants` → `GET /groups?group_class=tenant_boundary`. All existing UUIDs and API endpoints preserved.

---

## SECTION 23 — UNIVERSAL AUDIT MODEL

Every modification to every DCM artifact produces an audit record. No exceptions. See `16-universal-audit.md` for the complete model.

### 23.1 Four Required Fields
**Date/time** (ISO 8601 microseconds) | **Who** (composite actor chain) | **What** (subject entity) | **Action** (closed vocabulary)

### 23.2 Two-Stage Audit — Synchronous Commit + Async Enrichment

**Stage 1 (synchronous, < 1ms, in critical path):**
```yaml
commit_log_entry:
  entry_uuid: <uuid>
  sequence: <integer>           # monotonically increasing
  timestamp: <ISO 8601 microseconds>   # AUTHORITATIVE audit timestamp
  entity_uuid / entity_type / action / actor_uuid / tenant_uuid
  change_fingerprint: <SHA-256>
  status: pending_forward
```
Written using Raft consensus — confirmed when quorum (2/3 or 3/5) of Commit Log replicas acknowledge. Operation returns success after Stage 1. Stage 1 timestamp is the authoritative audit timestamp (AUD-013).

**Stage 2 (asynchronous, out of critical path):**
Audit Forward Service enriches minimal Commit Log entry → full audit_record → hash chain computed → written to Audit Store with retry. Full record visible seconds to minutes after Stage 1.

### 23.3 Composite Actor Chain — The "Who"
```yaml
actor:
  immediate:
    type: <human|system_component|policy|provider|scheduled_job|mode4_provider>
    uuid / display_name
  authorized_by:
    uuid / authorization_method: <direct_action|request_submission|policy_activation|system_policy|scheduled>
  request_uuid / policy_uuid / correlation_id
```

### 23.4 Action Vocabulary (closed — AUD-007)
`CREATE | MODIFY | STATE_TRANSITION | DELETE | ACTIVATE | DEACTIVATE | DEPRECATE | RETIRE | MEMBER_ADD | MEMBER_REMOVE | RELATIONSHIP_CREATE | RELATIONSHIP_RELEASE | AUTHORIZE | REVOKE | EVALUATE | ENRICH | LOCK | HOLD_PLACE | HOLD_CONFIRM | HOLD_RELEASE | DRIFT_DETECT | DRIFT_RESOLVE | INGEST | PROMOTE | EXPIRE | REHYDRATE | QUERY | DISCOVER | LOGIN | LOGOUT | CONFIG_CHANGE`

### 23.5 Retention — Reference-Based
- `retention_status: live` — any referenced entity non-retired → retain unconditionally
- `retention_status: all_retired` → apply governing policy
- Post-lifecycle defaults: dev=P90D, standard=P3Y, prod/fsi=P7Y (DEFAULT), sovereign=P10Y

### 23.6 Tamper-Evidence — Hash Chain
`record_hash` (SHA-256 of record) + `previous_record_hash` (preceding record for this entity) + `chain_sequence`. Chain breaks detectable and trigger security alerts (AUD-010).

### 23.7 Recoverability
- DCM crash after Stage 1 → Audit Forward Service replays `pending_forward` entries on restart (AUD-011)
- Audit Store unavailable → Commit Log accumulates; Audit Forward Service retries when recovered
- Commit Log quorum unavailable → operation aborted — no silent change

### 23.8 System Policies
- `AUD-001` — Every modification produces Commit Log entry synchronously; Commit Log write failure aborts operation
- `AUD-002` — Audit records append-only and immutable while retention obligations apply
- `AUD-003` — Audit records survive at least as long as any referenced entity is live
- `AUD-004` — Post-lifecycle retention governed by policy; default P7Y
- `AUD-005` — Actor field must identify immediate actor + authorized_by chain
- `AUD-006` — record_hash + previous_record_hash hash chain required
- `AUD-007` — Action field must use closed vocabulary
- `AUD-008` — Audit Store must support queries by entity_uuid, actor_uuid, action, timestamp range, tenant_uuid, request_uuid, retention_status
- `AUD-009` — Audit Forward Service delivers with exponential backoff retry; cleared only after Audit Store confirmation AND retention window
- `AUD-010` — Hash chain verification first-class; chain breaks trigger immediate security alerts
- `AUD-011` — On restart, Audit Forward Service replays all pending_forward entries before accepting new operations
- `AUD-012` — Commit Log uses Raft consensus with quorum writes
- `AUD-013` — Stage 1 Commit Log timestamp is authoritative audit timestamp

---

## SECTION 24 — DEPLOYMENT AND REDUNDANCY

Every DCM component and store is designed for redundancy by default. Everything containerized. Profile-governed. Self-hosting. See `17-deployment-redundancy.md` for the complete model.

### 24.1 Core Principles
- **Redundant by default** — every component and store has a redundancy model
- **Everything containerized** — all components run as Kubernetes pods; no bare-metal DCM
- **Profile-governed** — replica counts and quorum set by active Profile; not per-component
- **Stateless control plane** — all state in external stores; any pod can fail and be replaced
- **Self-hosting** — DCM's own deployment is a DCM resource; DCM manages itself

### 24.2 Redundancy Matrix by Profile

| Profile | CP Replicas | Store Replicas | Write Quorum | Zone Spread | Geo-Replication |
|---------|------------|---------------|-------------|------------|----------------|
| `minimal` | 1 | 1 | No | No | No |
| `dev` | 1 | 1 | No | No | No |
| `standard` | 3 | 3 | 2/3 | Preferred | No |
| `prod` | 3 | 3 | 2/3 | Required | Yes |
| `fsi` | 5 | 5 | 3/5 | Required | Yes |
| `sovereign` | 5 | 5 | 3/5 | Required | Within boundary |

### 24.3 Store Redundancy Model

| Store | Implementation | Write Quorum | Notes |
|-------|---------------|-------------|-------|
| Commit Log | etcd (Raft) | 2/3 | Stage 1 audit; < 1ms write |
| GitOps Store | Gitea/equivalent | 2/3 | Intent, Requested, Layers, Policies |
| Event Stream | Kafka/equivalent | 2/3 | Realized, Discovered, Audit events |
| Audit Store | Elasticsearch/equivalent | 2/3 | Indexed, queryable, compliance-grade |
| Search Index | Elasticsearch/equivalent | 1 | Non-authoritative — rebuildable from Git |

### 24.4 Pod Security Model (all components)
`run_as_non_root: true` | `run_as_user: 65534` | `read_only_root_filesystem: true` | `allow_privilege_escalation: false` | `capabilities.drop: [ALL]` | mTLS for all inter-component communication (RED-009)

### 24.5 Self-Hosting
DCM's own deployment is declared as a `dcm_deployment` DCM resource in Git. DCM runs drift detection on its own components. Bootstrap sequence: bootstrap installer → reads `dcm_deployment` from Git → provisions to target redundant state → hands off.

### 24.6 The Repave Scenario
DCM lost entirely → bootstrap installer on new cluster → reads `dcm_deployment` from Git → provisions itself → rehydrates customer workloads in dependency order → drift detection validates. Recovery bounded by infrastructure provisioning speed — not backup restoration.

### 24.7 System Policies
- `RED-001` — All DCM components run as containers in Kubernetes pods
- `RED-002` — All control plane components stateless
- `RED-003` — Profiles above `minimal`: replicas >= 3 with anti-affinity
- `RED-004` — Profiles above `minimal`: quorum writes with write_quorum >= 2
- `RED-005` — Commit Log uses Raft consensus with quorum writes
- `RED-006` — DCM deployment declared as DCM resource in Git
- `RED-007` — DCM runs drift detection on its own components
- `RED-008` — Rolling updates must not reduce replicas below min_available
- `RED-009` — All component communication uses mTLS
- `RED-010` — Bootstrap manifest is the only DCM config outside DCM's management scope

---

## SECTION 25 — WEBHOOKS, MESSAGING, AND EXTERNAL INTEGRATION

### 25.1 The Three Integration Mechanisms
- **Outbound Webhooks** — DCM pushes event notifications to external HTTP endpoints
- **Inbound Webhooks** — External systems push requests, queries, and events to DCM
- **Message Bus Provider** — Persistent bidirectional event streaming with external message buses

All three are authenticated, authorized, and audited identically to any other DCM API call. No privileged back-channel.

### 25.2 Universal Ingress/Egress Actor Model

Every request carries an immutable `ingress` block set by the DCM ingress layer:
```yaml
ingress:
  surface: <web_ui|consumer_api|webhook_inbound|message_bus_inbound|
            provider_callback|policy_engine|scheduler|rehydration|
            ingestion|dcm_internal|operator_cli>
  protocol: <https|amqp|kafka|grpc|websocket>
  authenticated_via: <hmac_sha256|mtls|bearer_token|oidc|ldap|...>
  actor:
    uuid / type / display_name / identity_source
    auth_provider_uuid / auth_provider_type
    roles / tenant_scope / groups / permissions
    authorized_by: {method, authorizing_entity_uuid, expiry}
    session_uuid / mfa_verified
    external_identity: {provider, subject, claims}
  webhook_registration_uuid / message_bus_provider_uuid / parent_request_uuid
  source_ip  # audit only — never used for authorization
```
The ingress block is immutable — policies may read but never modify it. Carried verbatim into audit records. Policies can act on any ingress field (surface, actor.roles, auth_provider_type, mfa_verified, etc.).

Egress calls carry DCM's authenticated identity via the `egress` block: component, authenticated_via, credential_ref, originating_request_uuid.

### 25.3 Outbound Webhooks
Optional and policy-governed. Profile sets defaults — fsi/sovereign may require via Policy Group.

Key properties:
- **Schema adapters** — consumer pins to a schema version; DCM transforms forever; 90-day deprecation notice
- **Managed secret rotation** — automatic with transition window; consumer notified via signed event
- **Endpoint health** — suspend-not-delete on failure; full config retained for reactivation
- **Versioned registrations** — standard DCM artifact lifecycle; Git-managed
- **Sovereignty-aware** — delivery blocked if endpoint jurisdiction incompatible with Tenant sovereignty

Delivery: at-least-once; per-entity ordering guaranteed; cross-entity ordering not guaranteed; `event_uuid` is idempotency key.

### 25.4 Inbound Webhooks
DCM exposes typed authenticated endpoints:
- `POST /webhooks/inbound/request` — submit service request
- `POST /webhooks/inbound/query` — query entity state/catalog
- `POST /webhooks/inbound/event` — push provider state change / CI/CD signal
- `POST /webhooks/inbound/ingestion` — push brownfield ingestion data
- `POST /webhooks/inbound/data` — push enrichment or information data

Callers must be registered as **webhook actors** with role, tenant_scope, permitted_operations, and rate_limit. Full Policy Engine evaluation — same as any other API call. Returns 202 Accepted + request_uuid for async operations.

### 25.5 Message Bus Provider (Sixth Provider Type)
Persistent bidirectional event streaming. Supports: kafka, amqp, nats, mqtt, azure_service_bus, aws_eventbridge, gcp_pubsub, rabbitmq, custom.

Inbound messages processed as authenticated API calls via registered webhook actor identity. Same Policy Engine evaluation as inbound webhooks.

Architecture: internal Message Bus → Message Bus Bridge Service ↔ external message bus.

### 25.6 Webhook System Policies
WHK-001 through WHK-014 — see doc 18. Key: ING-008 (ingress block immutable), ING-009 (full actor context required), ING-010 (egress authenticated), ING-011 (no anonymous access), ING-012 (webhook/message bus always authenticated).

---

## SECTION 26 — AUTHENTICATION, AUTHORIZATION, AND AUTH PROVIDERS

### 26.1 Auth Provider — The Eighth Provider Type
An **Auth Provider** answers two questions: (1) is this identity who they claim to be? and (2) what are they permitted to do? Every authentication mode is an Auth Provider implementation.

**Authentication is always required — no anonymous access in any profile.** The difference between profiles is how much effort setup requires.

### 26.2 Built-In Auth Provider (zero configuration)
Always registered, cannot be deregistered. Supports:
- **Static API key** — generated at bootstrap, shown once, 30 seconds to start
- **Local users** — `dcm user create --username admin --role platform_admin`
- **GitHub/GitLab OAuth** — opt-in, requires client_id + secret

### 26.3 Auth Modes by Profile

| Profile | Auth Modes | Setup Effort |
|---------|-----------|-------------|
| `minimal` | Static API key, Local user/password | 30 seconds – 2 min |
| `dev` | + GitHub/GitLab OAuth, FreeIPA/AD direct bind | 5–15 minutes |
| `standard` | + OIDC via broker, AD/FreeIPA direct | 30–60 minutes |
| `prod` | + OIDC direct, MFA configurable | 1–2 hours |
| `fsi` | + mTLS required, MFA required | 4–8 hours |
| `sovereign` | + Air-gapped OIDC/mTLS | 1–2 days |

No anonymous access in any profile. No static API key in standard+. mTLS required in fsi/sovereign.

### 26.4 LDAP / FreeIPA / Active Directory
FreeIPA: direct LDAP bind with optional Kerberos SSO and HBAC enforcement. Ideal for Red Hat / Linux-first environments.

Active Directory: LDAP bind with `LDAP_MATCHING_RULE_IN_CHAIN` (OID 1.2.840.113556.1.4.1941) for nested group resolution. `sAMAccountName` or UPN for user lookup. Automatic DC failover.

Both support: group_role_map (external groups → DCM roles), tenant_mapping (external groups → DCM Tenants), group_sync (interval-based re-sync), multiple domain controllers for failover.

### 26.5 Multiple Auth Providers and Routing
Multiple providers registered simultaneously. Ingress layer routes based on authentication signal (mtls_client_cert → mtls provider; bearer_token → OIDC or API key provider; basic_auth → LDAP; hmac_signature → webhook provider; none → reject).

Auth providers can be chained: authentication (LDAP bind) → enrichment (LDAP groups) → augmentation (OIDC userinfo for rich claims like department, cost_center).

### 26.6 Credential Provider (Seventh Provider Type)
Cross-cutting dependency for all secret resolution. Supports: hashicorp_vault, aws_secrets_manager, azure_key_vault, gcp_secret_manager, kubernetes_secrets, cyberark, delinea, external_api, dcm_internal.

All provider registrations, webhook configurations, and Auth Provider connections reference credentials via:
```yaml
secret_ref:
  credential_provider_uuid: <uuid>
  secret_path: "dcm/path/to/secret"
  version: latest
```
Credentials never stored in Git. Never appear in audit record values (only secret_path logged). Cached in memory with configurable TTL.

### 26.7 Auth Provider Health
On unhealthy: existing sessions remain valid until TTL expiry; new auth attempts route to fallback_provider_uuid or are rejected. On_unhealthy options: alert, fallback_to_next, block_new_sessions.

### 26.8 System Policies
AUTH-001 through AUTH-010 — see doc 19. Key: AUTH-008 (no anonymous access in any profile), AUTH-009 (webhook/message bus always authenticated), AUTH-007 (credentials always via Credential Provider).

---

## SECTION 27 — REGISTRY GOVERNANCE

### 27.1 The Three-Tier Registry

| Tier | Name | Maintained By | Contains |
|------|------|--------------|---------|
| 1 | DCM Core | DCM Project team | Universal types (Compute.VirtualMachine, Network.VLAN, etc.) |
| 2 | Verified Community | Named community maintainers | Technology-specific types (OpenStack.HeatStack, KubeVirt.VirtualMachine) |
| 3 | Organization | Deploying organization | Organization-specific/proprietary types |

### 27.2 The Federated Registry Model
Not centralized, not fully distributed — federated:
```
DCM Project Registry (origin) → Organization Registry (local mirror) → Air-gapped Registry (offline copy)
```
Every DCM deployment has exactly one active **Registry Provider** (sub-type of Information Provider). Air-gapped deployments use signed bundles verified against the organization's public key — no external connectivity required.

### 27.3 PR-Based Proposal Workflow (Q9)
Resource Type proposals are Pull Requests against the registry repository. Automated gates before review: schema validation, FQN conflict check, dependency resolution, breaking change detection, test case coverage. Shadow validation in `proposed` status is mandatory before `active` promotion.

**Review periods by change type:** Revision=3 days, Minor/Tier2=7 days, Tier1=14 days, Breaking=21 days, Deprecation=30 days, Emergency=waived (7-day shadow minimum).

### 27.4 Deprecation Lifecycle — Default Policies (Q11)
Deprecation lifecycle is governed by **default DCM system policies** (REG-DP-001 through REG-DP-007), overridable via standard policy priority. FSI/sovereign profiles lock sunset periods as immutable.

| Policy | Default | Overridable? |
|--------|---------|-------------|
| `REG-DP-001` | 30-day notification before deprecation | Yes |
| `REG-DP-002` | Sunset: Tier 1=P12M, Tier 2=P6M | Yes (locked in fsi/sovereign) |
| `REG-DP-003` | Migration window: P90D after retirement | Yes |
| `REG-DP-004` | Successor type required in deprecation notice | Yes |
| `REG-DP-005` | Retired types reject new requests | **No — structural** |
| `REG-DP-006` | Existing realizations → DEPRECATED_RUNTIME | Yes |
| `REG-DP-007` | Emergency migration floor: P30D | **No — floor** |

DEPRECATED_RUNTIME: eligible for modify/decommission; not eligible for rehydration using deprecated type; drift detection continues.

### 27.5 Version Resolution Policy (Q12)
Strictly enforced — no silent resolution to different version. DCM never auto-upgrades across major versions.

`version_policy` options: `exact` | `compatible` (^major) | `latest_minor` (~minor) | `latest`

Profile defaults: minimal=latest, dev/standard/prod=compatible, fsi/sovereign=exact.

### 27.6 Provider Tie-Breaking Hierarchy (Q13)
When multiple providers satisfy all placement criteria equally:
1. **Policy preference** — Transformation policy injected preference_score or preferred_provider_uuid
2. **Provider priority** — numeric field on registration (default: 50; higher = preferred)
3. **Tenant affinity** — Policy Group declares preferred providers for resource types
4. **Cost analysis** — if Cost Analysis has current data AND cost is determinable and comparable (skip if not)
5. **Least loaded** — capacity utilization from reserve_query (skip if data unavailable)
6. **Consistent hash** — SHA-256(request_uuid + resource_type + sorted_candidate_uuids); deterministic, never round-robin

Cost ranks above operational load because it is a business decision. 5% threshold — candidates within 5% cost are treated as equal.

### 27.7 Registry Provider — Policy Governed (Q14)
The Registry Provider is fully policy-governed. Policies act on registry sync, activation, bundle import, and version upgrades. Profile-appropriate registry policy groups activated by default:

| Group | Profile | Behavior |
|-------|---------|---------|
| `system/group/registry-minimal` | minimal | Advisory; pull everything; warn only |
| `system/group/registry-dev` | dev | Warn on unverified sources; Tier 1+2 |
| `system/group/registry-standard` | standard | Block unverified; sovereignty filter |
| `system/group/registry-prod` | prod | Vendor allowlist; audit all syncs; major version manual approval |
| `system/group/registry-fsi` | fsi | Exact pinning; immutable sunset; dual-approval syncs |
| `system/group/registry-sovereign` | sovereign | Signed bundles only; offline; no external connectivity |

### 27.8 System Policies
REG-001 through REG-007 and REG-DP-001 through REG-DP-007 — see doc 20.

---

## SECTION 28 — STORAGE ARCHITECTURE

### 28.1 Git Repository Structure (Q79)
Handle-based directory structure. Four repos: Intent, Requested, Layers, Policies. Minimal/dev may use monorepo; standard+ use separate repos. `main` is authoritative. Tenant isolation under `{tenant-uuid}` directories. DCM service account handles all Git reads/writes — no direct Tenant Git access.

```
dcm-intent/tenants/{tenant-uuid}/requests/{request-uuid}/intent.yaml
dcm-requested/tenants/{tenant-uuid}/requests/{request-uuid}/requested-payload.yaml
dcm-layers/{domain}/{type}/{name}/v{Major}.{Minor}.{Revision}.yaml
dcm-policies/{domain}/{type}/{name}/v{Major}.{Minor}.{Revision}.yaml
```

### 28.2 Multi-Region Replication (Q80)
Declared capability on Storage Provider registration. Active Profile determines minimum requirements:
- minimal/dev: 1 replica, no multi-region
- standard: 3 replicas, strong/bounded consistency
- prod/fsi/sovereign: 3-5 replicas, strong consistency, geo-replicated
- sovereign: multi-region required but within sovereignty boundary only

(STO-001)

### 28.3 Storage Provider Failure Handling (Q81)
Per store type — policy-governed:
- **Commit Log:** quorum unavailable → abort operation (no silent changes)
- **GitOps Stores:** unavailable → queue writes locally (max size + max age); explicit reject on exhaustion
- **Event Stream:** producer queues locally; consumer resumes from last offset on recovery
- **Audit Store:** two-stage model — accumulates in Commit Log; operations not blocked
- **Search Index:** non-authoritative; degrades gracefully; full rebuild on recovery

(STO-002)

### 28.4 Search Index — Separate Sub-Type (Q82)
Separate Storage Provider sub-type — distinct from GitOps stores. Non-authoritative, rebuildable from authoritative stores. Consistency lag declared (e.g., PT5M). API queries may specify `freshness: authoritative` to bypass index. (STO-003)

### 28.5 Audit Store — Specialized Sub-Type (Q83)
Specialized Storage Provider sub-type — NOT the same as Event Stream. Properties: append-only with immutability enforcement, hash chain integrity, reference-based retention tracking, compliance-grade multi-dimensional queries. Event Stream is the delivery channel; Audit Store is the compliance destination. (STO-004)

---

## SECTION 29 — PROVIDER SOVEREIGNTY DECLARATIONS

### 29.1 Obligation
Every provider registration (Service, Information, Message Bus, Policy, Auth Provider) MUST include a `sovereignty_declaration` block. Contractual obligation — not optional metadata.

### 29.2 What Sovereignty Declaration Covers
- **operating_jurisdictions** — countries and legal jurisdictions where provider physically operates
- **legal_frameworks** — applicable frameworks (GDPR, HIPAA, FedRAMP, ITAR, etc.)
- **data_residency_guarantee** — data never leaves declared jurisdictions (true/false)
- **data_transit_jurisdictions** — jurisdictions data transits through during operations
- **external_dependencies** — external connectivity requirements, air_gap_capable flag, external services with data sharing details
- **sub_processors** — third-party sub-processors with jurisdiction and data handled
- **government_access_risk** — which governments can legally compel access
- **certifications** — current certifications with validity periods (ISO-27001, SOC2, PCI-DSS, FedRAMP)
- **audit_rights** — customer audit rights and notice periods
- **change_notification** — mandatory notification events and SLA (e.g., PT24H)

### 29.3 Change Notification and DCM Response
Provider MUST notify DCM when any sovereignty data changes. DCM treats sovereignty changes as discovered drift → Policy Engine re-evaluation:
- **No violations:** update record, emit webhook event, notify Tenants (informational)
- **Violations found:** for each affected resource, policy declares action:
  - `notify_only` — inform Tenant; no automatic action
  - `pause` — suspend resource; Tenant must act
  - `migrate` — Provider-Portable Rehydration to compliant provider (sequential)
  - `emergency_migrate` — parallel provisioning before decommission

Sovereignty violation record created in Audit Store. Notifications: Tenant owner, platform admin, data_protection_officer.

### 29.4 Auto-Migration
Policy declares `migrate` or `emergency_migrate` → DCM uses Provider-Portable Rehydration. Non-compliant provider excluded from placement candidate set. Full audit trail linking violation record to migration request. (SOV-001 through SOV-005)

---

## SECTION 30 — GIT PR INGRESS

### 30.1 Concept
DCM supports `git_pr_merge` and `git_pr_open` as ingress surfaces. Teams submit standard DCM resource definition YAML as Pull Requests. DCM's Git Request Watcher monitors designated repositories.

### 30.2 Git Actor Identity Resolution
**DCM trusts the Git server's authentication assertion — not user-declared Git configuration.** Git `user.email` self-declaration is ignored — spoofing vector.

Resolution methods (all go through registered Auth Provider):
- `oidc_subject_lookup` — Git server OAuth subject → OIDC Auth Provider → DCM actor
- `ldap_username_lookup` — Git server username → LDAP/AD Auth Provider → DCM actor
- `ssh_key_fingerprint` — key fingerprint → DCM SSH key registry → DCM actor
- `webhook_service_account` — CI/CD service account → registered webhook actor

**The resolved actor has IDENTICAL roles, groups, and tenant scope to the same user logging in via web UI.** Git PR ingress does not grant different permissions than any other surface. Same Auth Provider, same group mappings, same tenant scope enforcement.

**Unresolvable identity → explicit PR rejection comment** with actionable guidance. Never silently ignored.

### 30.3 PR Lifecycle
1. PR opened → DCM resolves author → Auth Provider → shadow policy evaluation posted as PR comments
2. Human review + Git branch protection approvals
3. PR merged → actor re-verified at merge time (not assumed from PR open) → full nine-step assembly → realization result posted as PR comment
4. Realized state committed to `realized/` directory (optional)

### 30.4 The git_context in ingress block
```yaml
ingress:
  surface: git_pr_merge
  actor: <fully resolved DCM actor — same as web UI login>
  git_context:
    repository / pr_number / pr_url / merge_commit
    pr_author / pr_reviewers / pr_approved_by
    # pr_approved_by: DCM resolves reviewer Git identities via same Auth Provider
```

### 30.5 Policy Use Cases
- Require specific approvers in pr_approved_by before processing
- Require MFA for Git PR merges in prod Tenants
- Restrict resource types submittable via Git PR
- Require actor to be in authorized Tenant group
- Post shadow evaluation results as PR comments

### 30.6 System Policies
GIT-001 through GIT-008 — see doc 18. AUTH-011 — Git identity resolution uses registered Auth Provider; same role/group/tenant scope as any other ingress.

---

## SECTION 31 — ENTITY AND DEPENDENCY GAPS

### 31.1 Ownership Transfers (Q25)
Ownership transfers are **unlimited by default**. Each transfer is immutably recorded with a monotonically incrementing `transfer_number` and mandatory reason field. Policy may declare a maximum per resource type via GateKeeper. ENT-001.

### 31.2 Bare Metal Indivisibility (Q26)
`Compute.BareMetal` declares `allocation_model: whole_unit` and `shareability.allowed: false` (structural lock). Placement holds are exclusive — no concurrent holds on the same server. Provider must report full physical identity (serial_number, hardware_profile) in realized payload and notify DCM of any sharing attempt. ENT-002.

### 31.3 Capacity Confidence Actions (Q27)
Confidence ratings trigger policy-governed automatic actions:
- `HIGH` → proceed (all profiles)
- `MEDIUM` → proceed_with_warning (minimal/dev) or refresh_before_placement (prod/fsi/sovereign)
- `LOW` → proceed_with_warning (minimal), refresh_before_placement (dev/standard), reject (prod/fsi/sovereign)

LOW confidence triggers a Mode 1 Information Provider query before finalizing placement in standard+ profiles. Policy Group overrides per resource type. ENT-003.

### 31.4 Process Resource Execution Time (Q28)
`max_execution_time` is **mandatory** on Process Resource entities. Enforced by the Lifecycle Constraint Enforcer as a standard TTL. Profile governs default `on_max_exceeded`:
- minimal/dev: `notify`
- standard/prod: `escalate`
- fsi/sovereign: `terminate`

ENT-004.

### 31.5 SUSPENDED State Billing (Q29)
`billing_state` is a first-class field on all entities: `billable | non_billable | reduced_rate`. Policy injects `billing_state` and `billing_metadata` (rate_multiplier, billable_components) during state transitions. Cost Analysis component consumes the field — DCM carries the billing signal, policy decides the billing model. ENT-005.

### 31.6 Dependency Graph Versioning (Q30)
Dependency graphs versioned as part of their parent catalog item — not independently. New required dependency or removed dependency = **major (breaking) version bump**. New optional dependency = minor bump. Constraint change = revision bump. Dependency graph version captured in assembly provenance. ENT-006.

### 31.7 Dependency Graph Storage (Q31)
Not a separate entity. Three levels:
- Declared graph: embedded in Resource Type Specification (GitOps)
- Resolved graph: embedded in `placement.yaml` in Requested State
- Realized graph: Realized State events per dependency

ENT-007.

### 31.8 Dependency Graph Depth (Q33)
Profile-governed maximum: minimal=20, dev=15, standard/prod=10, fsi/sovereign=7. Requests exceeding max depth rejected with clear error. Circular dependency detection always enforced regardless of depth configuration. ENT-008.

### 31.9 Meta Provider Composition Visibility (Q34)
Meta Providers declare `composition_visibility`:
- `opaque` — consumer sees only top-level service; sub-resources not in DCM; drift on realized payload only
- `transparent` — all sub-resources registered as DCM entities; full drift detection
- `selective` — provider declares which sub-resources are DCM-visible

ENT-009.

### 31.10 System Policies
ENT-001 through ENT-009 — see docs 06 and 07.

---

## SECTION 32 — INFORMATION PROVIDER CONFIDENCE SCORING AND AUTHORITY

### 32.1 Confidence Scoring — 0 to 100
Every Information Provider field value carries a confidence score (0-100). DCM computes scores — providers do not self-declare. Score bands for policy use: very_high (81-100), high (61-80), medium (41-60), low (21-40), very_low (0-20).

**Formula:**
```
confidence_score = min(100, base_score × freshness_multiplier × corroboration_multiplier × authority_multiplier)
```

| Factor | Values |
|--------|--------|
| Base score | primary_authoritative=90, secondary=70, discovered=60, advisory=50, self_reported=40, inferred=30 |
| Freshness | <1h=1.00, <1d=0.95, <7d=0.85, <30d=0.70, >30d=0.50 |
| Corroboration | 1 source=1.00, 2 agree=1.10, 3+ agree=1.15, disagree=0.60 |
| Authority | primary=1.00, secondary=0.85, advisory=0.70 |

### 32.2 Authority as Layer Data
Authority scope and priority for Information Providers are declared in **platform or system domain layers** — not just policies. This is static organizational knowledge ("our CMDB is authoritative for business unit data"). Layer-defined authority establishes the default; policies act on confidence scores at runtime.

### 32.3 Ingestion-Time Conflict Detection
Conflict detection at ingestion time (7-step flow): schema validation → authority scope check → confidence score computation → conflict detection → resolution policy → entity record update → INGEST audit record.

**Resolution strategies:** `higher_authority_wins` | `higher_confidence_wins` | `higher_priority_wins` | `escalate` | `merge` (array fields only)

Authority scope conflicts detected at **registration time** — two providers claiming primary authority for the same field cannot both go active without explicit resolution.

### 32.4 Write-Back (Q63)
Optional declared capability. Policy triggers write-back — never automatic. Produces ENRICH audit records. Credentials via Credential Provider. (INF-002)

### 32.5 Extended Schema Versioning (Q64)
Semver semantics: field removal/type change = major (breaking); new optional field = minor; constraint change = revision. Migration plan required for major bumps. (INF-003)

### 32.6 Well-Known Provider Registry (Q65)
Three-tier registry (Core/Community/Organization) — same governance model as Resource Type Registry. Separate registries, shared infrastructure. (INF-004)

### 32.7 Air-Gapped Verification (Q66)
Three modes: pre-verified signed bundle, internal mTLS (for internal providers), periodic online re-verification with cached tokens. Profile governs cache expiry behavior. (INF-005)

### 32.8 System Policies
INF-001 through INF-008 — see docs 10 and 21.

---

## SECTION 33 — DCM FEDERATION AND CROSS-INSTANCE COORDINATION

### 33.1 Three Relationship Types
- **Peer DCM** — same organizational level; share resources/information
- **Parent-Child DCM** — hierarchical; parent has governance overlay; does not own child resources
- **Hub DCM** — specialized parent as resource allocation clearinghouse

All use the Universal Group Model: federation group (peers) or tenant_boundary nesting (parent-child).

### 33.2 Provider Federation Eligibility
Every provider registration declares `federation_eligibility`:
- `mode: none` — cannot participate in any federation (sovereign/classified providers)
- `mode: selective` — only with explicitly declared partners
- `mode: open` — any trusted DCM peer (sovereignty checks always apply)

**Layer-defined defaults** in `platform` domain layer. Individual registrations may be **more restrictive** — never more permissive without GateKeeper approval.

**Federation scope declares:** permitted resource types + operations, data sharing permissions, max concurrent allocations. Remote DCMs CANNOT decommission local resources through a tunnel.

**Storage providers default to `mode: none`** — data sovereignty prohibits storage federation unless explicitly authorized.

### 33.3 The DCM Provider — Ninth Provider Type
Wraps another DCM instance's API. Always mTLS (non-configurable). Sovereignty checks mandatory before tunnel establishment. Local DCM policies govern ALL resources from any tunnel.

**Non-negotiable primary concerns on all tunnels:**
- Sovereignty: verified before establishment; data classification checked per egress
- Authentication: always mTLS — no API key or bearer token
- Authorization: local policies govern; remote policies cannot override
- Audit: records in BOTH DCM instances; shared correlation_id
- Observability: cross-DCM allocation visible in both instances

### 33.4 Cross-DCM Confidence Scoring
```
cross_dcm_confidence = source_resource_confidence × (tunnel_trust_score / 100)
```
Federation trust score (0-100): factors include identity verification, sovereignty compatibility, certifications currency, audit trail integrity, uptime, compliance.

### 33.5 DCM Export/Import
Signed export package: tenants, layers, policies, provider registrations (not credentials), entity intent/requested states, groups, audit records with hash chain. Never export credentials.

Import trust score (0-100): source verification + sovereignty compatibility + data completeness + schema compatibility + audit trail integrity. Low score → reject or escalate.

### 33.6 System Policies
DCM-001 through DCM-008 — see doc 22.

---

## SECTION 34 — OPERATIONAL AND PERFORMANCE GAPS

### 34.1 Field-Level Provenance Models (Q7, Q8)

**Three configurable models — organization chooses; profile provides default:**

**Model A — Full Inline**
All provenance stored on entity record. Simplest queries, highest storage cost, no tooling required.
- ✅ Auditors read one record — regulatory clarity
- ✅ No dependency on layer chain store
- ❌ Very high storage volume at scale
- ❌ Write amplification

**Model B — Deduplicated (Content-Addressed) ← RECOMMENDED**
Layer chain is the deduplication key. Classical content-addressed dedup (like Git objects, Docker layers). Only delta fields store unique provenance. 95-99% storage reduction for standardized deployments. Lossless because layer chains are immutable.
- ✅ Dramatic storage reduction
- ✅ Full audit reconstruction always possible
- ✅ Write performance highest (layer-matching fields free)
- ❌ Chain traversal tooling required for queries
- ❌ Layer chain must be retained while any entity references it

**Model C — Tiered Archive**
Hot (full detail) → warm (change events) → cold (hash anchors). Degrades gracefully.
- ✅ Balances cost and access speed
- ✅ Compliant for long retention
- ❌ Cross-tier queries for long time ranges
- ❌ Cold tier requires full records from warm/hot for reconstruction

**Model B+C — Combined**
Maximum efficiency: content-addressed dedup + tiered archival of chains and deltas.

**Profile defaults:**

| Profile | Provenance Group | Rationale |
|---------|----------------|-----------|
| minimal, dev | `system/group/provenance-full-inline` | Simplicity; scale not a concern |
| standard, prod | `system/group/provenance-deduplicated` | Scale matters; tooling justified |
| fsi, sovereign | `system/group/provenance-full-inline` | Regulatory clarity; self-contained |

Organizations override by swapping the active provenance Policy Group.

**Audit completeness guarantee (OPS-002):** Regardless of model, full provenance is always reconstructable from entity record + layer chain store + Audit Store combined.

### 34.2 Background Conflict Validation (Q85)
Event-triggered (primary) on layer ingestion/update — async, non-blocking. Scheduled weekly sweep as safety net. Both triggers produce same conflict record format and audit trail. (OPS-003)

### 34.3 Policy Minimum Review Periods (Q86)
Change-type minimum periods: GateKeeper=14d, Validation=7d, Transformation=3d. Profile multipliers: minimal=0×, dev=0.5×, standard=1×, prod=1.5×, fsi/sovereign=2×. DCM enforces — not bypassable except emergency activation with dual-approval audit. (OPS-004)

### 34.4 Shadow Evaluation Store (Q87)
Dedicated **Validation Store** (not Audit Store). Queryable and modifiable. Links to Audit Store EVALUATE events via audit_record_uuid. Default retention P90D after policy promotion/retirement. (OPS-005)

### 34.5 Artifact Status Extensions (Q88)
Five standard statuses (developing/proposed/active/deprecated/retired) are invariant — no custom additions. Organizations use status_metadata for workflow state (purely informational, no system behavior). Policy gates status transitions based on status_metadata field values. (OPS-006)

### 34.6 System Policies
OPS-001 through OPS-006 — see docs 03 and 06.

---

## SECTION 35 — PROFILE COMPOSITION — POSTURE AND COMPLIANCE DOMAINS

### 35.1 The Two-Dimensional Profile Model

**Profiles compose two orthogonal dimensions:**

```
Complete Profile = Deployment Posture Group + Compliance Domain Group(s)
```

**Dimension 1 — Deployment Posture** (vertical axis): How DCM infrastructure behaves — redundancy, enforcement strictness, audit retention, tenancy model.

| Posture Group | Key Behaviors |
|--------------|--------------|
| `system/group/posture-minimal` | Advisory; single instance; no redundancy |
| `system/group/posture-dev` | Warn-not-block; basic logging |
| `system/group/posture-standard` | Full enforcement; 3-replica; explicit cross-tenant |
| `system/group/posture-prod` | Full enforcement + SLA; geo-replicated |
| `system/group/posture-hardened` | 5-replica; 7-year audit; dual approval |
| `system/group/posture-sovereign` | Air-gap; deny_all; 10-year audit; signed bundles |

**Dimension 2 — Compliance Domain** (horizontal): Which regulatory frameworks govern data and resources.

| Compliance Group | Domain |
|----------------|--------|
| `system/group/compliance-fsi` | Financial Services — Basel III, SOX, Dodd-Frank |
| `system/group/compliance-pci-dss` | Payment Card Industry — PCI-DSS v4 |
| `system/group/compliance-hipaa` | Healthcare — HIPAA/HITECH PHI |
| `system/group/compliance-fedramp-moderate` | US Federal Moderate — NIST 800-53 Moderate |
| `system/group/compliance-fedramp-high` | US Federal High — NIST 800-53 High |
| `system/group/compliance-dod-il2` through `il6` | DoD Impact Levels |
| `system/group/compliance-government` | Government/public sector |
| `system/group/compliance-gdpr` | EU GDPR data protection |
| `system/group/compliance-iso27001` | ISO 27001 information security |
| `system/group/compliance-nist-800-53` | NIST 800-53 security framework |
| `system/group/compliance-soc2` | SOC 2 service organization controls |
| `system/group/compliance-nerc-cip` | Critical infrastructure energy/utilities |
| `system/group/compliance-sovereign` | Sovereign/classified — air-gap, HSM, signed bundles |

### 35.2 Built-In Profile Compositions

The six core profiles are posture+compliance compositions:

```
minimal = posture-minimal
dev = posture-dev
standard = posture-standard
prod = posture-prod
fsi = posture-hardened + compliance-fsi + compliance-pci-dss + compliance-iso27001
sovereign = posture-sovereign + compliance-sovereign
```

**Extended built-in profiles:**

| Profile | Extends | Compliance Groups Added |
|---------|---------|------------------------|
| `system/profile/hipaa-prod` | prod | compliance-hipaa, compliance-iso27001 |
| `system/profile/hipaa-sovereign` | sovereign | compliance-hipaa |
| `system/profile/fedramp-moderate` | prod | compliance-fedramp-moderate, compliance-nist-800-53 |
| `system/profile/fedramp-high` | sovereign | compliance-fedramp-high, compliance-nist-800-53 |
| `system/profile/government` | prod | compliance-government, compliance-nist-800-53 |
| `system/profile/dod-il4` | sovereign | compliance-dod-il4, compliance-fedramp-high, compliance-nist-800-53 |
| `system/profile/dod-il5` | dod-il4 | compliance-dod-il5 |
| `system/profile/dod-il6` | dod-il5 | compliance-dod-il6, compliance-sovereign |

### 35.3 HIPAA Compliance Group Key Controls
- PHI field classification enforcement (phi: true tag required)
- PHI access control (phi_authorized role required)
- Audit retention: P6Y minimum
- AES-256 at rest, TLS 1.3 in transit for PHI
- Breach notification workflow via sovereignty_violation_record
- BAA tracking: providers declare baa_in_place in sovereignty_declaration
- Minimum Necessary standard on Mode 4 data_request_spec

### 35.4 Government/DoD Key Controls
- Data classification mandatory on all resources
- Cross-boundary controls for classification levels
- Audit retention: P10Y minimum
- DoD IL4+: CUI handling markers; foreign sub-processor exclusion
- DoD IL5+: sovereign posture within US boundary
- DoD IL6: classified + HSM required for key management

### 35.5 Tenant-Level Compliance Overlay
**One DCM deployment, multiple compliance postures per Tenant:**
```yaml
tenant_config:
  active_profile: system/profile/prod     # posture from platform
  compliance_groups:
    - system/group/compliance-hipaa        # this Tenant handles PHI
    - system/group/compliance-pci-dss      # this Tenant processes payments
```
Clinical Tenants (HIPAA) + Billing Tenants (HIPAA + PCI-DSS) + Admin Tenants (standard) — all on same DCM platform.

### 35.6 System Policies
- `PROF-001` — Profiles compose posture + compliance domain groups
- `PROF-002` — Compliance groups apply at platform or Tenant level; additive not replacing
- `PROF-003` — DCM ships built-in compliance groups for all major domains
- `PROF-004` — implementation_posture groups (provenance model etc.) are independent of compliance domain

---

## SECTION 36 — GROUPING AND RELATIONSHIP GAPS

### 36.1 Group Subclass Registry (Q35)
No separate registry needed. `group_class` is the closed system-behavior set. `group_subclass` is open and advisory — freely declared, never validated. DCM ships a community subclass catalog as a non-authoritative reference (same infrastructure as well-known provider registry). GRP-011.

### 36.2 Group Sovereignty Interaction (Q36)
Class-specific sovereignty rules:
- `tenant_boundary` — NEVER cross-sovereignty (structural, not configurable)
- `resource_grouping` — permitted by default; policy may restrict for classified resources
- `policy_collection` / `layer_grouping` — always permitted (governance artifacts, no data)
- `composite` — governed by most restrictive member type
- `federation` — permitted with DCM federation rules (DCM-003)

GRP-012.

### 36.3 Tenant Decommission Lifecycle (Q37)
Mandatory four-phase staged decommission:
1. **Pre-decommission validation** (blocking): resource state, cross-tenant relationships, compliance holds, rehydration leases, child groups resolved first
2. **Resource decommission**: cascade (default) / retain (ORPHANED state) / notify (PENDING_DECOMMISSION)
3. **Group membership cleanup**: remove from all memberships; empty federation groups → EMPTY state
4. **Audit record archival**: all records enter post-lifecycle retention — NEVER destroyed

Child tenant_boundary groups must be resolved BEFORE parent decommission (GRP-INV-003). GRP-013.

### 36.4 Time-Bounded Group Membership (Q38)
Already in Universal Group Model via `valid_from` / `valid_until` on every membership. Lifecycle Constraint Enforcer handles expiry. `on_expiry` actions: `remove` / `notify` (default) / `suspend_member`. `warn_before_expiry: P7D` standard. Expiry produces `MEMBER_REMOVE` audit record with `reason: membership_ttl_expired`. GRP-014.

### 36.5 Group Policy Inheritance (Q39)
Class-specific defaults, all profile-governed:
- `tenant_boundary`: `opt_out` (standard/prod) — parent cascades unless child excludes; `opt_in` (minimal/dev/fsi/sovereign)
- `federation`: always `opt_in` — peer consent required, not configurable
- `composite`: `opt_out` by default, configurable
- `resource_grouping` / `policy_collection`: not applicable

GRP-015.

### 36.6 Relationship Role Validation (Q58)
Advisory by default. Resource Type Spec may declare `permitted_relationship_roles` with `role_validation: advisory | enforced`. Advisory → assembly warning for unknown roles. Enforced → unknown roles rejected at request time. DCM ships community role catalog as non-authoritative reference. REL-020.

### 36.7 Relationship Graph Depth (Q60)
Profile-governed max: minimal=25, dev=20, standard/prod=15, fsi/sovereign=10. Circular detection always enforced. Depth = graph traversal distance between any two entities (NOT count of relationships on one entity). REL-021.

### 36.8 System Policies
GRP-011 through GRP-015 — see doc 15. REL-020, REL-021 — see doc 09.

---

## SECTION 37 — AUDIT AND OBSERVABILITY GAPS

### 37.1 Information Provider Trust Score Validation (Q15)

Dual-trigger model — same pattern as conflict validation:

**Event-triggered (primary):** push fails schema validation → degraded; push conflicts with primary authority → degraded; health check fails → degraded; sovereignty declaration change → re-evaluated; registration update → re-verification triggered.

**Scheduled (safety net):** daily health check; weekly full re-verification (identity, sovereignty, certifications, schema). fsi/sovereign: daily full re-verification.

**Trust score → source_trust mapping:**
- Score ≥ 80: `verified` → confidence multiplier 1.00
- Score 60-79: `degraded` → confidence multiplier 0.75
- Score < 60: `suspended` → no new pushes accepted; score = 0

(INF-009)

### 37.2 Confidence Scoring — The Hybrid Descriptor Model (Q15 extended)

**Three-tier model:**
- **Confidence Descriptor** (primary — stored): `authority_level` + `corroboration` + `source_trust` + `last_updated_at`
- **Derived Score** (0-100, computed on demand): mathematical composition for placement and conflict resolution
- **Derived Band** (very_high/high/medium/low/very_low, computed on demand): what humans and policies use

**Who sets each field:**
- `authority_level`: set at registration from authority declaration layer (static per field per provider)
- `corroboration`: computed at ingestion (confirmed/single_source/contested based on multi-provider comparison)
- `source_trust`: maintained by trust scoring system (event-triggered + scheduled)
- `last_updated_at`: set at each push event

**Score formula:** `min(100, base(authority_level) × freshness_mult × corroboration_mult × trust_mult)`

**Freshness is computed at query time** from `now - last_updated_at` — never stored (avoids staleness). Score and band computed at query time for the same reason.

**Audit reconstruction:** authority_level (from registration) + corroboration (from ingestion event) + source_trust (from trust audit) + last_updated_at (from push event) → score and band fully reconstructable from stored facts.

**Configurable derivation:** base scores, freshness thresholds, and band thresholds configurable via Policy Group — stored as versioned policy artifacts.

### 37.3 Audit vs Observability — Definitively Separate (Q16)

| | Audit | Observability |
|--|-------|--------------|
| Purpose | WHAT HAPPENED + WHO authorized | SYSTEM HEALTH + PERFORMANCE |
| Consumers | Auditors, compliance, legal | SREs, operators, dashboards |
| Write rate | Low (per action) | Very high (per second) |
| Retention | P7Y+ | Days to months |
| Mutability | Never — append-only | Downsampling acceptable |
| Accuracy | 100% required | Statistical sampling OK |
| Failure | Missing = compliance violation | Missing = operational inconvenience |

They cannot be combined without violating one contract or the other. Observability may reference audit record UUIDs for correlation. AUD-013.

### 37.4 Curated Observability Event Stream (Q17)

DCM publishes a curated event stream via Message Bus — NOT raw metrics. Policy governs what is published, subscriber roles, and redaction. Published by default: component.health_changed, resource.state_transition, capacity.threshold_crossed, drift.detected, security.gatekeeper_triggered, provider.confidence_changed. NOT published by default: metrics.raw (explicit policy opt-in required).

Observability events on Message Bus do NOT replace audit records. OBS-001.

### 37.5 System Policies
- `INF-009` — dual-trigger trust score; degraded/suspended states; policy governs thresholds
- `AUD-013` — audit and observability definitively separate; different contracts/consumers
- `OBS-001` — curated observability event stream via Message Bus; policy-filtered; raw metrics opt-in only

---

## SECTION 38 — OVERRIDE CONTROL AND ENHANCEMENT GAPS

### 38.1 The Complete Field Lifecycle Contract

Three questions together define the full field governance model across a resource's lifecycle:

```
ASSEMBLY TIME (Q50 — override_preference):
  Which layers can set this field?
  immutable → only this layer and higher-domain layers
  constrained → any layer within declared bounds
  allow → any layer

CATALOG PRESENTATION (Q52 — constraint_visibility):
  What does the consumer see about this field's constraints?
  full → constraint + bounds + reason + suggestions
  summary → bounds only
  hidden → enforced silently

POST-REALIZATION (Q56 — editability):
  Can the consumer change this field after provisioning?
  editable: false → requires reprovisioning
  editable: true → targeted delta update permitted (within edit_constraints)
```

### 38.2 Override Preference Enforcement (Q50)

`override: allow | constrained | immutable` on layer fields is enforced by the Request Payload Processor during assembly **Step 3 (Layer Merge)**. No separate GateKeeper policy needed.

**Authority rule:** `immutable` prevents overrides from lower-authority domains only. A platform domain `immutable` field blocks tenant/service/provider/request — but system domain can still override. Higher authority always wins.

**GateKeeper escalation:** A GateKeeper policy may additionally lock an `allow` or `constrained` field at runtime — for compliance mandates the layer author didn't anticipate.

**Enforcement:** If a lower-priority layer or consumer sets an `immutable` field → assembly halts with clear error identifying the conflicting layer and locking layer.

LAY-005.

### 38.3 Constraint Schema Visibility (Q52)

Constrained fields expose their constraint schema to consumers in the Service Catalog UI and Consumer API at a policy-governed disclosure level.

**Disclosure levels:** `full` (constraint + bounds + reason + suggestions), `summary` (bounds only), `hidden` (silently enforced)

**Profile defaults:** minimal/dev/standard → full; prod/fsi → summary; sovereign → hidden

**API:** `GET /api/v1/catalog/items/{id}/schema` returns field schemas at the declared visibility level for the authenticated consumer's Tenant profile.

Policy may override per field or resource type.

LAY-006.

### 38.4 Post-Realization Field Editability (Q56)

**Editability is orthogonal to override_preference:**
- `override` governs assembly time (which layers can set the field during request construction)
- `editable` governs post-realization (can the consumer update the field on a running resource)

**Declared on Resource Type Specification:**
```yaml
fields:
  cpu_count:    editable: true; edit_constraints: {range: 1-32}; requires_restart: true
  hostname:     editable: false; non_editable_reason: "Requires reprovisioning"
  dns_servers:  editable: true; requires_restart: false
  region:       editable: false; non_editable_reason: "Region immutable post-realization"
```

**Update request flow:** validate editable → validate edit_constraints → evaluate edit_policy → produce delta Requested State → dispatch delta to provider → update Realized State

**Critical:** Updates are targeted deltas — **layers do NOT re-run**. Only changed fields validated and dispatched. Layer chain NOT re-assembled for updates.

Editable fields and edit_constraints visible in Service Catalog at same constraint_visibility level as constraint schemas.

ENT-010.

### 38.5 System Policies
- `LAY-005` — override: allow/constrained/immutable enforced at Step 3; immutable = lower-authority only; GateKeeper may additionally lock
- `LAY-006` — constraint schema visible at full/summary/hidden level; profile-governed; API endpoint
- `ENT-010` — editability first-class on Resource Type Spec; independent of override_preference; updates = targeted deltas; layers do not re-run

---

## SECTION 39 — PERSONAS

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

## SECTION 40 — TERMINOLOGY GLOSSARY

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
| **Commit Log** | Stage 1 audit store — minimal record, Raft consensus quorum write, sub-millisecond; Audit Forward Service reads from it to produce full audit records |
| **Audit Forward Service** | DCM component that enriches Commit Log entries into full audit_record structures and delivers them to the Audit Store asynchronously with retry |
| **Self-Hosting** | DCM's own deployment is a DCM resource; DCM manages itself through the same model used for customer infrastructure |
| **dcm_deployment** | The DCM resource declaring DCM's own deployment — profile, replica counts, store implementations, redundancy configuration |
| **Bootstrap manifest** | The minimal configuration outside DCM's management scope used to bootstrap DCM before it can manage itself |
| **Redundancy by Default** | DCM architectural principle: every component and store has a redundancy model; `minimal` profile sets replicas: 1; all others set replicas >= 3 |
| **Quorum Write** | Write confirmed durable only when a majority of replicas acknowledge it; used by Commit Log and all durable stores in standard+ profiles |
| **Raft** | Consensus protocol used by Commit Log (etcd) for quorum writes; guarantees durability even if minority of replicas fail |
| **DCMGroup** | Universal group entity — all grouping constructs in DCM expressed as DCMGroup with group_class |
| **group_class** | Determines system behavior of a DCMGroup — closed built-in set: tenant_boundary, resource_grouping, policy_collection, policy_profile, layer_grouping, composite, federation |
| **override: allow/constrained/immutable** | Layer field metadata declaring override intent; enforced by Request Payload Processor at Step 3; immutable prevents lower-authority overrides only; GateKeeper may additionally lock |
| **constraint_visibility** | Policy-governed disclosure level for constrained fields: full (constraint+bounds+reason+suggestions), summary (bounds only), hidden (silently enforced) |
| **editable** | Resource Type Spec field declaration: can this field be modified post-realization via a targeted delta update (true) or only via reprovisioning (false) |
| **edit_constraints** | Bounds declared on editable fields: range, list, enum; validated at update time; same constraint types as assembly-time constraints |
| **requires_restart** | Editable field flag indicating whether a provider restart action is needed to apply the update |
| **targeted delta** | Update mechanism for editable fields: applies only changed fields to Realized State; does NOT re-run the layer assembly chain |
| **non_editable_reason** | Human-readable explanation on non-editable fields explaining why reprovisioning is required to change them |
| **confidence_descriptor** | Primary confidence data model: authority_level (from registration), corroboration (from ingestion), source_trust (from trust system), last_updated_at (from push) — stored fields |
| **freshness** | Derived confidence field computed at query time from (now - last_updated_at) vs thresholds: high (<1h), medium (<1d), low (<7d), stale (>7d) |
| **corroboration** | Confidence descriptor field: confirmed (2+ sources agree), single_source, contested (sources disagree) |
| **source_trust** | Confidence descriptor field maintained by trust scoring system: verified (score ≥80), degraded (60-79), suspended (<60) |
| **OBS-001** | Policy: DCM publishes curated Observability Event Stream via Message Bus; policy-filtered; raw metrics opt-in; does not replace audit records |
| **AUD-013** | Policy: Audit and Observability are definitively separate components — opposite trade-offs; cannot be combined |
| **group_subclass** | Advisory label on a DCMGroup — no system behavior; used for organization-specific semantics (e.g., cost_center, business_unit) |
| **composite group** | DCMGroup with group_class: composite — permits cross-type membership (resources, policies, layers, groups) |
| **federation group** | DCMGroup with group_class: federation — peer association of tenant_boundary groups; enables shared policies and consolidated reporting |
| **nested Tenant** | A tenant_boundary group with parent_group_uuid pointing to another tenant_boundary group |
| **federated Tenant** | A tenant_boundary group that is a member of a federation group |
| **former_group_membership** | Permanent provenance record retained by a member after group destruction or membership expiry |
| **group_destruction_record** | Permanent Audit Store record of a destroyed group including its full member list at destruction time |
| **member_type_filter** | Policy targeting declaration narrowing scope within a composite group to specific member types |
| **most_restrictive_wins** | Governance inheritance principle for nested Tenants — most restrictive policy at any level in the hierarchy applies |
| **Nested Tenant** | tenant_boundary group with parent_group_uuid — child maintains isolation; parent has governance overlay and cost rollup |
| **GRP-INV** | Universal group structural invariants — non-overridable regardless of enforcement_model or Profile |
| **Universal Audit Record** | Uniform audit record produced by every DCM component for every change — date/time, who, what, action |
| **Composite Actor Chain** | The who in an audit record — immediate actor + authorized_by human chain + originating request/policy |
| **Action Vocabulary** | Closed set of audit record action values — free text rejected at write time (AUD-007) |
| **Reference-Based Retention** | Audit records retained while any referenced entity is live — not fixed time schedule |
| **Write-Ahead Log (WAL)** | Local audit delivery buffer — change + audit record written atomically; Audit Store delivery async with retry; WAL cleared after Audit Store confirms |
| **Hash Chain** | Per-entity tamper-evident chain: record_hash + previous_record_hash; chain breaks detectable and trigger security alerts |
| **Mode 4 Policy Provider** | Black box query-enrichment policy provider — DCM sends query, external system evaluates and/or enriches, returns structured result; logic is opaque to DCM |
| **Black Box Query-Enrichment** | Mode 4 operation where an external system simultaneously evaluates request data and injects enrichment fields into the payload |
| **audit_token** | Provider-issued reference in Mode 4 responses enabling cross-system audit correlation between DCM audit trail and provider's internal logs |
| **data_request_spec** | Mode 4 registration declaration of which fields the provider is authorized to receive, with classification ceiling per field |
| **Policy Naturalization** | Translation of external policy schemas (OSCAL, XCCDF, CIS JSON) into DCM policy format — Mode 3 Policy Provider mechanism |
| **Policy Group** | Cohesive versioned collection of policies addressing a single identifiable concern — the unit of policy reuse |
| **Policy Profile** | Complete DCM configuration for a specific use case — composed of Policy Groups |
| **Policy Provider** | Fifth DCM provider type — external authoritative source supplying policies into DCM |
| **concern_type** | Policy Group classification: technology, compliance, sovereignty, business, operational, security |
| **minimal profile** | Least restrictive built-in profile — advisory enforcement, auto-tenant, home lab / evaluation |
| **sovereign profile** | Most restrictive built-in profile — hard tenancy, deny_all cross-tenant, maximum sovereignty |
| **Lifecycle Constraint Enforcer** | DCM control plane component monitoring realized entities against time constraints |
| **cross_tenant_authorization** | Explicit authorization record for cross-tenant relationship — specifies who, what, when, where |
| **explicit_only** | Default cross-tenant hard tenancy setting — ALL cross-tenant requires explicit authorization |
| **PENDING_REVIEW** | Entity state during paused rehydration tenancy conflict — awaiting resolution |
| **Policy Gap Record** | Audit record for fields absent from reserve query with no applicable policy — records implicit_approval |
| **Shared Resource** | An entity within a single Tenant with active relationships from multiple parent entities; governed by sharing_model and reference counting |
| **sharing_model** | Entity-level declaration of shareability, active_relationship_count, and on_last_relationship_released behavior |
| **active_relationship_count** | DCM-maintained count of active constituent/operational relationships on a shared resource |
| **save_overrides_destroy** | The lifecycle action hierarchy rule: retain > notify > suspend > detach > cascade > destroy; most conservative action always wins |
| **lifecycle_conflict_record** | Audit record created when multiple lifecycle action recommendations differ; carries severity, resolved action, and resolution rule |
| **deferred_destruction_record** | Audit record created when a destructive lifecycle action is deferred because active_relationship_count is above minimum |
| **Ingestion Model** | Unified DCM mechanism for bringing entities outside lifecycle control into DCM governance — covers V1 migration, brownfield discovery, and manual import |
| **Ingestion Record** | Provenance record on every ingested entity — source, confidence, assignment method, enrichment history, promotion timestamp |
| **`__transitional__` Tenant** | System-managed holding Tenant for unassigned ingested entities — cannot be deleted, renamed, or used for new provisioning |
| **Ingestion Confidence** | `high | medium | low` — quality signal for auto-assignment; reflects how reliable the Tenant assignment is |
| **Brownfield** | Existing infrastructure not yet under DCM lifecycle management — brought in via brownfield ingestion |
| **V1 Migration** | Migration of pre-Tenant DCM V1 entities to V2 using the ingestion model |
| **INGESTED state** | First ingestion lifecycle state — entity in DCM, minimal metadata, Tenant may be __transitional__ |
| **ENRICHING state** | Second ingestion lifecycle state — Tenant assigned, metadata and relationships being completed |
| **PROMOTED state** | Final ingestion lifecycle state — all requirements met, DCM assumes full lifecycle ownership |
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

## SECTION 41 — OPEN QUESTIONS

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
| 32 | How are cross-tenant dependencies handled? | Dependencies | ✅ Resolved — governed by REL-010/011/012; DEP-001/002/003 for dependency graph specifics; explicit_only default; cross_tenant_authorization required |
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
| 54 | Enhancement gaps: selected_provider as policy output vs. placement component concern | Enhancements | ✅ Resolved — Placement Engine is a distinct named component; nine-step assembly; reserve query; placement loop with policy phases; policy_gap_record for implicit approval; post-placement policy pass |
| 55 | Enhancement gaps: migration path from V1 (no Tenant) to Tenant-mandatory | Enhancements | ✅ Resolved — unified ingestion model; __transitional__ Tenant; three-step ingest/enrich/promote; ING-001 through ING-007; also covers brownfield ingestion |
| 56 | Enhancement gaps: should editable field concept from Catalog Item Schema be incorporated into Resource Type Spec? | Enhancements |
| 57 | How are relationship conflicts resolved — two policies declare different lifecycle policies for the same relationship? | Entity Relationships | ✅ Resolved — standard Policy Engine authority hierarchy; lifecycle policy fields are just fields; no special case; REL-008 and REL-009 |
| 58 | Should relationship roles be validated against the role registry at request time, or is validation advisory? | Entity Relationships |
| 59 | How does the relationship graph interact with multi-tenant scenarios — can a relationship cross Tenant boundaries? | Entity Relationships | ✅ Resolved — nature governs; constituent never; operational with dual auth; informational unless deny_all; REL-010/011/012; allocated resource model |
| 60 | Should there be a maximum relationship graph depth? | Entity Relationships |
| 61 | How are shared entities represented — an entity required by multiple parents? | Entity Relationships | ✅ Resolved — sharing_model with active_relationship_count; save_overrides_destroy hierarchy; lifecycle_conflict_record; REL-015 through REL-019 |
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

## SECTION 42 — DOCUMENTATION STRUCTURE

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

## SECTION 43 — WORKING INSTRUCTIONS FOR AI MODELS

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
65. **Universal Group Model supersedes separate grouping constructs** — all Tenants, Resource Groups, Policy Groups, and Profiles are DCMGroup entities with group_class; use the universal model for new implementations; existing UUIDs and APIs are preserved
66. **group_class drives system behavior, group_subclass is advisory** — never design system behavior around group_subclass; only the built-in group_class values produce system-enforced behavior
67. **Composite groups default to targeting all member types** — always declare member_type_filter when writing policies that target a composite group unless genuinely intending to govern all member types simultaneously
68. **Nested tenant governance: most restrictive wins** — a child policy that is more restrictive than a parent policy wins; parent policies cascade where the child has no policy; this is the same principle as save_overrides_destroy and field override control
69. **former_group_membership records are permanent** — group destruction does not erase membership history; queries against membership history are valid at any time via provenance store; use this for compliance and audit queries about past associations
115. **Three independent field governance mechanisms cover the full lifecycle** — override_preference (assembly time: which layers can set), constraint_visibility (catalog: what consumers see), editability (post-realization: what consumers can change); all three are orthogonal and compose
116. **Updates are targeted deltas — layers never re-run on updates** — PATCH requests validate editable fields and edit_constraints then dispatch a delta; the layer assembly chain is not re-invoked; this preserves original assembly integrity while allowing operational changes
117. **immutable override only blocks lower-authority domains** — a platform domain immutable field blocks tenant/service/provider/request; it does not block system domain; higher authority always wins; GateKeeper can additionally lock allow/constrained fields for compliance mandates
111. **Confidence descriptor is primary — score and band are derived** — authority_level/corroboration/source_trust/last_updated_at are stored facts; freshness/score/band computed at query time from stored facts; never stored as primary (avoids staleness); all reconstructable from audit records
112. **source_trust drives the confidence trust_multiplier** — verified=1.00, degraded=0.75, suspended=0.00; maintained by dual-trigger trust scoring (event-triggered + weekly scheduled); push failures and schema errors degrade trust automatically
113. **Audit and Observability answer different questions** — Audit: what happened and who authorized it; Observability: is the system healthy; different consumers, opposite storage trade-offs; Observability may reference audit record UUIDs but lives in a separate store
114. **Curated Observability Event Stream is policy-filtered** — not raw metrics; policy governs what is published and subscriber role requirements; raw metrics.raw requires explicit policy opt-in; published events do not replace audit records
108. **Tenant decommission is four-phase and never silent** — pre-decommission validation blocks the operation until all resources, cross-tenant relationships, compliance holds, and child groups are resolved; audit records enter post-lifecycle retention and are never destroyed
109. **Group policy inheritance is class-specific** — tenant_boundary uses opt_out for standard/prod (parent cascades) and opt_in for fsi/sovereign; federation always opt_in; resource_grouping and policy_collection are not applicable
110. **Relationship graph depth differs from dependency depth** — depth is graph traversal distance between any two entities, not relationship count; circular detection always enforced; profile-governed max 15 (standard/prod) or 10 (fsi/sovereign)
105. **Profiles have two independent dimensions** — posture (how DCM infrastructure behaves) and compliance domain (which regulatory frameworks apply); compose them freely; a hospital uses hipaa-prod = posture-prod + compliance-hipaa; a defense contractor uses dod-il4 = posture-sovereign + compliance-dod-il4 + compliance-fedramp-high + compliance-nist-800-53
106. **Compliance domain groups apply at Tenant level** — one DCM deployment can host clinical Tenants (HIPAA), billing Tenants (HIPAA + PCI-DSS), and admin Tenants (standard) simultaneously; compliance_groups in tenant_config are additive to the platform profile
107. **HIPAA group enforces PHI minimum necessary** — Mode 4 data_request_spec is limited to minimum PHI fields; providers handling PHI must declare baa_in_place in sovereignty_declaration; audit retention is P6Y regardless of profile default; breach notification triggers via sovereignty_violation_record
101. **Provenance model is configurable — Model B is recommended for standard+** — organizations choose full_inline (simple, high storage), deduplicated/Model B (content-addressed dedup, lossless, 95-99% storage reduction), tiered (hot/warm/cold), or combined; swap the active provenance Policy Group to change
102. **Shadow evaluation records go to Validation Store — not Audit Store** — Validation Store is queryable and modifiable (records marked reviewed); links to Audit Store via audit_record_uuid; P90D retention after policy promotion/retirement
103. **Policy minimum review periods are DCM-enforced** — not guidelines; GateKeeper=14d, Validation=7d, Transformation=3d × profile multiplier; emergency bypass requires dual-approval audit
104. **Artifact status extensions are not permitted** — the five statuses are invariant; use status_metadata for workflow state (no system behavior); policy gates transitions based on status_metadata values
97. **Confidence scoring is computed by DCM — never self-declared** — the formula (base_score × freshness × corroboration × authority) is standardized and auditable; policies work on bands (very_high/high/medium/low/very_low) not raw values
98. **Information Provider authority is layer-defined** — static organizational knowledge ("our CMDB is authoritative for business unit") belongs in a platform domain layer; conflict detection happens at ingestion time; policy governs automated resolution
99. **DCM Provider is the ninth provider type** — always mTLS (non-configurable); sovereignty checks mandatory; local policies govern ALL federated resources; audit records in both DCM instances with shared correlation_id
100. **Provider federation eligibility is layer-defined with policy enforcement** — platform layer sets defaults per provider type; individual registrations may be more restrictive; storage providers default to mode: none; remote DCMs cannot decommission local resources through tunnels
93. **Process Resource max_execution_time is mandatory** — it is not optional metadata; enforced by the Lifecycle Constraint Enforcer; profile governs the default on_max_exceeded action (notify/escalate/terminate)
94. **Dependency graphs are embedded, not separate entities** — declared graph in Resource Type Specification; resolved graph in placement.yaml (Requested State); realized graph in Realized State events; no separate dependency graph artifact needed
95. **Billing state is first-class — not metadata** — DCM carries the billing_state field; policy determines the billing model per resource type and state; Cost Analysis consumes it; organizations decide what is billable
96. **Meta Provider composition_visibility governs DCM's view** — opaque means DCM only sees what the provider reports; transparent means all sub-resources are full DCM entities with drift detection; selective is the middle ground
89. **Provider sovereignty is a contractual obligation** — every provider registration requires sovereignty_declaration; changes must be notified within declared SLA; DCM treats sovereignty changes as drift and re-evaluates placement; auto-migration available via Provider-Portable Rehydration
90. **Git PR ingress actors resolve through the same Auth Provider as all other users** — DCM trusts the Git server's authentication assertion; git config user.email is ignored (spoofing vector); the resolved actor has IDENTICAL roles/groups/tenant scope to web UI login for the same user; unresolvable identities are always rejected with an actionable PR comment
91. **Storage Provider sub-types are distinct** — Search Index (non-authoritative, rebuildable, consistency lag declared) and Audit Store (append-only, hash chain, reference-based retention, compliance queries) are separate sub-types; never treat them as interchangeable
92. **GitOps stores use handle-based directory structure** — deterministic path from artifact identity; main is authoritative; monorepo acceptable for minimal/dev; separate repos for standard+
85. **Layers are data, policies are logic — never conflate them** — if a policy repeatedly injects the same static value, that value belongs in a layer; if a layer contains conditional evaluation logic, that logic belongs in a policy; the flow is strictly unidirectional (layers Steps 1-4, policies Steps 5-9)
86. **Layer domains mirror policy domains** — system > platform > tenant > service > provider > request; same authority model, same override precedence; lower cannot override higher
87. **Layer Groups use DCMGroup group_class: layer_grouping** — same universal group model as policy_collection; enables discovery, composition, and governance of related layers
88. **activation_condition enables conditional layer inclusion** — evaluated in Step 2; can reference request fields, tenant attributes, resource type, resolved core layer fields, and ingress fields; condition false = layer excluded = recorded in provenance
81. **Registry governance is PR-based and policy-governed** — proposals are Pull Requests with automated validation gates; shadow validation in proposed status is mandatory before active; the Registry Provider is fully policy-governed with profile-appropriate policy groups
82. **Deprecation defaults are policies — not hard-coded values** — REG-DP-001 through REG-DP-007 are overridable via standard priority; FSI/sovereign profiles lock sunset periods as immutable; REG-DP-005 (retired rejects new requests) is structural and never overridable
83. **Version constraints are strictly enforced — no silent upgrades** — DCM never auto-upgrades across major versions; version_policy governs flexibility within that constraint; profile sets the default policy
84. **Cost analysis ranks above least-loaded in tie-breaking** — cost is a business decision; but only if Cost Analysis has current data and cost is determinable; skip silently if not; consistent hash is always the final deterministic tiebreaker
75. **Eight provider types — not five** — Message Bus Provider (6), Credential Provider (7), and Auth Provider (8) complete the ecosystem; all follow the same base contract
76. **The ingress block is the policy surface for all access control** — every request carries surface, protocol, authenticated_via, actor.roles, actor.auth_provider_type, mfa_verified, and external_identity claims; GateKeeper policies act on all of these
77. **No anonymous access in any profile** — minimal profile uses static API key (30 seconds to set up); the authentication ladder is about setup effort, not whether auth exists; AUTH-008 is non-negotiable
78. **Credentials always via Credential Provider** — no plaintext credentials anywhere in DCM: not in Git, not in audit records, not in logs; always reference a Credential Provider secret_path
79. **Auth Providers are versioned artifacts** — role_mapping and tenant_mapping changes go through proposed → active validation; Auth Provider config changes are audited; multiple providers can be registered simultaneously with signal-based routing
80. **Webhook registrations are versioned artifacts** — Git-managed, lifecycle-governed, schema adapters for long-lived compatibility; inbound callers must be registered as webhook actors with explicit permissions
71. **Two-stage audit: Stage 1 is the durability guarantee** — the Commit Log quorum write confirms the change is audited; Stage 2 enrichment is asynchronous; Stage 1 timestamp is the authoritative audit timestamp (AUD-013)
72. **Redundancy is profile-governed — not per-component** — never configure replica counts individually; activate the appropriate Profile and it configures redundancy for the entire deployment
73. **DCM is self-hosting** — DCM's own deployment is a DCM resource; DCM manages itself through the same four-state model, policy engine, and audit trail used for customer workloads
74. **Everything is containerized** — no bare-metal DCM components; all components run as Kubernetes pods following the standard pod security model; state is always in external stores (stateless control plane)
65. **All DCM grouping uses DCMGroup with group_class** — there is no separate Tenant entity, Resource Group entity, or Policy Group entity; they are all group_class values; use the class-filtered API views for backward compatibility
66. **Composite groups apply to all member types by default** — always use member_type_filter when targeting a composite group with a policy that should apply only to specific member types
67. **Nested Tenants inherit governance from parent — not ownership** — a resource always belongs to its leaf tenant_boundary group; the parent has governance overlay and cost rollup only; GRP-INV-004 is non-overridable
68. **Every change produces an audit record — no exceptions** — the WAL guarantees delivery; WAL write failure aborts the change; no silent unaudited changes are possible
69. **Audit retention is reference-based — not time-based** — a 7-year retention policy means 7 years AFTER all referenced entities retire; a record created 20 years ago is retained unconditionally if any referenced entity is still operational
70. **The audit hash chain is tamper-evident** — any insertion, modification, or deletion of a historical record breaks the chain; verification is a first-class DCM operation; chain breaks trigger security alerts
63. **Mode 4 Policy Providers are query-response interfaces** — logic lives externally; DCM sends minimized data, receives decision and/or enrichment; data sovereignty check always runs before any query is dispatched; default failure behavior is gatekeep
64. **Mode 4 enrichment fields carry full provenance** — source_type: black_box_provider, source_uuid, and audit_token; override control applies; a GateKeeper can refuse enrichment on sensitive fields; enrichment providers require transformation trust level minimum
57. **Policy Profiles are the primary configuration mechanism** — most deployments activate a built-in profile and add organization-specific groups; do not configure individual policies from scratch when a profile covers the use case
58. **Policy Groups are the unit of reuse** — when designing policies for a concern, package them as a group; groups can be shared across profiles and inherited by other groups
59. **Policy Providers are the fifth provider type** — they follow the same base contract; trust level determines max policy authority; untrusted providers are advisory only; trusted requires dual approval elevation
60. **Cross-tenant default is explicit_only** — informational sharing is NOT open by default; every cross-tenant relationship of any nature requires a cross_tenant_authorization record; this supersedes the earlier operational_only default
61. **Lifecycle time constraints are first-class fields** — they follow standard precedence and override control; GateKeeper can lock them immutable; expiry enforcement is a DCM control plane function not a provider concern
62. **Rehydration cannot bypass tenancy or sovereignty** — policy_version: pinned only governs resource configuration policies; tenancy and sovereignty always use current policies; conflicts produce PENDING_REVIEW state
53. **Shared resources use reference counting** — DCM maintains active_relationship_count; destructive actions are deferred until the count reaches minimum_relationship_count per REL-015; informational relationships never count (REL-016)
54. **Save overrides destroy — always** — the lifecycle action hierarchy (retain > notify > suspend > detach > cascade > destroy) resolves all multi-parent lifecycle conflicts deterministically; retain always wins per REL-018; this is non-negotiable
55. **Lifecycle conflicts are recorded, not silently resolved** — lifecycle_conflict_record created whenever multiple different action recommendations exist; warning/critical severity triggers notifications; info severity is logged only
56. **shareability.allowed: false blocks multiple relationships at type level** — non-shareable resource types (e.g., boot disks) reject second constituent/operational relationships at request time per REL-017; check Resource Type Specification before designing multi-parent relationships
49. **Assembly is nine steps not seven** — steps 1-4 (layers), step 5 (pre-placement policies), step 6 (Placement Engine loop), step 7 (post-placement policies), step 8 (Requested State storage), step 9 (dispatch); always use the correct step number when discussing assembly
50. **Reserve query is atomic** — it simultaneously verifies constraints, returns metadata, and places a resource hold; it is the primary placement query inside the loop; non-hold queries (capacity, metadata, constraint_verification) are available outside the loop for informational purposes
51. **Missing metadata is a policy concern only** — DCM has no built-in opinion about metadata sufficiency; if no policy declares required_context for an absent field, the result is implicit_approval; implicit approvals are recorded explicitly in policy_gap_records
52. **Placement Engine is a named component** — it is a peer to the Policy Engine, not subordinate to it; it owns the placement loop, candidate scoring, reserve query dispatch, and hold management
45. **Ingestion model is the unified mechanism** — V1 migration and brownfield ingestion are the same three-step pattern: ingest → enrich → promote; use the same ingestion_record structure, same __transitional__ Tenant, same governance policies regardless of source
46. **`__transitional__` Tenant is a system artifact** — never design around it for normal operations; it exists only as a migration/ingestion holding area; entities there are governance liabilities to be resolved
47. **Ingested entities have capability restrictions** — INGESTED and ENRICHING state entities cannot be parents for allocated resource claims or hard dependencies for new requests; always check ingestion state before designing dependencies
48. **Promotion is the lifecycle gate** — an entity is not a full DCM citizen until it reaches PROMOTED state; before that it is in a holding state with restricted capabilities
41. **Lifecycle policy fields on relationships are just fields** — they carry the same override metadata and resolve under the same Policy Engine authority hierarchy as any other DCM field; no special conflict resolution mechanism
42. **Relationship type × nature matrix is explicit and enforced** — invalid combinations are rejected at request time per REL-013; the matrix is the authoritative source for valid relationship combinations
43. **Cross-tenant relationships are governed by nature** — constituent never crosses tenant boundaries; operational requires dual authorization; informational is permitted unless deny_all; hard_tenancy declaration on the Tenant entity controls the boundary
44. **Allocated resources are first-class entities** — a consuming Tenant gets its own UUID, lifecycle, and governance; the relationship is depends_on + operational + cross_tenant; the parent pre-defines available allocations; DCM tracks active allocations on the parent with notification endpoints — they carry the same override metadata and resolve under the same Policy Engine authority hierarchy as any other DCM field; there is no special conflict resolution mechanism for lifecycle policies; REL-008 and REL-009 are the only relationship-specific system policies that add constraints beyond the standard model

---

*This prompt script is a living document. Update it whenever architectural decisions are made or open questions are resolved.*
