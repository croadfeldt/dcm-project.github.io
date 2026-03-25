---
title: "Data Layers and Assembly"
type: docs
weight: 3
---

> **⚠️ Active Development Notice**
> 
> The DCM data model and architecture documentation are actively being developed. Concepts, structures, and specifications documented here represent work in progress and are subject to change as design decisions are finalized. Open questions are explicitly tracked and decisions are recorded as they are made.
> 
> Contributions, feedback, and discussion are welcome via [GitHub](https://github.com/dcm-project).


**Document Status:** 🔄 In Progress  
**Related Documents:** [Context and Purpose](00-context-and-purpose.md) | [Entity Types](01-entity-types.md) | [Four States](02-four-states.md) | [Resource Type Hierarchy](05-resource-type-hierarchy.md)

---

## 1. Purpose

Data Layers are the mechanism by which DCM assembles a complete, contextually correct request payload from a set of composable, reusable data definitions. Rather than requiring consumers to specify every field of every resource they request, layers allow standards, organizational context, service-specific configuration, and consumer intent to be declared independently and merged into a unified payload at request time.

Layers are the answer to the question: **how does a single consumer request become a complete, policy-validated, provider-ready payload?**

The layering model enables:
- **Reuse** — a base configuration defined once is inherited by thousands of resources
- **Standardization** — organizational standards are encoded in layers, not in every individual request
- **Separation of concerns** — infrastructure teams own core and service layers; consumers own request layers; policy owners own policy layers
- **Scale** — 36 layer definitions can govern 40,000 VMs without duplication
- **Auditability** — every field in the merged payload knows which layer set it and why

---

## 2. What is a Layer?

A Layer is a **declarative, immutable, versioned unit of data** that contributes some or all of its fields to a merged payload. Layers do not execute — they declare. The assembly process is what merges them.

Every layer:
- Has a **UUID** that uniquely identifies it
- Has a **version** following the universal Major.Minor.Revision scheme
- Is **immutable once published** — changes produce a new version
- Carries a **reference to its parent entity** (UUID and version)
- Has an **origination timestamp**
- Can be **deprecated** following the universal deprecation model
- Contributes **provenance metadata** for every field it sets — any field set by a layer records that layer's UUID as its source

Layers are stored in Git following GitOps practices. They are the configuration source of truth — not the assembled payload.

---

## 3. Layer Types

DCM defines six layer types. Each has a distinct purpose, scope, ownership model, and position in the assembly precedence chain.

### 3.1 Base Layer

**Purpose:** The foundation entity for a resource. Defines the minimum required fields and their default values for a given resource context. Everything starts with a Base Layer.

**Scope:** Can be type-agnostic (a universal base) or type-scoped (a base specific to a Resource Type). A Base Layer that is type-scoped must declare its Resource Type.

**Ownership:** DCM platform or platform implementor.

**Characteristics:**
- Every layer chain must begin with a Base Layer
- Base Layers contain only universal fields — no provider-specific data
- A Base Layer for a typed resource must conform to the Resource Type Specification's universal field requirements
- Multiple Base Layers can exist for the same context — the applicable one is selected based on the request context

**Examples:**
- CIS Benchmark base configuration
- Baseline OS configuration
- DMZ network base configuration

---

### 3.2 Core Layers

**Purpose:** Provide data that is applicable across any resource type. Core Layers carry organizational, infrastructure, and contextual data that is not specific to any one service.

**Scope:** Type-agnostic by default. Core Layers apply to all resource types unless explicitly scoped. This is the primary distinction from Service Layers.

**Ownership:** DCM platform, infrastructure teams, or platform implementors.

**Characteristics:**
- Applied to every request regardless of resource type
- Cannot contain service-specific or provider-specific data
- Carry location, organizational, and infrastructure context
- Stored in the Core Layer Store
- Cached in the Service Layer Cache at deployment time

**Examples:**
- Data Center layer (DC1, DC2)
- Zone layer (Zone 1, Zone 2)
- Rack layer
- Geographic region layer
- Environment layer (production, staging, development)

---

### 3.3 Intermediate / Customization Layers

**Purpose:** Provide organizational or contextual overrides and customizations that sit between the base standards and the service-specific configuration. These layers encode the organizational hierarchy and deployment context.

**Scope:** Can be type-agnostic or type-scoped. Scope is declared per layer.

**Ownership:** Organizational teams, domain owners, platform implementors.

**Characteristics:**
- Stack between Core Layers and Service Layers in the precedence chain
- Encode organizational structure (business unit, enclave, logical unit)
- Allow organizational customization without modifying base standards
- The Git repo hierarchy typically mirrors the intermediate layer hierarchy

**Examples:**
- Ship layer (in Navy context: specific vessel configuration)
- Enclave layer (isolated network segment configuration)
- Business unit layer
- DMZ customization layer
- Production web tier layer

---

### 3.4 Service Layers

**Purpose:** Provide service-specific data required to build a complete request payload for a specific Resource Type. Service Layers are the bridge between general organizational context and provider-ready configuration.

**Scope:** **Must be type-scoped.** A Service Layer without a declared Resource Type scope is invalid. The scope inheritance behavior is configurable per Service Layer declaration.

**Type Scope Declaration:**
```yaml
type_scope:
  resource_type_uuid: <uuid of Resource Type>
  resource_type_fully_qualified_name: <Category.ResourceType>
  scope_inheritance: <exact|descendants>
  # exact: applies only to the declared Resource Type
  # descendants: applies to the declared Resource Type and all child types via inheritance
```

**Ownership:** Service Providers or service domain teams. Stored in Service Layer SCM (source control management). Registered with DCM as part of Service Provider registration.

**Characteristics:**
- Only applied when the request resource type matches the layer's declared type scope
- Carry service-specific configuration, defaults, and constraints
- Must not contain provider-specific data unless marked as portability-breaking
- Cached in the Service Layer Cache at Service Provider registration time

**Examples:**
- VM sizing layer (small, medium, large configurations for `Compute.VirtualMachine`)
- Web server configuration layer for `Compute.VirtualMachine`
- Network port configuration layer for `Network.Port`
- CL Web Service Data Layer for `Compute.VirtualMachine` (exact scope)
- General compute placement layer for `Compute.VirtualMachine` and descendants

---

### 3.5 Request Layer

**Purpose:** Carries the consumer's declared intent. The Request Layer is what the consumer provides — the fields they explicitly specify for their resource request.

**Scope:** Scoped to the Resource Type the consumer is requesting.

**Ownership:** Consumer (via Web UI or Consumer API).

**Characteristics:**
- Created at the time the consumer submits a request
- Contains only what the consumer explicitly declares — it does not need to be complete
- The gap between what the consumer declares and what the provider needs is filled by the lower layers in the chain
- Has higher precedence than all data layers below it — consumer-declared values override layer defaults
- Is the direct source of the **Intent State** — the Request Layer as submitted by the consumer is stored in the Intent Store before any processing occurs
- After assembly and policy processing, the enriched payload becomes the **Requested State**

**Examples:**
- Consumer requests a VM with `cpu_count: 8`, `ram_gb: 32`, `os: RHEL9`, `environment: production`
- Consumer requests a firewall rule with source/target network and port

---

### 3.6 Policy Layers

**Purpose:** Policy Layers are not data layers in the traditional sense — they do not add fields to the merge chain. Instead, they operate on the assembled payload after the data layers have been merged. They are the governance layer of the assembly process.

**Scope:** Scoped by policy type and domain. Core Policies apply to all requests. Service Policies apply to specific Resource Types. Organizational and domain policies apply to specific organizational scopes.

**Ownership:** Policy creators, security teams, compliance teams, organizational domain owners.

**Policy Layer Types and Their Behavior:**

| Policy Type | Behavior | Precedence Effect |
|-------------|----------|-------------------|
| **Validation** | Checks data against rules. Does not modify data. Returns pass/fail. If fail, request is rejected. | No precedence — pass/fail only |
| **Transformation** | Enriches or modifies data in the payload. Adds missing fields, applies standards, fills gaps. | Adds to or modifies the assembled payload — recorded in provenance |
| **GateKeeper** | Highest authority. Can override any field regardless of what was declared in lower layers or the Request Layer. Can halt execution entirely. Used for sovereignty constraints, security mandates, and hard compliance rules. | Overrides everything — including consumer input |

**Characteristics:**
- Policies operate only on the policy definition, core data, and the data in the request payload
- Policy outcomes are deterministic — same input always produces same output for a given policy version
- All policy modifications are recorded in field-level provenance with policy UUID, operation type, and reason
- Policies are versioned using the universal versioning scheme
- Policies are maintained via GitOps practices

---

## 4. Layer Identity — Domain, Handle, and Priority

Every layer has a formal identity model with three components that together make it uniquely identifiable, locatable, and orderable within DCM.

### 4.1 Layer Domain

The **Layer Domain** is the organizational and architectural home of a layer. It declares ownership, storage location, and authorization scope — who can create and modify this layer, and which other layers it can override.

| Domain | Meaning | Authorization | Can Override |
|--------|---------|--------------|-------------|
| `system` | DCM built-in layers, shipped with DCM | DCM maintainers only | Nothing above system |
| `platform` | Platform team layers, apply across all tenants | Platform team | tenant, service, provider |
| `tenant` | Tenant-specific layers | Tenant Admin | service, provider within tenant |
| `service` | Service Provider contributed layers | Service Provider owner | provider |
| `provider` | Provider Catalog Item layers | Provider owner | Nothing above provider |

A lower-domain layer cannot override a higher-domain layer. A `tenant` layer cannot override a `platform` layer. This is enforced at ingestion — the conflict detection pipeline checks domain authority before allowing a merge.

### 4.2 Layer Handle

The **Layer Handle** is the human-readable, stable identifier for a layer within DCM. It complements the UUID (machine-meaningful) with a reference that humans can use in conversation, documentation, policy declarations, and audit records.

**Format:** `{domain}/{layer_type}/{name}`

**Examples:**
```
platform/core/cis-benchmark-linux
platform/core/security-cpu-limits
tenant/service/payments-vm-standards
system/base/universal-defaults
service/service/kubevirt-vm-defaults
provider/service/cloudnativepg-database-config
```

**Rules:**
- Unique within DCM — enforced at ingestion
- Stable across versions — the handle does not change when a new version is published
- URL-safe characters only — lowercase, hyphens, forward slashes
- The Git file path mirrors the handle structure exactly

**Git path from handle:**
```
{layer_store_root}/{domain}/{layer_type}/{name}/v{Major}.{Minor}.{Revision}.yaml

# Example:
dcm-layers/platform/core/security-cpu-limits/v1.2.0.yaml
dcm-layers/tenant/{tenant-uuid}/service/payments-vm-standards/v1.0.0.yaml
```

### 4.3 Priority Schema

The **Priority Schema** is the deterministic ordering mechanism for resolving conflicts between layers of the same type and scope. It uses a hierarchical dotted-notation system that supports infinite differentiation — new priority values can always be inserted between any two existing values.

**Format:** `{integer}.{integer}.{integer}...` — unlimited depth

**Comparison:** Left-to-right, segment by segment. **Higher numeric value = higher priority.** No ceiling — you can always go higher.

```
900.10    beats    800.10    (900 > 800 at segment 1)
900.20    beats    900.10    (20 > 10 at segment 2)
900.10.5  beats    900.10    (longer path with matching prefix — 5 at segment 3 > nothing)
900.10.10 beats    900.10.5  (10 > 5 at segment 3)
```

**Infinite insertability — symmetric in both directions:**
Between `900.10` and `900.20` insert `900.15`. Between existing values or above the current maximum — there is no ceiling. You can always go higher. This is the key advantage over a lower-wins model which would have a hard floor at 1.

**Priority Label:** Semantic context for the numeric value — human-readable, does not affect ordering.

**Reference Priority Taxonomy (advisory — not enforced by DCM):**

DCM ships a reference taxonomy as documentation and starter templates. Organizations adopt, adapt, or ignore it — DCM resolves conflicts purely by numeric comparison. The taxonomy is a suggested convention, not a system constraint.

| Suggested Range | Category | Rationale |
|-----------------|----------|-----------|
| `900.*` | Compliance | Regulatory mandates — highest authority |
| `800.*` | Security | Security standards |
| `700.*` | Sovereignty | Data residency constraints |
| `600.*` | Operations | SRE and operational standards |
| `500.*` | Platform | Platform-level defaults |
| `400.*` | Service | Service-specific configuration |
| `300.*` | Organization | Organizational defaults |
| `200.*` | Site | Location-specific overrides |
| `100.*` | Custom | Implementor-defined — lowest standard category |

Higher number = higher priority. An organization that needs a mandate above all standard categories simply uses `1000.*` or above — no renumbering required. An organization that prioritizes sovereignty above compliance would simply swap their `700.*` and `900.*` ranges.

**Priority in a layer definition:**

```yaml
priority:
  value: "800.30.10"
  label: "security.container.cpu_limits"
  category: security
  rationale: >
    CPU limit enforcement for container workloads per
    CISO mandate SEC-2024-047. Overrides platform defaults
    to ensure no container can exceed approved limits.
```

---

## 4b. Artifact Metadata Standard

Every DCM artifact — layers, policies, resource types, catalog items, provider registrations, entity definitions, and all other defined or stored objects — carries a standard **Artifact Metadata** block. This is a structural requirement, not optional.

The artifact metadata block answers: **who created this, when, who owns it, what changed, and how do we contact them?**

### 4b.1 Universal Artifact Metadata Structure

```yaml
artifact_metadata:

  # Identity
  uuid: <uuid — assigned by DCM at creation, immutable>
  handle: <domain/type/name — human-readable stable identifier>

  # Versioning
  version: <Major.Minor.Revision>
  status: <developing|proposed|active|deprecated|retired>

  # Status detail — populated per status
  status_detail:
    # When status: proposed
    proposed_at: <ISO 8601>
    proposed_by:
      uuid: <actor UUID — optional>
      display_name: <required>
      email: <optional>
    shadow_execution:
      enabled: <true|false — only meaningful for policy artifacts>
      started_at: <ISO 8601>
      evaluation_count: <integer — requests shadowed so far>
      validation_dashboard_url: <URL to shadow output review>

    # When status: deprecated
    deprecated_at: <ISO 8601>
    deprecated_by:
      uuid: <actor UUID>
      display_name: <required>
    replacement_uuid: <UUID of replacement artifact>
    replacement_handle: <handle of replacement artifact>
    deprecation_reason: <human-readable>
    migration_guidance: <what users should do>
    sunset_date: <ISO 8601 — when it becomes retired>

    # When status: retired
    retired_at: <ISO 8601>
    retired_by:
      uuid: <actor UUID>
      display_name: <required>

  # Origination
  created_by:
    uuid: <actor UUID — optional when no Identity Provider registered>
    display_name: <required — human-readable name>
    email: <optional — direct contact fallback>
    notification_endpoint: <optional — automated notification target>
  created_at: <ISO 8601>
  created_via: <pr|api|migration|system>
  # pr:        submitted via GitOps PR workflow — full review history available
  # api:       submitted via direct API
  # migration: imported from external system — provenance depth may be limited
  # system:    created by DCM itself (entity stubs, system artifacts)

  # Ownership — may differ from creator
  owned_by:
    uuid: <actor or team UUID — optional>
    display_name: <required — team or individual name>
    email: <optional>
    notification_endpoint: <optional — receives conflict and deprecation alerts>
  # Note: created_by is the audit record (who physically submitted it)
  # owned_by is the accountability record (who is responsible and gets notified)

  # Modification history — append-only
  modifications:
    - sequence: 1
      modified_by:
        uuid: <actor UUID — optional>
        display_name: <required>
        email: <optional>
      modified_at: <ISO 8601>
      modification_type: <create|update|deprecate|retire|restore|status_change>
      version_before: <Major.Minor.Revision>
      version_after: <Major.Minor.Revision>
      change_summary: <human-readable — what changed>
      pr_reference: <Git PR URL — if via PR workflow>
      reason: <why this change was made>
```

### 4b.2 The Five Artifact Statuses

| Status | Meaning | Executes? | Output Applied? | Output Captured? | Merges to Active? |
|--------|---------|-----------|----------------|-----------------|------------------|
| `developing` | In active development. Development mode / dev pipeline only. | Dev mode only | No | Dev logs only | No — must transition to proposed first |
| `proposed` | Development complete. Submitted for validation. Shadow mode for policies. | Yes (shadow) | No | Yes — validation report | Yes — after review approval |
| `active` | Live and governing. Applied to all relevant requests. | Yes | Yes | Yes — audit/provenance | N/A |
| `deprecated` | Being phased out. Replacement available. Works but warns. | Yes | Yes | Yes — with deprecation warning | N/A |
| `retired` | End of life. Cannot be used. | No | No | No | No |

**Status transition rules:**
```
developing → proposed  (author submits for review)
developing → retired   (author abandons without proposing)
proposed   → active    (reviewers approve — via PR merge or API approval)
proposed   → developing (returned for rework)
active     → deprecated (replacement available — sunset date declared)
deprecated → retired   (sunset date reached or manual retirement)
retired    → (terminal — no transitions out)
```

### 4b.3 Proposed Status — Shadow Execution for Policies

When a policy artifact is in `proposed` status, it runs in **shadow mode** against real request traffic:

- Executes alongside active policies on every relevant request
- Output is captured in a `proposed_evaluation_record` — what it would have done
- Output is **never applied** to the actual request
- Shadow output feeds the Validation Dashboard for reviewer analysis
- Policy authors can see aggregate impact before activation

```yaml
# Shadow output record — captured per real request evaluated
proposed_evaluation_record:
  policy_uuid: <uuid>
  policy_version: <version>
  request_uuid: <real request being shadowed>
  tenant_uuid: <tenant>
  evaluated_at: <ISO 8601>
  would_have_applied: <true|false>
  shadow_output:
    would_have_rejected: <true|false>
    rejection_reason: <if would_have_rejected>
    would_have_patched:
      - field: <field path>
        current_value: <value in real payload>
        would_have_set: <value policy would have applied>
        reason: <policy reason>
    would_have_locked:
      - field: <field path>
        lock_type: <constrained|immutable>
        reason: <policy reason>
    would_have_selected_provider: <provider UUID — if policy sets provider constraints>
  impact_assessment:
    category: <none|low|medium|high|critical>
    # none:     policy would not have applied to this request
    # low:      minor enrichment only
    # medium:   significant field modifications
    # high:     would have rejected or locked critical fields
    # critical: would have rejected or overridden consumer intent
```

### 4b.4 Contact Info — Two Modes

Contact information supports both IdP-backed and standalone deployments:

**Mode 1 — Identity Provider backed:**
The `uuid` field contains the DCM external entity reference UUID linking to an Identity.Person or Identity.Team in a registered Information Provider. The `display_name` is cached non-authoritatively for UI display. DCM can resolve the full identity record via the Information Provider on demand.

**Mode 2 — Standalone (no Identity Provider):**
The `uuid` field is absent. `display_name`, `email`, and `notification_endpoint` are the primary identity fields. DCM accepts and records these directly without external verification. This mode supports bootstrapping, air-gapped deployments, and organizations that have not yet registered an Identity Information Provider.

Both modes are fully supported. An organization can start in standalone mode and migrate to IdP-backed mode by adding `uuid` fields to existing artifact metadata — no other changes required.

### 4b.5 Notifications from Artifact Metadata

The `owned_by.notification_endpoint` is the target for all proactive DCM notifications about an artifact:

| Event | Who Is Notified |
|-------|----------------|
| Layer conflict detected at ingestion | Owner of new layer AND owner of conflicting existing layer |
| Layer deprecated | Owners of all artifacts that reference the deprecated layer |
| Provider deregistered | Owners of all catalog items backed by that provider |
| Policy violation | Owner of the entity that violated the policy |
| Drift detected | Owner of the entity that drifted |
| Proposed policy shadow shows high/critical impact | Policy owner and designated reviewers |
| Artifact approaching sunset date | Artifact owner |

---

## 4c. Conflict Detection at Ingestion

Conflict detection runs at layer ingestion time — not at request assembly time. This ensures all layers in DCM are conflict-free before they are ever used.

### 4c.1 Ingestion CI Pipeline

When a layer is committed to the Layer Store (Git branch created or updated):

```
Layer committed to Git branch
  │
  ▼
CI Pipeline fires automatically
  │
  ├── 1. Schema validation
  │      Is the layer well-formed per the layer schema?
  │      Does it carry required artifact metadata?
  │      Is the version correctly incremented?
  │
  ├── 2. Handle validation
  │      Is the handle unique in DCM?
  │      Does the handle match the Git path?
  │      Does the domain match the submitting actor's authorization?
  │
  ├── 3. Scope validation
  │      If type-scoped: do declared resource types exist in the registry?
  │      Is the layer type consistent with the domain?
  │
  ├── 4. Priority validation
  │      Is the priority value in valid dotted-notation format?
  │      Does the priority category match the domain advisory range?
  │      (Warning only if category/domain mismatch — not a block)
  │
  ├── 5. Conflict detection
  │      For each field in this layer:
  │        Find all active layers of the same type and overlapping scope
  │        Check if any declare the same field
  │        If conflict found:
  │          → Does the new layer declare a higher priority? → Allowed, documented
  │          → Does the existing layer declare a higher priority? → Allowed, documented
  │          → Neither declares priority? → CONFLICT ERROR — PR blocked
  │          → Both declare equal priority? → CONFLICT ERROR — PR blocked
  │          → Domain authority violation? → CONFLICT ERROR — PR blocked
  │
  │      Conflict notification:
  │        Posted as PR comment with: conflicting layer UUID, handle, owner
  │        Both layer owners notified via notification_endpoint
  │
  ├── 6. Deprecation reference validation
  │      If status: deprecated — does replacement UUID exist?
  │
  └── 7. Result
         All checks pass → PR approved for merge
         Any check fails → PR blocked, detailed error comment posted
```

### 4c.2 Conflict Resolution Rules

| Situation | Resolution | Action |
|-----------|-----------|--------|
| New layer and existing layer conflict, no priority on either | CONFLICT ERROR | PR blocked. Both owners notified. One must declare priority or remove the conflicting field. |
| New layer has higher priority (higher value) than existing | Allowed — new layer wins | Documented in provenance. Warning posted if domain authority is unusual. |
| Existing layer has higher priority | Allowed — existing layer wins | New layer is a lower-priority alternative. Documented. |
| Both layers have equal priority | CONFLICT ERROR | PR blocked. Priority must be differentiated. |
| New layer from lower domain overrides higher domain | CONFLICT ERROR | Domain authority violation. Platform cannot be overridden by service layer. |
| Priority category suggests domain mismatch | WARNING | PR comment posted, not blocked. Merge allowed but reviewers are notified. |

### 4c.3 Pre-Validation of All Layers

Because conflict detection runs at ingestion, all layers resident in DCM are pre-validated:

- No two active layers of the same type and scope conflict without explicit priority resolution
- The assembly process never encounters an ambiguous merge — all conflicts are resolved at definition time
- If a conflict is discovered after the fact (e.g., a new layer is activated that conflicts with an existing one that was already active when the new layer was ingested), the newer layer's ingestion pipeline should have caught this. A background validation job runs periodically to detect any edge cases.

---

## 4d. Complete Layer Definition Structure

Combining all elements — identity, artifact metadata, scope, priority, and fields:

```yaml
# Complete layer definition
layer:
  # === ARTIFACT METADATA (universal — required on all artifacts) ===
  artifact_metadata:
    uuid: "layer-uuid-001"
    handle: "platform/core/security-cpu-limits"
    version: "1.2.0"
    status: active
    created_by:
      uuid: "actor-uuid-001"       # Optional — present if IdP registered
      display_name: "Jane Smith"
      email: "jane.smith@example.com"
      notification_endpoint: "https://notify.example.com/webhooks/jane"
    created_at: "2026-01-15T10:30:00Z"
    created_via: pr
    owned_by:
      uuid: "team-uuid-security"   # Optional — present if IdP registered
      display_name: "Platform Security Team"
      email: "platform-security@example.com"
      notification_endpoint: "https://notify.example.com/webhooks/platform-security"
    modifications:
      - sequence: 1
        modified_by:
          display_name: "Jane Smith"
          email: "jane.smith@example.com"
        modified_at: "2026-01-15T10:30:00Z"
        modification_type: create
        version_before: null
        version_after: "1.0.0"
        change_summary: "Initial creation — CPU limits per CISO mandate SEC-2024-047"
        pr_reference: "https://github.com/org/dcm-layers/pull/42"
        reason: "CISO mandate SEC-2024-047 requires CPU limits on all containers"
      - sequence: 2
        modified_by:
          display_name: "Bob Jones"
          email: "bob.jones@example.com"
        modified_at: "2026-02-20T14:00:00Z"
        modification_type: update
        version_before: "1.0.0"
        version_after: "1.2.0"
        change_summary: "Increased CPU limit from 4 to 8 per updated mandate"
        pr_reference: "https://github.com/org/dcm-layers/pull/67"
        reason: "Updated CISO mandate SEC-2024-047-rev2 allows 8 CPU"

  # === LAYER IDENTITY ===
  domain: platform
  layer_type: core

  scope:
    resource_types:
      - Compute.Container
      - Compute.Pod
    # Empty list = type-agnostic (applies to all resource types)

  priority:
    value: "200.30.10"
    label: "security.container.cpu_limits"
    category: security
    rationale: >
      CPU limit enforcement for container workloads per
      CISO mandate SEC-2024-047. Overrides platform defaults.

  # === LAYER CHAIN ===
  parent_chain:
    - uuid: "base-layer-uuid-001"
      handle: "system/base/universal-defaults"
      version: "1.0.0"
      layer_type: base

  # === FIELDS ===
  fields:
    cpu_limit:
      value: 8
      metadata:
        basis_for_value: "CISO mandate SEC-2024-047-rev2"
        baseline_value: 4
      override: constrained
      constraint_schema:
        minimum: 1
        maximum: 8
```

---

---

## 5. Precedence and Merge Rules

When layers are merged to produce the assembled payload, fields from higher-precedence layers override fields from lower-precedence layers. The precedence order from lowest to highest is:

```
1. Base Layer                    (lowest precedence — foundation defaults)
2. Core Layers                   (organizational and infrastructure context)
3. Intermediate/Customization    (organizational hierarchy overrides)
4. Service Layers                (service-specific configuration)
5. Request Layer                 (consumer intent — overrides all data layers)
6. Transformation Policies       (enrichment — adds or modifies fields)
7. Validation Policies           (pass/fail — no field modification)
8. GateKeeper Policies           (highest authority — overrides everything)
```

### 5.1 Override Behavior

- A higher-precedence layer that declares a field **overrides** the value from all lower-precedence layers
- A higher-precedence layer that does **not** declare a field leaves the lower-precedence value intact
- Fields not declared at any layer level are absent from the payload — providers must declare all required fields as being covered by at least one layer in the chain
- GateKeeper policies can override **any** field including consumer-declared Request Layer values — this is the mechanism for enforcing sovereignty constraints, security mandates, and hard compliance rules

### 5.2 Additive vs. Override Fields

Some fields are **scalar** (a single value — one layer wins) and some are **additive** (a list or set — layers contribute to a collection). The field type in the Resource Type Specification declares which behavior applies:

```yaml
field_name:
  type: <string|integer|boolean|enum|uuid|object|list>
  merge_behavior: <override|additive>
  # override: higher precedence layer's value replaces lower precedence value
  # additive: all layers contribute their values to a merged collection
```

### 5.3 Conflict Resolution

When two layers at the same precedence level declare conflicting values for the same field:
- The conflict is recorded and surfaced as a validation error
- The request is not processed until the conflict is resolved
- Conflict resolution is never silent — it is always recorded in provenance

---

## 5a. Field Override Control

Field override control is the mechanism by which DCM governs **who can change what, under what conditions**, across the layer precedence chain. It was present in the original data model rules as "override preference" metadata on fields — this section formalizes that concept as a graduated model that is **simple by default and powerful when needed**.

**Design Principle:** A field with no override declaration is fully overridable by anyone. Restrictions are always opt-in. The model has three levels — you use only the level you need. Levels 1 and 2 cover the vast majority of real-world cases. Level 3 exists for fields that genuinely require nuanced, actor-specific governance.

---

### 5a.1 Two Categories of Override Rule

**Category 1 — Structural Rules (Request Payload Processor — non-overridable)**

Enforced by the Request Payload Processor as DCM System behavior. Not configurable. Always applied:

- A layer entity is immutable once versioned — no override can modify a published version
- A child layer cannot remove a field declared in a parent layer — it can only override the value
- The layer precedence order is fixed — Base → Core → Intermediate → Service → Request → Policy
- Circular layer references are rejected unconditionally
- A Service Layer without a declared type scope is rejected unconditionally

**Category 2 — Business Rules (Policy Engine — configurable)**

Enforced by the Policy Engine using the Validation/Transformation/GateKeeper mechanism. Override control metadata is set exclusively by the Policy Engine and carried in the payload as part of field-level provenance. Data layers and the Request Payload Processor never set override control.

---

### 5a.2 Where Override Control is Declared

Override control can be declared at two static levels and applied dynamically at runtime:

**Level A — Resource Type Specification (portable, sets the ceiling)**
Declares the default override behavior for a field across all implementations of that Resource Type. These defaults travel with the type definition and apply to all providers and catalog items that implement the type. This sets the maximum permissiveness ceiling — lower levels can only restrict further.

**Level B — Catalog Item (offering-specific, can only restrict)**
Declares additional restrictions for a specific curated offering beyond the Resource Type defaults. A "PCI Production VM" catalog item can lock `encryption_standard` to a single value even if the VM Resource Type allows a broader enum. Cannot expand beyond what the Resource Type permits.

**Level C — Policy Engine (runtime, within static bounds)**
Applies override control at request processing time based on current organizational policies. Can only restrict within the bounds established by the Catalog Item (or Resource Type if no Catalog Item restriction exists). Higher-authority policy levels (Global) can grant expansion to trusted actors within their authority scope.

**Inheritance Rule:** Override control can only be made more restrictive as it flows down the declaration hierarchy — Resource Type → Catalog Item → Runtime Policy. The sole exception is explicit trusted grants made by higher-authority actors (see Section 5a.6).

---

### 5a.3 Level 1 — No Declaration (Default)

No override control declaration on a field means it is fully overridable by any actor. This is the default for all fields. Zero configuration required.

```yaml
# Level 1 — fully overridable, no declaration needed
cpu_count:
  value: 4
```

This covers the majority of fields in most implementations.

---

### 5a.4 Level 2 — Simple Declaration

A single `override` property covers the most common governance needs without requiring a full matrix. Sufficient for most governed fields.

```yaml
# Level 2a — nobody can change this
sovereignty_zone:
  value: us-east
  override: immutable

# Level 2b — anyone can change but only within these values
encryption_standard:
  value: AES-256
  override: constrained
  constraint_schema:
    enum: [AES-256, AES-128]

# Level 2c — explicit allow (same as default, but self-documenting)
display_name:
  value: my-vm
  override: allow
```

| Value | Meaning | Enforcement |
|-------|---------|-------------|
| `allow` | Default. Any actor may override. | Structural rules |
| `constrained` | Any actor may override within `constraint_schema` | Policy Engine — Validation |
| `immutable` | No actor may override at any level | Policy Engine — GateKeeper |

---

### 5a.5 Level 3 — Matrix Declaration

Full actor-level control for fields that require nuanced governance. Used only when Level 2 is insufficient.

```yaml
billing_tag:
  value: engineering
  override_matrix:
    default: allow
    # Default permission for any actor not explicitly listed
    # Options: allow | constrained | deny

    inheritance: restrict_only
    # Catalog Items and lower-level declarations can only restrict
    # Higher-authority actors can grant expansion via trusted_grants

    actors:
      - actor: policy.global
        permission: allow
        can_expand: true
        # Global policies can always override and can grant expansion
        # to lower actors via trusted_grants

      - actor: policy.tenant
        permission: allow
        can_expand: true
        # Tenant policies can override and grant within global ceiling

      - actor: policy.user
        permission: deny
        can_expand: false
        # User policies cannot override and cannot grant to others

      - actor: consumer_request
        permission: constrained
        constraint_schema:
          pattern: "^[a-z0-9-]+$"
        can_expand: false
        # Consumers can override within pattern, cannot grant expansion

      - actor: process_resource
        permission: deny
        can_expand: false
        # Automation denied by default — grant via trusted_grants

      - actor: provider
        permission: deny
        can_expand: false
        # Providers cannot modify this field

      - actor: sre_override
        permission: allow
        can_expand: false
        # SREs have operational authority but cannot grant to others

      - actor: admin_override
        permission: allow
        can_expand: true
        # Admins can override and grant within their scope level

    trusted_grants:
      # Explicit expansion grants from higher-authority actors
      # Used when an actor needs more permission than their default
      - granted_to_uuid: <uuid of specific automation pipeline>
        actor_type: process_resource
        permission: allow
        granted_by_policy_uuid: <uuid of policy granting this>
        reason: Patching automation trusted to update billing_tag
        expires: <ISO 8601 timestamp — optional>

    constraint_schema:
      pattern: "^[a-z0-9-]+$"
      # Applied to all actors with permission: constrained
```

---

### 5a.6 Actor Registry

The actor list is extensible. DCM ships with built-in actors. Organizations register custom actors following the same model. Custom actors default to `deny` until explicitly granted permissions.

**Built-in actors:**

| Actor | Default Scope | Can Expand | Notes |
|-------|--------------|------------|-------|
| `policy.global` | All tenants | ✅ | Highest authority — can grant to any actor |
| `policy.tenant` | Single tenant | ✅ | Within global ceiling |
| `policy.user` | Single user | ❌ | Can only restrict |
| `consumer_request` | Request submitter | ❌ | Can only restrict |
| `process_resource` | Automation execution | ❌ by default | Requires trusted grant |
| `provider` | Service Provider | ❌ | Can only restrict |
| `sre_override` | SRE team | ❌ | Operational authority, cannot grant |
| `admin_override` | DCM Admin | ✅ | Within their scope level |

**Custom actor registration:**

```yaml
custom_actor:
  uuid: <uuid>
  name: <actor name>
  description: <description>
  registered_by_tenant_uuid: <uuid — or null for global>
  default_permission: deny
  # Custom actors always default to deny until explicitly granted
  can_expand: false
  # Custom actors cannot expand by default — requires explicit grant
  version: <Major.Minor.Revision>
  status: <active|deprecated|retired>
  provenance:
    <standard provenance metadata>
```

Custom actors follow the universal versioning and deprecation model. A custom actor registered at Tenant scope cannot be granted Global-level authority.

---

### 5a.7 Expansion Rules

Actor expansion follows a strict hierarchy:

- **`policy.global`** and **`admin_override`** at global scope — can grant expansion to any actor for any field, including fields declared `immutable` at lower levels
- **`policy.tenant`** and **`admin_override`** at tenant scope — can grant expansion within their tenant, cannot expand beyond what Global permits
- **`policy.user`**, **`consumer_request`**, **`provider`** — can never grant expansion regardless of what they receive
- **`sre_override`** — can never grant expansion but can be granted expansion by Tenant or Global
- **`process_resource`** — denied by default, can be granted expansion by Tenant or Global via `trusted_grants`
- **Custom actors** — denied by default, can be granted expansion by the level that registered them or higher

**Trusted grants expire** — if an `expires` timestamp is set, the grant is automatically revoked at that time. Expired grants are retained in provenance for audit purposes but are no longer applied.

---

### 5a.8 Override Control in the Assembly Process

Override control is applied during Step 5 (Policy Processing) of the assembly process:

```
Layer Merge complete (Steps 1-4)
  │  Fields have values — all fields default to Level 1 (allow)
  │  Static override declarations from Resource Type and Catalog Item are loaded
  ▼
Transformation Policies
  │  May set override: constrained or override_matrix on fields
  │  May set baseline_value and basis_for_value metadata
  │  Records policy UUID, level, and reason in field provenance
  ▼
Validation Policies
  │  Verify existing override declarations are not violated
  │  Verify actor permissions against current override_matrix
  │  Pass/fail — no modification to override control
  ▼
GateKeeper Policies
  │  May set override: immutable on fields
  │  May override field values before locking
  │  May issue trusted_grants to specific actors
  │  Records policy UUID, level, lock type, and reason in provenance
  ▼
Requested State
  │  All governed fields carry full override control metadata
  │  Provenance chain complete — every lock and grant is traceable
  ▼
```

---

### 5a.9 Override Control and Rehydration

During rehydration, the Intent State is replayed through the **current** Policy Engine. Override control declared in current policies is applied fresh. A field that was `allow` in the original request may be `immutable` if a new GateKeeper policy was added since. This is by design — rehydration applies current governance standards, not historical ones.

The original consumer intent is preserved unchanged in the Intent Store. The new realized state reflects current governance. Both are auditable and traceable.

The one exception is `pinned` policy version rehydration (Historical Exact or Historical Portable modes) — this deliberately replays historical policies and may bypass current immutable locks. Pinned rehydration requires elevated authorization precisely for this reason.

---

### 5a.11 Global Policy Self-Override — The Immutable Ceiling Model

**Q51 resolved:** When a Global GateKeeper policy sets `override: immutable` on a field, can a higher-priority Global policy still override it?

**The answer emerges from execution order.** Policies execute highest-priority-first (highest numeric value first within a tier). The first policy to set `override: immutable` on a field locks it. All subsequent policies — including other Global policies with lower priority values — find the field locked and cannot modify it. In normal request processing, **default `immutable` is effectively absolute** — not through a special rule, but through execution order.

**The `immutable_ceiling` declaration** is a forward-looking protection for fields that must remain locked even if a higher-priority policy is **added to the system later**:

```yaml
# Default immutable — protected by execution order during this request
# The highest-priority Global GateKeeper to run first locks it
# No subsequent policy in this execution can change it
sovereignty_zone:
  value: eu-west
  override: immutable
  # Safe in practice — execution order guarantees the first-runner wins
  # Does NOT protect against a new higher-priority policy being added tomorrow

# Absolute immutable — explicit forward-looking protection
# Protected even if a new higher-priority policy is added to the system
classification_level:
  value: RESTRICTED
  override: immutable
  immutable_ceiling: absolute
  # Cannot be overridden by ANY policy, ever
  # If a policy attempts to override this, it receives a hard rejection
  # The attempted override is logged in audit with full provenance
  # Use for: sovereignty zones, data classification, hard compliance mandates
```

**The formal rule:**

| Declaration | Protected During Execution? | Protected Against Future Policies? | Use Case |
|-------------|----------------------------|-------------------------------------|---------|
| `override: immutable` (default) | ✅ Yes — execution order | ❌ No | Most governed fields |
| `override: immutable` + `immutable_ceiling: absolute` | ✅ Yes | ✅ Yes — hard rejection | True non-negotiables |

**`immutable_ceiling: absolute` is the nuclear option.** Use it sparingly — only for fields where the governance requirement is genuinely non-negotiable regardless of any future organizational policy change. Sovereignty zone on a sovereign deployment. Data classification on a restricted system. Encryption standard under a regulatory mandate with no variance permitted.

**Audit behavior:** When a policy attempts to override a field with `immutable_ceiling: absolute`, the attempt is rejected silently from the requesting policy's perspective (the field simply doesn't change) but is fully logged in the Audit Store with the policy UUID, the attempted value, the rejection reason, and the UUID of the policy that set the ceiling.

