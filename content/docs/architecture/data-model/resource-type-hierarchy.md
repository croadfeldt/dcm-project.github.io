---
title: "Resource Type Hierarchy and Service Catalog"
type: docs
weight: 5
---

> **⚠️ Active Development Notice**
> 
> The DCM data model and architecture documentation are actively being developed. Concepts, structures, and specifications documented here represent work in progress and are subject to change as design decisions are finalized. Open questions are explicitly tracked and decisions are recorded as they are made.
> 
> Contributions, feedback, and discussion are welcome via [GitHub](https://github.com/dcm-project).


**Document Status:** 🔄 In Progress  
**Related Documents:** [Context and Purpose](00-context-and-purpose.md) | [Entity Types](01-entity-types.md) | [Four States](02-four-states.md) | [Layering and Versioning](03-layering-and-versioning.md) | [Examples](04-examples.md)

---

## 1. Purpose

The DCM Resource Type Hierarchy is the structural model that defines how services and resources are categorized, specified, and exposed through the DCM Service Catalog. It is the mechanism by which DCM achieves **resource portability** — the ability to express what a consumer needs independently of which specific provider delivers it.

The hierarchy serves four goals:

1. **Portability** — consumer intent can be fulfilled by any provider that satisfies the resource type contract, without the consumer needing to know which provider that is
2. **Standardization** — a common vocabulary and data contract for all resource types encourages interoperability across providers, implementors, and the broader DCM community
3. **Extensibility** — the model can be extended at every level without breaking existing definitions
4. **Transparency** — any deviation from full portability is explicitly declared, versioned, and surfaced to consumers

---


### 1a. Precise Vocabulary — Resource Type vs Catalog Item

These terms are frequently conflated. The distinction is architectural:

**Resource Type** — the classification category. Groups catalog items for portability and discovery. Vendor-neutral by requirement. Defines the field schema that any provider offering this type must support. Examples: `Compute.VirtualMachine`, `Network.IPAddress`, `Process.AnsiblePlaybook`.

**Resource Type Specification** — the versioned, formal definition of a Resource Type: field schema, constraints, lifecycle rules, portability classification, and allowed relationship types. Stored in the Resource Type Registry. Providers implement against a specific version. Example: `Compute.VirtualMachine v2.1.0`.

**Provider Catalog Item** — what a specific Service Provider is offering to consumers. The provider's declaration: "I can fulfill `Compute.VirtualMachine v2.1.0` with these specific options, at this cost, with these availability characteristics, in this region." A catalog item is always linked to a specific Resource Type Specification version. Catalog items can represent resource allocations (a VM, a subnet) or processes (an automation job, a playbook execution, a pipeline run) — anything a provider offers for consumption.

**The key relationship:** Consumers request by Resource Type (or Resource Type Specification version). DCM resolves to a Provider Catalog Item through the specificity narrowing algorithm. The catalog item is what actually gets provisioned. The resource type is the portable, vendor-neutral expression of intent.

**Anti-vocabulary update:** Never say "catalog item" when you mean "resource type specification." Never say "resource type" when you mean a specific provider offering — use "catalog item" or "provider catalog item."


## 2. The DCM Resource Type Registry

DCM maintains an official **Resource Type Registry** — the authoritative source of standard resource type definitions. The registry is the foundation of portability across the DCM ecosystem.


### 2.1a Catalog Item vs Resource Type Specification — Critical Distinction

These two terms are frequently conflated throughout the documentation. They are distinct concepts at different levels of the hierarchy:

**Resource Type Specification (Registry entry):**
- Vendor-neutral definition of a resource type's fields, constraints, lifecycle rules, and portability classification
- Lives in the Resource Type Registry (Tier 1, 2, or 3)
- Examples: `Compute.VirtualMachine v2.1.0`, `Network.VLAN v1.0.0`
- Defines what the resource TYPE is, not what any specific provider offers

**Provider Catalog Item (Service Catalog entry):**
- A specific provider's offering implementing a Resource Type Specification
- Includes provider-specific pricing, availability, SLAs, and performance characteristics
- What consumers actually request via the Service Catalog
- Examples: "EU-WEST-Prod-1's 4-CPU VM offering", "NetworkOps's VLAN service"
- Tied to a specific provider; multiple providers can offer catalog items for the same Resource Type Spec

**When to use each term:**
- "The consumer requests a catalog item" ✓ — they request a provider's specific offering
- "The resource type specification defines the field schema" ✓ — the spec defines structure
- "The catalog item schema" ✗ — should be "the resource type specification schema"
- "The consumer browses resource types" ✓ — they browse the type hierarchy
- "The consumer selects a catalog item" ✓ — they select a specific provider offering

**In the anti-vocabulary:** "Catalog Item" should not be used when "Resource Type Specification" is meant, and vice versa. The hierarchy is: Resource Type Category → Resource Type → Resource Type Specification → Provider Catalog Item.


### 2.1 Registry Principles

- The registry is **open** — third parties, implementors, and the community can propose new resource type definitions
- Registry entries are **versioned and immutable** once published — changes produce new versions
- Registry definitions are **vendor-neutral by hard requirement** — no vendor-specific data is permitted in a DCM-specified resource type unless that vendor is the exclusive provider of that technology stack
- The registry itself is subject to the same **deprecation model** as all other DCM definitions
- All registry entries follow the **universal versioning scheme** (Major.Minor.Revision)

### 2.2 Default Resource Type Categories

DCM ships with a default set of Resource Type Categories. Implementors may define additional categories following the specification. The registry contains both **Resource Types** (for provisioned resources) and **Information Types** (for external data references) — distinguished by category prefix.

**Resource Type Categories:**

| Category | Description |
|----------|-------------|
| `Compute` | Processing resources — virtual machines, containers, bare metal |
| `Network` | Networking resources — IP addresses, VLANs, firewall rules, load balancers |
| `Storage` | Storage resources — block, object, file, databases |
| `Platform` | Platform services — Kubernetes clusters, application platforms |
| `Security` | Security resources — certificates, secrets, HSMs, identity |
| `Observability` | Monitoring and logging resources |
| `Data` | Data services — streams, queues, pipelines |

**Information Type Categories:**

| Category | Description |
|----------|-------------|
| `Business` | Business organizational data — BusinessUnit, CostCenter, ProductOwner |
| `Identity` | Identity and access data — Person, ServiceAccount, Group |
| `Compliance` | Regulatory and compliance data — RegulatoryScope, AuditFramework |
| `Operations` | Operational reference data — Runbook, SLA, SupportContract |

All categories follow the same versioning, deprecation, and registry governance model. The `implements_type` field on provider registrations distinguishes whether a provider is a Service Provider (`service`) or an Information Provider (`information`).

### 2.3 Registry Entry Structure

Every entry in the Resource Type Registry carries the following metadata:

```yaml
registry_entry:
  uuid: <uuid>
  name: <human-readable name>
  fully_qualified_name: <Category.ResourceType>
  version: <Major.Minor.Revision>
  parent_uuid: <uuid of parent type, null for root categories>
  status:
    state: <active|deprecated|retired>
    deprecation_date: <ISO 8601 date, if applicable>
    sunset_date: <ISO 8601 date after which retired, if applicable>
    replacement_uuid: <uuid of replacement definition, if deprecated>
    replacement_version: <version of replacement definition, if deprecated>
    deprecation_reason: <human-readable explanation, if deprecated>
    migration_guidance: <how to transition to replacement, if deprecated>
  portability:
    classification: <universal|conditional|provider-specific|exclusive>
    portability_breaking: <true|false>
    portability_notes: <human-readable explanation of any portability limitations>
  ownership:
    owner: <DCM|community|implementor|provider>
    owner_uuid: <uuid of owning entity>
    origination_date: <ISO 8601 timestamp>
  description: <human-readable description>
  specification_ref: <reference to the full type specification document>
```

---

## 3. Resource Type Hierarchy Levels

The hierarchy has four levels, from most abstract to most concrete. Each level builds on the one above it.

### Level 1 — Resource Type Category

The broadest classification. Defines the domain of a resource without any specificity about what the resource is.

- DCM ships with default categories (see Section 2.2)
- Implementors may define additional categories
- Categories have no data fields — they are organizational containers
- Categories are versioned and can be deprecated

**Example:** `Compute`, `Network`, `Storage`

---

### Level 2 — Resource Type

Defines an abstract resource within a category. A Resource Type represents a class of resource that multiple providers can implement. Resource Types are the primary unit of portability in DCM.

- DCM maintains default Resource Types in the registry
- Community and implementors can define and register new Resource Types
- Resource Types must be **vendor-neutral** — no provider-specific data
- Resource Types declare their **base field specification** (universal fields only)
- Resource Types are versioned and can be deprecated

**Example:** `Compute.VirtualMachine`, `Network.IPAddress`, `Network.FirewallRule`

---

### Level 3 — Resource Type Specification

The data contract for a Resource Type. Defines all fields — universal, conditional, and any declared extension points — along with their types, constraints, and portability classifications.

- Every field in a specification carries a **portability classification** (see Section 4)
- Specifications define which fields are required vs. optional
- Specifications define validation constraints for each field
- Specifications declare **extension points** where providers may add fields
- Specifications are versioned independently of their Resource Type
- Specifications can be deprecated

**Example:** `Compute.VirtualMachine` specification defines: `cpu_count` (universal, required), `ram_gb` (universal, required), `storage_gb` (universal, required), `os_image` (universal, required), `high_availability` (conditional, optional)

---

### Level 4 — Provider Catalog Item

A specific provider's concrete implementation of a Resource Type Specification. This is where provider-specific detail lives and where the abstract becomes actionable.

- Provider Catalog Items are registered against a specific Resource Type Specification version
- They must implement **all universal fields** of the parent specification
- They may implement **conditional fields** (declared in their registration)
- They may add **provider-specific extension fields** (must be marked portability-breaking)
- They are versioned and can be deprecated
- They declare their **sovereignty capabilities** (see Section 6)
- They declare their **supported lifecycle operations** (see Section 7)

**Example:** `Nutanix.VM.Small` implements `Compute.VirtualMachine` with `cpu_count: 4`, `ram_gb: 16`, `storage_gb: 60`

---

## 4. Portability Classification

Every field in every Resource Type Specification carries a portability classification. This classification is part of the field's metadata and is immutable once published for a given version.

### 4.1 Classification Levels

| Classification | Description | Portability Impact |
|---|---|---|
| `universal` | Part of the DCM standard spec. All providers implementing this type must support it. | Fully portable across all implementing providers |
| `conditional` | Supported by multiple providers but not all. Providers declare support in their registration. | Portable across providers that declare support |
| `provider-specific` | Specific to one provider or technology stack. Using this field locks the request to that provider. | Portability-breaking — must be explicitly marked |
| `exclusive` | Only one provider supports this technology stack. Portability is not applicable by definition. | Not applicable — acknowledged and declared |

### 4.2 Hard Portability Requirements

The following are non-negotiable requirements for any DCM-specified Resource Type:

1. All **universal** fields MUST be supported by ALL providers implementing that Resource Type
2. **Provider-specific** fields MUST be explicitly marked as portability-breaking in the field metadata
3. Consumers MUST be warned when their request contains portability-breaking fields
4. The only exception to vendor-neutrality is the **exclusive** classification — where one provider is the sole implementor of a technology stack, explicitly acknowledged and declared in the registry
5. Any Resource Type in the DCM registry that contains provider-specific fields as universal fields is invalid and must be rejected

### 4.3 Portability Field Metadata

Every field in a Resource Type Specification carries the following portability metadata:

```yaml
field_name:
  type: <string|integer|boolean|enum|uuid|object|list>
  required: <true|false>
  description: <human-readable description>
  portability:
    classification: <universal|conditional|provider-specific|exclusive>
    portability_breaking: <true|false>
    portability_notes: <human-readable explanation>
    supported_by: <all|list of provider UUIDs — for conditional fields>
  constraints:
    - <constraint definition>
  default_value: <default if not specified>
  provenance:
    <standard provenance metadata — see context-and-purpose.md>
```

---

## 5. Inheritance Model

Resource Types support inheritance, enabling specialization without duplication. A child type inherits all fields from its parent and may add new fields.

### 5.1 Inheritance Rules

1. A child type inherits **all fields** from its parent type — no field can be removed or redefined
2. A child type may **add new fields** beyond its parent's specification
3. A child type's portability classification can only be **equal to or more restrictive** than its parent — a child of a `universal` type may be `conditional`, but not vice versa
4. Each level of the hierarchy is **independently versioned**
5. Each level maintains a **reference to its parent UUID and version**
6. Deprecating a parent type **does not automatically deprecate child types** — each must be independently deprecated with appropriate migration guidance

### 5.2 Inheritance Example

```
Compute                                        # Category
  └── VirtualMachine                           # Base Resource Type
        ├── VirtualMachine.GPU                 # Inherits VirtualMachine
        │     ├── gpu_count (conditional)
        │     ├── gpu_memory_gb (conditional)
        │     └── VirtualMachine.GPU.HighMemory  # Inherits VirtualMachine.GPU
        │           └── extended_memory_gb (conditional)
        └── VirtualMachine.HighAvailability    # Inherits VirtualMachine
              ├── ha_mode (conditional)
              └── failover_policy (conditional)
```

### 5.3 Inheritance Metadata

Every Resource Type that inherits from a parent carries the following inheritance metadata:

```yaml
inheritance:
  parent_uuid: <uuid of parent type>
  parent_version: <version of parent type this inherits from>
  parent_fully_qualified_name: <Category.ParentType>
  inherited_fields: <list of field names inherited — for documentation>
  added_fields: <list of field names added by this type>
```

---

## 6. Provider Registration and Catalog Item Declaration

For a provider to participate in the DCM ecosystem and have its catalog items available for request resolution, it must register against the Resource Type Hierarchy.

### 6.1 Provider Registration Declaration

A provider's registration is a machine-readable declaration that DCM consumes to understand what the provider offers and how to route requests to it:

```yaml
provider_registration:
  uuid: <provider uuid>
  name: <provider name>
  version: <Major.Minor.Revision>
  status:
    state: <active|deprecated|retired>
    deprecation_date: <if applicable>
    sunset_date: <if applicable>
    replacement_uuid: <if deprecated>
    deprecation_reason: <if deprecated>
    migration_guidance: <if deprecated>
  catalog_items:
    - <list of catalog item declarations>
  sovereignty_capabilities:
    <see sovereignty contract — provider-contract.md>
  supported_lifecycle_operations:
    <see lifecycle contract — provider-contract.md>
  trust_declaration:
    <see trust contract — provider-contract.md>
```

### 6.2 Catalog Item Declaration

Each catalog item a provider offers is declared against a specific Resource Type Specification version:

```yaml
catalog_item:
  uuid: <uuid>
  name: <human-readable name>
  version: <Major.Minor.Revision>
  implements:
    resource_type_uuid: <uuid of Resource Type being implemented>
    resource_type_version: <version of specification this implements>
    resource_type_fully_qualified_name: <Category.ResourceType>
  status:
    state: <active|deprecated|retired>
    deprecation_date: <if applicable>
    sunset_date: <if applicable>
    replacement_uuid: <if deprecated>
    deprecation_reason: <if deprecated>
    migration_guidance: <if deprecated>
  universal_fields:
    <implementation of all universal fields from parent specification>
  conditional_fields_supported:
    <list of conditional field names this provider supports>
  provider_specific_extensions:
    <additional fields beyond the base specification>
    <each field must be marked portability_breaking: true>
  portability_warning: <true|false — true if any provider-specific extensions are present>
```

---

## 7. Request Resolution — Specificity Narrowing

Provider selection in DCM is never explicit. The consumer declares intent using Resource Types and field values. The appropriate provider catalog item is selected by the DCM Policy Engine through progressive specificity narrowing.

### 7.1 Resolution Steps

```
Step 1: Resource Type declared
        → matches all providers implementing that Resource Type

Step 2: Universal fields specified
        → still matches all providers (all must support universal fields)

Step 3: Conditional fields specified
        → narrows to providers that declare support for those fields

Step 4: Provider-specific fields used
        → narrows to single provider
        → portability warning issued and recorded in request provenance
        → enforcement mode applied (block|warn|allow) per organizational policy

Step 5: Placement and sovereignty constraints applied
        → Policy Engine applies placement policies
        → Provider sovereignty capabilities matched against request requirements
        → Final provider catalog item selected

Step 6: Provider catalog item UUID recorded in request payload provenance
```

### 7.2 Portability Warning Enforcement

When a request contains portability-breaking fields, the Policy Engine applies the configured enforcement mode. This is organizational policy — configurable at the organization, domain, or service level:

| Enforcement Mode | Behavior |
|---|---|
| `block` | Request is rejected. Consumer must remove portability-breaking fields or explicitly acknowledge the lock-in. |
| `warn` | Request proceeds. Portability warning is recorded in request provenance and surfaced to the consumer. |
| `allow` | Request proceeds silently. Portability-breaking fields are still recorded in provenance but no warning is surfaced. |

The enforcement mode is itself a versioned, auditable policy — subject to the same provenance tracking as all other data in DCM.

---

## 8. Deprecation Model

Every definition at every level of the Resource Type Hierarchy can be deprecated. Deprecation is a first-class concept in DCM — not an afterthought.

### 8.1 Deprecation Lifecycle

```
active → deprecated → retired
```

| State | Meaning | System Behavior |
|---|---|---|
| `active` | Definition is current and fully supported | Normal operation |
| `deprecated` | Definition is being phased out. Replacement is available. | Deprecation warning surfaced to consumers. Requests still processed. Warning recorded in provenance. |
| `retired` | Definition is no longer honored. | Requests using retired definitions are rejected by the Policy Engine. |

### 8.2 Deprecation Cascade Rules

- Deprecating a **Resource Type** does not automatically deprecate its child types or provider catalog items — each must be independently deprecated
- Deprecating a **Provider Catalog Item** does not affect other catalog items implementing the same Resource Type
- Retiring a **Resource Type Specification version** causes all catalog items registered against that version to require re-registration against a current version
- **Sunset dates** must provide sufficient migration runway — minimum notice periods may be defined by organizational policy

### 8.3 Migration Guidance Requirement

Any definition marked `deprecated` MUST include:
- A reference to the replacement definition (UUID and version)
- A human-readable deprecation reason
- Human-readable migration guidance explaining how to transition
- A sunset date giving consumers time to migrate

---

## 9. Versioning

All definitions in the Resource Type Hierarchy follow the universal DCM versioning scheme.

### 9.1 Version Scheme

`Major.Minor.Revision`

| Component | Trigger |
|---|---|
| **Major** | Breaking changes to the contract — removing fields, changing field types, changing required/optional status of universal fields |
| **Minor** | Additive changes, backward compatible — adding new optional fields, adding new conditional fields, adding new extension points |
| **Revision** | Data or configuration changes with no contract impact — updating descriptions, updating constraints that don't break existing data, updating metadata |

### 9.2 Version Constraints in Requests

Consumers and dependencies may declare version constraints in their requests:

```yaml
resource_type:
  uuid: <uuid>
  version_constraint: <exact|minimum|range>
  version: <version or version range>
```

### 9.3 Version Immutability

Once a version is published it is immutable. Any change — even a documentation correction — produces a new version. This applies to all definitions at all levels of the hierarchy.

---

## 10. Open Questions

| # | Question | Impact | Status |
|---|----------|--------|--------|
| 1 | What is the governance model for proposing and approving new Resource Types to the DCM registry? | Community adoption, quality control | ✅ Resolved — three-tier registry (DCM Core / Verified Community / Organization); PR-based proposals with automated validation gates; shadow validation period before active promotion; see doc 20 (REG-001, REG-002) |
| 2 | Should the registry support a formal review/approval workflow before a Resource Type becomes `active`? | Registry integrity, community trust | ✅ Resolved — PR-based workflow with automated gates (schema, FQN conflict, dependency resolution) and mandatory shadow validation before active; review periods by change type; see doc 20 (REG-002) |
| 3 | What is the minimum sunset period for deprecated definitions? | Migration planning, operational stability | ✅ Resolved — default sunset policies REG-DP-002: Tier 1=P12M, Tier 2=P6M; overridable via standard policy priority; locked as immutable in fsi/sovereign profiles; see doc 20 |
| 4 | Should version constraints in requests be strictly enforced or advisory? | Operational flexibility vs. predictability | ✅ Resolved — strictly enforced; version_policy options: exact/compatible/latest_minor/latest; DCM never auto-upgrades across major versions; profile-governed defaults (fsi/sovereign=exact); see doc 20 (REG-004) |
| 5 | How are conflicts resolved when multiple providers satisfy all narrowing criteria equally? | Request resolution determinism | ✅ Resolved — six-step tie-breaking: policy preference → provider priority → tenant affinity → cost analysis (if available) → least loaded → consistent hash on request_uuid; see doc 20 (REG-005) |
| 6 | Should the registry be distributed or centralized? How does this interact with sovereignty requirements? | Registry availability, sovereignty | ✅ Resolved — federated model: DCM Project registry → Organization mirror → Sovereign DCM (offline/signed bundles); air-gap via signed bundle import; see doc 20 (REG-006) |

---

## 11. Related Concepts

- **Portability** — the ability to fulfill a resource intent using any provider that satisfies the resource type contract
- **Naturalization** — provider's responsibility to transform DCM unified data into provider-specific format
- **Denaturalization** — provider's responsibility to transform provider-specific results back into DCM unified format
- **Sovereign Execution Posture** — sovereignty capabilities declared in provider registration inform placement decisions
- **Policy Engine** — applies portability enforcement, placement policies, and request resolution logic
- **Field-Level Provenance** — every field modification during request resolution is recorded with source UUID and operation type
- **Universal Versioning** — Major.Minor.Revision applies to all definitions at all levels of the hierarchy
- **Deprecation** — universal model for phasing out definitions at any level with migration guidance

---

*Document maintained by the DCM Project. For questions or contributions see [GitHub](https://github.com/dcm-project).*
