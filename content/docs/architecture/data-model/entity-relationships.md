---
title: "Entity Relationships"
type: docs
weight: 8
---

> **⚠️ Active Development Notice**
> 
> The DCM data model and architecture documentation are actively being developed. Concepts, structures, and specifications documented here represent work in progress and are subject to change as design decisions are finalized. Open questions are explicitly tracked and decisions are recorded as they are made.
> 
> Contributions, feedback, and discussion are welcome via [GitHub](https://github.com/dcm-project).


**Document Status:** 🔄 In Progress  
**Related Documents:** [Context and Purpose](../context-and-purpose/) | [Resource Type Hierarchy](../resource-type-hierarchy/) | [Resource/Service Entities](../resource-service-entities/) | [Service Dependencies](../service-dependencies/) | [Resource Grouping](../resource-grouping/) | [Information Providers](../information-providers/)

---

## 1. Purpose

The DCM Entity Relationship model is the **universal mechanism for expressing relationships between any two entities in DCM** — whether between two Resource/Service Entities, between an entity and external business data, or between entities at the service definition level.

A single relationship model is used everywhere. There is no separate binding mechanism for storage, no separate dependency graph structure, no separate business data association mechanism. One model serves all relationship types across the full lifecycle — from pre-realization planning through to post-realization management, drift detection, cost rollup, and rehydration.

This document supersedes the dependency graph concept from the Service Dependencies document for data structure purposes. The Service Dependencies document retains content on rehydration ordering and failure handling, which operate on the relationship graph defined here.

---

## 2. Design Principle

**Single model. Minimum variance. Simple by default.**

The worst outcome is a data model with different mechanisms for expressing similar concepts. Every relationship in DCM — whether a VM requires storage, an application contains a web server, or a resource references a Business Unit — is expressed using the same structure. The only things that vary are the relationship type, role, and nature — all of which are declared fields, not structural differences.

---

## 3. The Universal Relationship Structure

Every relationship is a first-class data object with its own UUID. It is recorded **bidirectionally** — on both participating entities. The same `relationship_uuid` appears on both sides, identifying the relationship itself.

### 3.1 Relationship Record Structure

```yaml
relationship:
  relationship_uuid: <uuid — same on both sides of the relationship>
  
  # This entity's perspective
  this_entity_uuid: <uuid of the entity carrying this relationship record>
  this_role: <role this entity plays in the relationship>
  
  # The related entity
  related_entity_uuid: <uuid of the related entity>
  related_entity_type: <internal|external>
  related_entity_role: <role the related entity plays>
  
  # For external entities only
  information_provider_uuid: <uuid of Information Provider — if external>
  information_type: <e.g., Business.BusinessUnit — if external>
  lookup_method: <primary_key|fallback — how to resolve the external reference>
  
  # Relationship semantics
  relationship_type: <see Section 4>
  nature: <constituent|operational|informational>
  
  # Lifecycle policy — for constituent and operational relationships only
  lifecycle_policy:
    on_related_destroy: <destroy|retain|detach|notify>
    on_related_suspend: <suspend|retain|detach|notify>
    on_related_modify: <cascade|ignore|notify>
  
  # Metadata
  version: <Major.Minor.Revision>
  status: <active|suspended|terminated>
  created_timestamp: <ISO 8601>
  created_by_uuid: <uuid of entity or process that created this relationship>
  
  provenance:
    <standard field-level provenance>
```

### 3.2 Bidirectional Recording

Every relationship is recorded on both participating entities. The `relationship_uuid` is identical on both sides — it identifies the relationship itself, not one side of it.

**Example — VM requires Storage:**

```yaml
# On the VM Entity
relationships:
  - relationship_uuid: "rel-uuid-001"
    this_entity_uuid: "vm-uuid-001"
    this_role: compute
    related_entity_uuid: "storage-uuid-001"
    related_entity_type: internal
    related_entity_role: storage
    relationship_type: requires
    nature: constituent
    lifecycle_policy:
      on_related_destroy: destroy
      on_related_suspend: suspend
      on_related_modify: notify

# On the Storage Entity
relationships:
  - relationship_uuid: "rel-uuid-001"
    this_entity_uuid: "storage-uuid-001"
    this_role: storage
    related_entity_uuid: "vm-uuid-001"
    related_entity_type: internal
    related_entity_role: compute
    relationship_type: required_by
    nature: constituent
    lifecycle_policy:
      on_related_destroy: destroy
      on_related_suspend: suspend
      on_related_modify: notify
```

---

## 4. Relationship Types

Relationship types form a fixed standard vocabulary. Every type has an inverse — when you record the relationship on both entities, the type is expressed from each entity's perspective.

| Type | Inverse | Meaning |
|------|---------|---------|
| `requires` | `required_by` | This entity cannot function without the related entity |
| `depends_on` | `dependency_of` | This entity uses the related entity but can degrade without it |
| `contains` | `contained_by` | This entity is a logical container for the related entity |
| `references` | `referenced_by` | This entity references the related entity without owning or requiring it |
| `peer` | `peer` | Equal relationship — neither owns, requires, or contains the other |
| `manages` | `managed_by` | This entity has lifecycle management authority over the related entity |

---

## 5. Relationship Roles

Roles describe the **function** a related entity serves in a relationship. They are semantic labels that carry meaning for humans and for policy evaluation — they do not affect system behavior directly.

### 5.1 Standard Roles (DCM-defined)

| Role | Description |
|------|-------------|
| `compute` | Processing resource — VM, container, bare metal |
| `storage` | Storage resource — block, object, file |
| `networking` | Network resource — IP, VLAN, subnet, port |
| `security` | Security resource — firewall rule, certificate, HSM |
| `database` | Database resource — relational, NoSQL, time-series |
| `web` | Web tier resource — web server, reverse proxy, CDN |
| `app` | Application tier resource — app server, runtime |
| `cache` | Caching resource — in-memory cache, CDN layer |
| `queue` | Messaging resource — message queue, event stream |
| `pipeline` | Pipeline resource — CI/CD, data pipeline |
| `identity` | Identity resource — service account, credential |
| `monitoring` | Monitoring resource — metrics, logging, alerting |
| `business_unit` | Business Unit association |
| `cost_center` | Cost Center association |
| `product_owner` | Product Owner association |
| `regulatory_scope` | Regulatory or compliance scope association |

### 5.2 Custom Roles (extensible)

Organizations register custom roles for domain-specific relationship semantics. Custom roles are semantic labels only — they do not change system behavior. DCM core ignores unknown custom roles in operational decisions but carries them in payloads for downstream consumers.

```yaml
custom_role_registration:
  uuid: <uuid>
  name: <role name — e.g., trading_engine>
  description: <description>
  registered_by_tenant_uuid: <uuid — or null for global>
  category: <domain context — e.g., financial_services>
  version: <Major.Minor.Revision>
  status: <active|deprecated|retired>
```

---

## 6. Relationship Nature

Nature describes the **structural character** of a relationship — what it means for the entities involved.

| Nature | Meaning | Lifecycle Policy | Example |
|--------|---------|-----------------|---------|
| `constituent` | The related entity is a required component of this entity's definition | Required — declared on relationship | VM requires its boot disk |
| `operational` | The related entity is needed for operation but is not part of the definition | Required — declared on relationship | Web server depends on load balancer |
| `informational` | The related entity provides context or reference only — no operational dependency | Not applicable | Resource references its Business Unit |

---

## 7. Lifecycle Policies

Lifecycle policies declare what happens to an entity when its related entity changes state. They apply to `constituent` and `operational` relationships only — `informational` relationships have no lifecycle implications.

### 7.1 Policy Actions

| Action | Meaning |
|--------|---------|
| `destroy` | Destroy this entity when the related entity is destroyed |
| `retain` | Keep this entity when the related entity is destroyed — it becomes independent |
| `detach` | Detach this entity from the relationship — relationship terminated, entity retained |
| `notify` | Notify appropriate personas and trigger Policy Engine evaluation — no automatic action |
| `suspend` | Suspend this entity when the related entity is suspended |
| `cascade` | Cascade the change from the related entity to this entity |
| `ignore` | Take no action — the change to the related entity does not affect this entity |

### 7.2 Lifecycle Policy Authority Hierarchy

Lifecycle policies follow the same three-tier authority model as override control:

```
Resource Type Specification default (lowest — portable default)
  │
  ▼
Provider Catalog Item default (provider preference)
  │
  ▼
Consumer declaration (at request time — within Resource Type bounds)
  │
  ▼
DCM System Policy (non-overridable — sovereignty and compliance mandates)
```

**Example:** A DCM System Policy might declare that all storage entities in a PCI-DSS scope must `retain` when their parent VM is destroyed — regardless of what the provider default or consumer declared.

---

## 8. Relationship Declarations — Where They Live

Relationship declarations exist at multiple levels, each building on the previous:

### 8.1 Resource Type Specification (structural ceiling)

Declares what relationships are **possible** for a resource type. Sets the ceiling — lower levels can only declare relationships within these bounds.

```yaml
resource_type: Compute.VirtualMachine
possible_relationships:
  - role: storage
    relationship_type: requires
    nature: constituent
    permitted_related_types:
      - Storage.Block
      - Storage.File
    default_lifecycle_policy:
      on_related_destroy: destroy
      on_related_suspend: suspend
    binding_types_permitted: [owned, referenced]
    consumer_declarable: true
    # Consumer can declare binding_type and lifecycle_policy override

  - role: networking
    relationship_type: requires
    nature: constituent
    permitted_related_types:
      - Network.IPAddress
    default_lifecycle_policy:
      on_related_destroy: destroy
    consumer_declarable: false
    # DCM manages this automatically — consumer cannot override
```

### 8.2 Catalog Item (offering-specific)

Declares the **actual relationships** for a specific curated offering. Can only be more restrictive than the Resource Type Specification.

```yaml
catalog_item: Production VM
relationships:
  - role: storage
    relationship_type: requires
    nature: constituent
    related_catalog_item_uuid: <uuid of Standard Block Storage catalog item>
    lifecycle_policy:
      on_related_destroy: retain
      # Overrides Resource Type default of destroy
      # Storage persists even if VM is destroyed — production data protection
    binding_type: owned
```

### 8.3 Request Time (consumer-declared)

The consumer declares relationships in their request. Bundled declarations (storage fields within a VM request) are automatically expanded into relationship records by the Request Payload Processor.

```yaml
# Explicit relationship declaration in a request
request:
  resource_type: Compute.VirtualMachine
  # ... other fields ...
  relationships:
    - role: storage
      relationship_type: requires
      binding_type: referenced
      related_entity_uuid: <uuid of existing Storage Entity>
      # Consumer referencing existing storage — not creating new

# Bundled declaration — expanded automatically
request:
  resource_type: Compute.VirtualMachine
  storage:
    disks:
      - name: boot
        capacity: 100GB
        # Processor expands this into a Storage Entity stub
        # and a relationship record with binding_type: owned
```

### 8.4 External Data Relationships

Relationships to external data entities follow the same structure with `related_entity_type: external`:

```yaml
# On a VM Entity — relationship to external Business Unit
relationships:
  - relationship_uuid: <uuid>
    this_entity_uuid: <vm-uuid>
    this_role: <consumer>
    related_entity_uuid: <uuid of external_entity_reference>
    related_entity_type: external
    information_provider_uuid: <uuid of HR Information Provider>
    information_type: Business.BusinessUnit
    relationship_type: references
    role: business_unit
    nature: informational
    lookup_method: primary_key
```

---

## 9. Bundled Declaration Expansion

When a consumer includes resource configuration as bundled fields (e.g., storage within a VM request), the Request Payload Processor expands these into first-class entities and relationship records.

### 9.1 Expansion Process

```
Consumer submits bundled VM request with storage fields
  │
  ▼
Request Payload Processor
  │  Reads expansion rules from Resource Type Specification
  │  For each expandable field:
  │    1. Creates a Resource/Service Entity stub (PENDING state)
  │       with its own UUID, Tenant membership, Resource Type
  │    2. Creates a Relationship record on both the parent stub
  │       and the child stub
  │    3. Applies lifecycle policy from:
  │       consumer declaration → provider default → Resource Type default
  │       → DCM System Policy override
  │    4. Adds the child entity stub to the relationship graph
  ▼
Policy Engine validates:
  │  Binding type is permitted by Resource Type Specification
  │  Consumer has override_matrix permission to declare binding type
  │  Lifecycle policy is not overridden by a DCM System Policy
  ▼
Service Provider receives:
  │  Parent entity request payload
  │  Child entity stub UUIDs embedded in parent payload
  │  Provisions resources natively
  │  Returns realized payloads for all entities in DCM unified format
  ▼
DCM updates:
  │  Parent entity: PENDING → REALIZED
  │  Child entities: PENDING → REALIZED
  │  All relationship records: status → active
  │  Full provenance recorded on all entities and relationships
```

### 9.2 Expansion Rules in Resource Type Specification

The expansion rule declares which fields expand into entities and how:

```yaml
field_definition:
  field_name: storage
  type: object
  expansion:
    expand_to_entity: true
    entity_resource_type_uuid: <uuid of Storage.Block>
    entity_resource_type_name: Storage.Block
    default_binding_type: owned
    binding_types_permitted: [owned, referenced]
    default_lifecycle_policy:
      on_related_destroy: destroy
      on_related_suspend: suspend
    consumer_can_override_lifecycle: true
    consumer_can_override_binding_type: true
```

---

## 10. The Entity Relationship Graph

All relationships across all entities form a traversable **Entity Relationship Graph** — the complete map of how all entities in DCM relate to each other.

### 10.1 Graph Properties

- Every node is a Resource/Service Entity (internal or external reference)
- Every edge is a Relationship with a UUID
- The graph is bidirectional — traversable from any node in any direction
- Every node exists exactly once — shared entities appear once with multiple relationship edges
- Circular relationships are invalid and must be rejected

### 10.2 Graph and the Four States

The relationship graph exists across all four states:

| State | Graph Role |
|-------|-----------|
| Intent State | Graph declared at request time — nodes are intent stubs |
| Requested State | Graph fully assembled — nodes are PENDING entity stubs with UUIDs |
| Realized State | Graph populated — nodes are REALIZED entities with full provenance |
| Discovered State | Graph used for comparison — discovered entities matched against realized graph |

### 10.3 Graph Applications

| Application | How the Graph is Used |
|-------------|----------------------|
| **Rehydration** | Full graph traversal from a root entity — all related entities identified and realized in dependency order |
| **Cost Rollup** | Graph traversal accumulates costs across all related constituent entities |
| **Drift Detection** | Discovered State graph compared against Realized State graph — structural and data differences identified |
| **Decommission** | Graph traversal determines decommission order — lifecycle policies applied at each edge |
| **Placement** | Pre-realization graph used to understand full resource footprint for placement decisions |
| **Impact Analysis** | Graph traversal from any node identifies all entities affected by a change |

---

## 11. Relationship Integrity

### 11.1 DCM System Policies for Relationships

| Policy | Rule |
|--------|------|
| `REL-001` | Every relationship must have a UUID |
| `REL-002` | Every relationship must be recorded on both participating entities |
| `REL-003` | Circular relationships are invalid and must be rejected |
| `REL-004` | A constituent relationship must declare a lifecycle policy |
| `REL-005` | External relationships must reference a registered Information Provider |
| `REL-006` | Relationship types must be from the standard vocabulary |
| `REL-007` | Consumer-declared binding types must be permitted by the Resource Type Specification |

### 11.2 Relationship Versioning and Deprecation

Relationships follow the universal versioning and deprecation model. A relationship version changes when its lifecycle policy, nature, or role changes. Terminated relationships are retained in provenance permanently.

---

## 12. Open Questions

| # | Question | Impact | Status |
|---|----------|--------|--------|
| 1 | How are relationship conflicts resolved — two policies declare different lifecycle policies for the same relationship? | Policy model | ❓ Unresolved |
| 2 | Should relationship roles be validated against the role registry at request time, or is validation advisory? | Operational complexity | ❓ Unresolved |
| 3 | How does the relationship graph interact with multi-tenant scenarios — can a relationship cross Tenant boundaries? | Multi-tenancy | ❓ Unresolved |
| 4 | Should there be a maximum relationship graph depth to prevent runaway complexity? | Operational governance | ❓ Unresolved |
| 5 | How are shared entities represented in the relationship graph — an entity required by multiple parents? | Graph model | ❓ Unresolved |

---

## 13. Related Concepts

- **Entity Relationship Graph** — the complete traversable graph of all entity relationships in DCM
- **Information Provider** — provider type for external data entities referenced in relationships
- **Bundled Declaration Expansion** — processor mechanism for expanding bundled fields into entities and relationships
- **Lifecycle Policy** — declares what happens to an entity when its related entity changes state
- **Service Dependencies** — document covering rehydration ordering and failure handling on the relationship graph
- **Resource Type Specification** — declares possible relationships for a resource type
- **External Entity Reference** — stable pointer to data owned by an external system

---

*Document maintained by the DCM Project. For questions or contributions see [GitHub](https://github.com/dcm-project).*