---

### 5a.10 Override Control Metadata — Full Structure

The complete field metadata structure carrying override control in the payload:

```yaml
field_name:
  value: <current value>
  metadata:
    # Simple declaration (Level 2) — set by Policy Engine at runtime
    override: <allow|constrained|immutable>
    # OR matrix declaration (Level 3) — set by Policy Engine at runtime
    override_matrix:
      <full matrix structure per Section 5a.5>

    # Always present regardless of level
    basis_for_value: <human-readable — why this value was set>
    baseline_value: <the original default before any override>
    locked_by_policy_uuid: <uuid of policy that set this>
    locked_at_level: <global|tenant|user>
    constraint_schema: <JSON Schema — if constrained>

  provenance:
    origin:
      value: <original value>
      source_type: <layer type or source>
      source_uuid: <uuid>
      timestamp: <ISO 8601>
    modifications:
      - sequence: 1
        previous_value: <value before>
        modified_value: <value after>
        source_uuid: <uuid of modifying entity>
        operation_type: <enrichment|transformation|validation|gatekeeping|override|lock|grant>
        actor: <actor type that performed this operation>
        timestamp: <ISO 8601>
        reason: <human-readable>
```

---

The Request Payload Processor assembles the final payload by executing the following steps in order. Each step is recorded in the payload's provenance chain.

### Step 1 — Intent Capture
The consumer's Request Layer is received and stored as the **Intent State** in the Intent Store. No modification occurs at this step. The Intent State is the immutable record of what the consumer asked for.

### Step 2 — Layer Resolution
The Request Payload Processor determines which layers apply to this request:
- Identifies the Resource Type from the Request Layer
- Retrieves the applicable Base Layer for the request context
- Retrieves all applicable Core Layers (type-agnostic — all apply)
- Retrieves applicable Intermediate/Customization Layers based on organizational context
- Retrieves applicable Service Layers whose declared type scope matches the request Resource Type
- Orders all retrieved layers according to the precedence chain

### Step 3 — Layer Merge
Layers are merged in precedence order (lowest to highest). For each field:
- The value from the highest-precedence layer that declares it is used
- The source layer UUID and layer type are recorded in the field's provenance metadata
- Additive fields accumulate values from all layers that declare them

### Step 4 — Request Layer Application
The consumer's Request Layer is applied last in the data layer merge. Consumer-declared values override all data layer values. Each override is recorded in provenance.

### Step 5 — Policy Processing
Policies are applied to the merged payload in order. Each policy step may read and set `override_control` metadata on fields — see Section 5a for full detail.
1. **Transformation Policies** — enrich and modify the payload. May set `override_preference: constrained` on fields, declaring that future overrides must satisfy a constraint schema. Each transformation records the policy UUID, operation type, reason, and any override control declarations in the affected fields' provenance.
2. **Validation Policies** — check the payload against rules and verify that existing `override_preference` declarations have not been violated. Failures reject the request with a detailed reason. No field modification occurs.
3. **GateKeeper Policies** — apply hard overrides and blocks. May set `override_preference: immutable` on fields, permanently locking them against further modification. GateKeeper overrides record the policy UUID, the overridden value, the new value, the lock type, and the reason in provenance.

### Step 6 — Requested State Storage
The fully assembled, policy-processed payload is stored as the **Requested State** in the Request Store. This is the complete, provider-ready payload with full provenance chain intact.

### Step 7 — Provider Dispatch
The Requested State payload is dispatched to the appropriate Service Provider via the API Gateway.

---

## 7. Layer Assembly Diagram

```
Consumer Request
      │
      ▼
┌─────────────────┐
│  REQUEST LAYER  │  ← Consumer declared intent → stored as INTENT STATE
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│                  LAYER RESOLUTION                        │
│                                                          │
│  Base Layer          (lowest precedence)                 │
│       ↓                                                  │
│  Core Layers         (type-agnostic context)             │
│       ↓                                                  │
│  Intermediate Layers (organizational context)            │
│       ↓                                                  │
│  Service Layers      (type-scoped service config)        │
│       ↓                                                  │
│  Request Layer       (consumer intent — highest          │
│                       data layer precedence)             │
└────────┬────────────────────────────────────────────────┘
         │  Merged payload with full provenance
         ▼
┌─────────────────────────────────────────────────────────┐
│                  POLICY PROCESSING                       │
│                                                          │
│  Transformation Policies  (enrich / modify)              │
│       ↓                                                  │
│  Validation Policies      (pass / fail check)            │
│       ↓                                                  │
│  GateKeeper Policies      (override / block)             │
└────────┬────────────────────────────────────────────────┘
         │  Complete, validated, policy-processed payload
         ▼
┌─────────────────┐
│ REQUESTED STATE │  ← Stored in Request Store
└────────┬────────┘
         │
         ▼
   Service Provider
```

---

## 8. Layer Scope and Type Enforcement

### 8.1 Core Layer Scope Enforcement
Core Layers are type-agnostic by default. They are applied to every request regardless of Resource Type. A Core Layer that contains service-specific or provider-specific data is invalid and must be rejected.

### 8.2 Service Layer Scope Enforcement
Service Layers must declare a Resource Type scope. The Request Payload Processor enforces this during Layer Resolution:
- A Service Layer whose declared Resource Type does not match the request Resource Type is excluded from the merge
- A Service Layer with `scope_inheritance: exact` is only included if the request Resource Type exactly matches the declared type
- A Service Layer with `scope_inheritance: descendants` is included if the request Resource Type is the declared type or any descendant type in the inheritance hierarchy
- A Service Layer with no declared type scope is invalid and must be rejected

### 8.3 Unanticipated Data Interaction Prevention
The type scoping rules for Service Layers are the primary mechanism for preventing unanticipated data interactions — one of the core data model objectives. Because Service Layers can only contribute to requests of their declared type, data from one service domain cannot inadvertently affect requests in another service domain.

---

## 9. Layer Versioning

All layers follow the universal DCM versioning scheme: **Major.Minor.Revision**

| Component | Trigger |
|-----------|---------|
| **Major** | Breaking changes — removing fields, changing field types, changing a field from optional to required |
| **Minor** | Additive changes — adding new optional fields, adding new contextual data |
| **Revision** | Data/configuration changes — updating field values, updating descriptions, updating metadata |

**Immutability:** Once a layer version is published it cannot be modified. Any change produces a new version. Previous versions remain accessible and can be referenced by existing realized entities.

**Parent Chain Versioning:** A layer's parent chain references specific versions of parent layers. Updating a parent layer does not automatically update child layers — child layers must be explicitly updated to reference the new parent version, producing a new version of the child layer.

---

## 10. Artifact Lifecycle — The Five Statuses

All DCM artifacts — layers, policies, resource types, catalog items, and all other defined objects — follow a five-status lifecycle. The statuses are defined in Section 4b.2. For layers specifically:

| Status | Layer Behavior |
|--------|---------------|
| `developing` | Layer is in active development. Only usable in development mode pipelines. Not loaded by the assembly process in production. |
| `proposed` | Layer has been submitted for review (PR open). Not yet active. For policy layers: shadow execution runs. For data layers: layer is visible in the registry but not applied. Cannot merge to active until PR is approved. |
| `active` | Layer is current and applied in assembly. Can be included in new layer chains. |
| `deprecated` | Layer is being phased out. Existing chains using it continue to function. New chains should use the replacement. Deprecation warning recorded in assembly provenance. Must include replacement UUID, reason, migration guidance, and sunset date. |
| `retired` | Layer cannot be included in new layer chains. Existing realized entities that reference it retain the reference for audit purposes but cannot be used for new requests. |

**Status transition rules for layers:**
```
developing → proposed   (author submits PR)
developing → retired    (author abandons)
proposed   → active     (PR merged — approval complete)
proposed   → developing (PR returned for rework)
active     → deprecated (replacement available — sunset declared)
deprecated → retired    (sunset date reached or manual retirement)
```

---

## 11. Scale Example — 40,000 Linux VMs

This example illustrates the power of the layering model at scale. 40,000 distinct VM configurations are governed by 36 layer definitions:

```
Base Entity (3 variants)
├── CIS Benchmark
├── Baseline
└── DMZ / Payments

  └── Layer Entity — OS Family (3 variants per base = 9 total)
      ├── Common Linux Config / RHEL
      ├── Common Linux Config / CoreOS
      └── Common Linux Config / OEL

        └── Layer Entity — OS Version (4 variants per OS layer = 36 total)
            ├── RHEL 6
            ├── RHEL 7
            ├── RHEL 8
            └── RHEL 9

              └── Realized Entity — one per VM (40,000 total)
                  Each realized entity carries FK references to its
                  full layer chain (Base UUID + Layer UUIDs)
                  and is stored in the CMDB
```

**Result:** 3 × 3 × 4 = **36 layer definitions** govern **40,000 VM configurations**. Each VM's realized entity is a lightweight reference to its layer chain — not a copy of all the configuration data.

This also means:
- Updating the CIS Benchmark base layer creates one new layer version that cascades to all 40,000 VMs at their next realization
- Drift detection compares each VM's discovered state against its realized entity's layer chain
- Any VM can be reproduced exactly by replaying its layer chain through the assembly process

---

## 12. Relationship to the Four States

| Layer | State Relationship |
|-------|-------------------|
| Request Layer (as submitted) | Directly captured as **Intent State** — stored in Intent Store before any processing |
| Assembled payload (post-merge, pre-policy) | Intermediate — not a named state, internal to assembly process |
| Assembled payload (post-policy) | Becomes **Requested State** — stored in Request Store |
| Provider execution result | Becomes **Realized State** — stored in Realized Store |
| Discovery interrogation result | Becomes **Discovered State** — stored in Discovered Store |

The layer chain of a Realized Entity is always traceable — given a Realized State record, the complete layer chain that produced it can be reconstructed, providing full audit capability back to the original Base Layer.

---

## 13. Open Questions

| # | Question | Impact | Status |
|---|----------|--------|--------|
| 1 | How are conflicting Service Layers at the same precedence level resolved? | Assembly determinism | ✅ Resolved — priority schema + conflict detection at ingestion |
| 2 | Should Core Layers be ordered within their precedence level? | Merge determinism | ✅ Resolved — priority schema provides deterministic ordering |
| 3 | Can a consumer explicitly exclude a layer from their request? | Consumer control vs. standardization | ❓ Unresolved |
| 4 | How are Service Layers registered and versioned relative to Service Provider registration? | Provider contract | ❓ Unresolved |
| 5 | Should assembly support conditional layer inclusion? | Assembly flexibility | ❓ Unresolved |
| 6 | How does the layer chain interact with service dependencies? | Dependency model | ❓ Unresolved |
| 7 | Should `override_preference` be declarable in layer definitions as a hint to the Policy Engine? | Override control | ❓ Unresolved |
| 8 | When `override_preference: immutable` is set by a Global policy, can a higher-priority Global policy still override it? | Override control precedence | ❓ Unresolved |
| 9 | Should the `constraint_schema` on a constrained field be visible to consumers in the Service Catalog UI? | Consumer experience | ❓ Unresolved |
| 10 | Should the background validation job for detecting post-ingestion conflicts run on a schedule or be event-triggered? | Operational | ❓ Unresolved |
| 11 | What is the minimum validation review period for a proposed policy before it can be activated? | Policy governance | ❓ Unresolved |

---

## 14. Related Concepts

- **Request Payload Processor** — the control plane component that executes the assembly process; enforces structural layer rules
- **Policy Engine** — executes Policy Layers (Validation, Transformation, GateKeeper) during the assembly process; the sole authority for setting field override control
- **Field Override Control** — the mechanism governing who can change what field, under what conditions, at what policy level
- **Override Preference** — per-field metadata declaring `allow`, `constrained`, or `immutable` — the formalization of the original data model "override preference" subtag
- **Service Layer Cache** — caches Service Layer data at Service Provider registration time for efficient retrieval during assembly
- **Core Layer Store** — stores all Core Layer definitions
- **Intent State** — the Request Layer as submitted, before assembly
- **Requested State** — the fully assembled, policy-processed payload
- **Field-Level Provenance** — every field in the assembled payload records which layer set it and which policy modified it
- **Resource Type Hierarchy** — defines the type scope that Service Layers must declare and that the assembly process enforces
- **GitOps** — all layers are stored in Git, versioned and immutable

---

*Document maintained by the DCM Project. For questions or contributions see [GitHub](https://github.com/dcm-project).*
