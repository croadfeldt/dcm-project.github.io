---
title: "Resource and Service Entities"
type: docs
weight: 5
---

> **⚠️ Active Development Notice**
> 
> The DCM data model and architecture documentation are actively being developed. Concepts, structures, and specifications documented here represent work in progress and are subject to change as design decisions are finalized. Open questions are explicitly tracked and decisions are recorded as they are made.
> 
> Contributions, feedback, and discussion are welcome via [GitHub](https://github.com/dcm-project).


**Document Status:** 🔄 In Progress  
**Related Documents:** [Context and Purpose](../context-and-purpose/) | [Layering and Versioning](../layering-and-versioning/) | [Resource Type Hierarchy](../resource-type-hierarchy/) | [Service Dependencies](../service-dependencies/) | [Resource Grouping](../resource-grouping/)

---

## 1. Purpose

This document defines the two fundamental transactional concepts in DCM — the **Resource/Service Request** and the **Resource/Service Entity** — and establishes the ownership models, lifecycle principles, and provider relationship rules that govern them.

Understanding the distinction between a Request and an Entity, and understanding DCM's role as the authoritative owner of all resource data regardless of operational ownership, is essential to understanding how DCM achieves its core goals of auditability, lifecycle management, and sovereignty.

---

## 2. Core Terminology

### 2.1 Resource/Service Request

A **Resource/Service Request** is what a consumer submits to DCM — the declared intent to consume a resource or service. It is the consumer side of the transaction.

- Created when a consumer submits a request via the Web UI or Consumer API
- Captured as the **Intent State** before any processing
- Processed into the **Requested State** after assembly and policy validation
- Is the initiating event that causes a Resource/Service Entity to be created

A Request is not a thing — it is an **instruction**. It describes what the consumer wants. The provider acts on the Requested State to produce an Entity.

### 2.2 Resource/Service Entity

A **Resource/Service Entity** is the "thing" produced by a provider as a result of fulfilling a Resource/Service Request. It is the provider side of the transaction — the allocation made real.

- Created when a provider fulfills a Requested State payload
- Returned to DCM in unified data model format via Denaturalization
- Captured as the **Realized State** in the Realized Store
- Assigned to a **DCM Tenant** — the ownership boundary
- Has a UUID, full provenance chain, and complete lifecycle from creation to decommission
- Is the unit of consumption, cost attribution, drift detection, and audit in DCM

A Resource/Service Entity IS a thing — it exists, it has state, it has an owner, and DCM manages its lifecycle.

### 2.3 The Critical Distinction

```
Consumer submits        →  Resource/Service REQUEST  →  Intent/Requested State
Provider fulfills       →  Resource/Service ENTITY   →  Realized State
DCM manages lifecycle   →  ENTITY persists            →  Drift/Audit/Cost/Rehydration
```

---

## 3. DCM as Authoritative Owner of All Resource Data

This is the most fundamental principle governing Resource/Service Entities:

**DCM is ALWAYS the system of record for Resource/Service Entity data. DCM is ALWAYS authoritative for the resource definition. DCM ALWAYS owns the lifecycle. This applies regardless of the operational ownership model.**

The operational ownership model (described in Section 4) determines who has authority to operate on a Resource/Service Entity. It does not affect DCM's data ownership. Specifically:

- DCM owns the **data definition** of every Resource/Service Entity — what it is, what it should be, what it was
- DCM owns the **lifecycle** — from Requested through Realized to Decommissioned
- DCM is **authoritative** — if a provider reports a change DCM was not aware of, DCM acts on it according to policy
- DCM acts as the **Tenant advocate** — it protects the Tenant's interests in all provider interactions
- Providers are **custodians** of the underlying infrastructure — they are not the system of record

**When a provider reports an unsanctioned change:**

If a provider reports a state change that was not initiated by a DCM request, the Policy Engine evaluates the change and determines the appropriate response:

| Response | Description |
|----------|-------------|
| `ALERT` | Notify appropriate personas — Tenant owner, SRE, Auditor |
| `REVERT` | Instruct provider to revert to DCM-declared realized state |
| `UPDATE_DEFINITION` | Accept the change and update the realized state definition |
| `INVESTIGATE` | Flag for human review before action |
| `DECOMMISSION` | Initiate decommission if the change represents unrecoverable deviation |
| `ESCALATE` | Escalate to higher policy tier for decision |

The response is determined by Policy Engine evaluation against:
- The Resource/Service definition
- Service/Resource dependencies
- Consumer preferences
- Organizational and Tenant policies
- Sovereignty requirements

---

## 4. Ownership Models

DCM supports four ownership models for Resource/Service Entities. Every Provider Catalog Item must declare which ownership model(s) it supports. The ownership model is recorded in the Resource/Service Entity's provenance at creation time.

### 4.1 Allocation Model

The provider retains internal ownership of the underlying infrastructure. The consumer owns the Resource/Service Entity (the allocation) in their DCM Tenant. The provider can reclaim the underlying resource when the entity is decommissioned.

**Characteristics:**
- Provider retains asset ownership
- Consumer owns the allocation — the Entity in their DCM Tenant
- Provider has reclaim rights on decommission
- Underlying infrastructure may be shared or subdivided
- DCM manages the Entity lifecycle; provider manages the underlying resource

**Examples:** Virtual Machine, Container, Network Port, IP Address, Firewall Rule, Database Instance

---

### 4.2 Whole Allocation Model

The entire physical or logical resource is allocated as a single indivisible unit to one consumer's DCM Tenant. The provider retains internal ownership but the consumer has exclusive use of the whole resource. The resource cannot be subdivided or shared during the allocation period.

**Characteristics:**
- Provider retains asset ownership
- Consumer has exclusive, indivisible use
- The resource is not shared or subdivided
- Provider has reclaim rights on decommission
- DCM manages the Entity lifecycle

**Examples:** Dedicated Bare Metal server (provider-owned), Dedicated Network appliance, Whole storage array allocation

---

### 4.3 Full Transfer Model

The provider transfers complete ownership of the underlying resource to the consumer's DCM Tenant. The Resource/Service Entity IS the resource — there is no separation between the allocation and the underlying infrastructure from DCM's perspective. The consumer controls the full lifecycle including decommissioning. The provider has no reclaim rights after transfer.

**Characteristics:**
- Ownership of the underlying resource transfers to consumer's DCM Tenant
- The Entity IS the resource — no allocation/infrastructure separation
- Consumer controls full lifecycle including decommission
- Provider has no reclaim rights post-transfer
- Transfer is recorded in provenance — permanent audit record
- DCM remains authoritative for data and lifecycle regardless of transfer

**Examples:** Transferred Bare Metal server, Licensed software asset, Dedicated hardware appliance transferred to consumer

---

### 4.4 Hybrid Transfer Model

Ownership can transfer multiple times across the lifecycle of the Resource/Service Entity. The current owner is always exactly one DCM Tenant, but ownership can be formally reassigned through a DCM-governed ownership transfer process. Every transfer is tracked, auditable, and policy-governed.

**Characteristics:**
- Ownership is held by exactly one DCM Tenant at any point in time
- Ownership can be transferred to another DCM Tenant through a formal DCM process
- Every transfer is recorded in the Entity's provenance chain — complete ownership history
- Transfer requires Policy Engine validation and authorization
- The receiving Tenant must accept the transfer — it cannot be forced
- DCM remains authoritative for data and lifecycle through all transfers

**Transfer Provenance Record:**
```yaml
ownership_transfer:
  sequence: <transfer number — 1 for first transfer, 2 for second, etc.>
  from_tenant_uuid: <uuid of transferring tenant>
  to_tenant_uuid: <uuid of receiving tenant>
  transfer_timestamp: <ISO 8601>
  authorized_by: <uuid of authorizing policy or persona>
  transfer_reason: <human-readable reason>
  policy_uuid: <uuid of policy that governed this transfer>
```

**Examples:** Bare Metal server reallocated between tenants, Hardware asset transferred between business units, Licensed resource reassigned

---

### 4.5 Ownership Model Declaration

Every Provider Catalog Item must declare the ownership model(s) it supports:

```yaml
catalog_item:
  uuid: <uuid>
  ownership_models_supported:
    - allocation
    - whole_allocation
    - full_transfer
    - hybrid_transfer
  default_ownership_model: <one of the above>
  transfer_policy_required: <true|false>
  # If true, a policy must be referenced in any transfer request
```

---

## 5. Resource/Service Entity Lifecycle

Every Resource/Service Entity progresses through a defined lifecycle. The lifecycle states are:

```
REQUESTED → PENDING → PROVISIONING → REALIZED → OPERATIONAL
                                                      │
                                          ┌───────────┼───────────┐
                                          ▼           ▼           ▼
                                      DEGRADED   MAINTENANCE  SUSPENDED
                                          │           │           │
                                          └───────────┼───────────┘
                                                      ▼
                                                DECOMMISSIONING
                                                      │
                                                      ▼
                                                DECOMMISSIONED
```

| State | Description |
|-------|-------------|
| `REQUESTED` | Request submitted, Intent State captured |
| `PENDING` | Requested State assembled, awaiting provider dispatch |
| `PROVISIONING` | Provider is fulfilling the request |
| `REALIZED` | Provider has fulfilled the request, Entity exists, Realized State captured |
| `OPERATIONAL` | Entity is in active use |
| `DEGRADED` | Entity is functioning but below expected operational characteristics |
| `MAINTENANCE` | Entity is undergoing planned maintenance |
| `SUSPENDED` | Entity is temporarily suspended — not operational but not decommissioned |
| `DECOMMISSIONING` | Decommission process initiated |
| `DECOMMISSIONED` | Entity no longer exists. Record retained permanently for audit. |

**Terminal states:** `DECOMMISSIONED` is the only terminal state. Once decommissioned, the Entity record is immutable and retained permanently.

---

## 6. Process Resource Entities

A **Process Resource Entity** is a distinct class of Resource/Service Entity representing ephemeral execution resources — automation jobs, playbooks, pipelines, workflows, and similar process-oriented resources.

### 6.1 Characteristics

- **Ephemeral lifecycle** — exists for the duration of execution, then terminates
- **No ongoing realized state to manage** — lifecycle ends at COMPLETED or FAILED
- **Execution record retained permanently** — the record of what the process did is immutable and permanent
- **Must belong to a DCM Tenant** — even ephemeral resources must be owned
- **Must be in the provenance chain** of any Resource/Service Entity they affect

### 6.2 Process Resource Lifecycle

```
REQUESTED → INITIATED → EXECUTING → COMPLETED
                                  → FAILED
                                  → CANCELLED
```

| State | Description |
|-------|-------------|
| `REQUESTED` | Process request submitted |
| `INITIATED` | Provider has begun execution |
| `EXECUTING` | Process is actively running |
| `COMPLETED` | Process completed successfully — terminal |
| `FAILED` | Process failed — terminal |
| `CANCELLED` | Process cancelled before completion — terminal |

All terminal states are permanent. The execution record is immutable after reaching a terminal state.

### 6.3 Process Resource Entity Data Model

```yaml
process_resource_entity:
  uuid: <uuid>
  entity_class: process
  process_type: <playbook|workflow|pipeline|automation_job|script|other>
  tenant_uuid: <owning tenant uuid>
  version: <Major.Minor.Revision>
  lifecycle_state: <REQUESTED|INITIATED|EXECUTING|COMPLETED|FAILED|CANCELLED>
  input_payload:
    <the Requested State payload that initiated this process>
  output_payload:
    <what the process produced — in DCM unified format>
  affected_entities:
    - entity_uuid: <uuid of affected Resource/Service Entity>
      effect_type: <created|modified|decommissioned|read>
      effect_description: <human-readable description>
  execution_record:
    initiated_timestamp: <ISO 8601>
    completed_timestamp: <ISO 8601 — when terminal state reached>
    executing_provider_uuid: <uuid of provider that executed>
    authorized_by_policy_uuid: <uuid of policy that authorized execution>
  provenance:
    <standard provenance metadata>
```

### 6.4 Provenance Obligation for Process Resources

If a Process Resource modifies the state of a Resource/Service Entity, that Entity's realized state provenance MUST reference the Process Resource Entity UUID as the source of the modification. This ensures that every change to an Infrastructure Entity can be traced back to the Process that caused it.

---

## 7. Provider Internal Lifecycle Model

Providers have their own internal infrastructure that underpins the Resource/Service Entities they create. While that internal infrastructure is opaque to consumers, DCM needs visibility into it for placement, cost analysis, and operational governance.

### 7.1 Provider Capacity Model

DCM supports three capacity information modes. Mode 3 is mandatory for all providers. Modes 1 and 2 are configurable per provider registration.

**Mode 1 — Dynamic Query (on-demand)**
DCM queries the provider for current capacity as part of request processing. Used when real-time accuracy is critical or when the provider cannot maintain a registration schedule.

```yaml
capacity_query_response:
  provider_uuid: <uuid>
  resource_type_uuid: <uuid>
  location_uuid: <uuid>
  query_timestamp: <ISO 8601>
  available_capacity: <units>
  reserved_capacity: <units>
  committed_capacity: <units>
  sovereignty_capabilities: <list>
```

**Mode 2 — Provider Registration (scheduled, preferred)**
Provider registers capacity data with DCM on a configurable schedule. DCM maintains an internal capacity rating per provider, per Resource Type, per location. Default minimum update frequency: twice daily. Update frequency is configurable per provider registration.

```yaml
capacity_registration:
  provider_uuid: <uuid>
  registration_timestamp: <ISO 8601>
  next_scheduled_registration: <ISO 8601>
  capacity_by_resource_type:
    - resource_type_uuid: <uuid>
      location_uuid: <uuid>
      available_capacity: <units>
      reserved_capacity: <units>
      committed_capacity: <units>
      sovereignty_capabilities: <list>
```

**Mode 3 — Provider Denial (reactive, mandatory)**
The provider validates it can fulfill a request before executing. If it cannot, it denies the request with reason `INSUFFICIENT_RESOURCES`. DCM receives the denial and can retry with an alternative provider. The denial triggers an immediate update to DCM's internal capacity rating for that provider.

```yaml
provider_denial:
  provider_uuid: <uuid>
  request_uuid: <uuid>
  denial_reason: INSUFFICIENT_RESOURCES
  denial_timestamp: <ISO 8601>
  resource_type_uuid: <uuid>
  location_uuid: <uuid>
  estimated_available_at: <ISO 8601 — optional, if provider can estimate>
```

### 7.2 Provider Lifecycle Events

Any provider event that affects Resource/Service Entity availability or operational characteristics MUST be reported to DCM immediately. Providers have a contractual obligation to report these events — this is non-negotiable.

**Reportable Event Types:**

| Event Type | Description | DCM Response |
|------------|-------------|--------------|
| `CAPACITY_CHANGE` | Available capacity increased or decreased | Update internal capacity rating |
| `DEGRADATION` | Underlying resource is degraded | Policy Engine evaluation → ALERT/REVERT/ESCALATE |
| `MAINTENANCE_SCHEDULED` | Planned maintenance window declared | Policy Engine evaluation → notify, migrate if needed |
| `MAINTENANCE_STARTED` | Maintenance has begun | Update Entity state to MAINTENANCE |
| `MAINTENANCE_COMPLETED` | Maintenance completed | Restore Entity state, trigger drift detection |
| `UNSANCTIONED_CHANGE` | Change occurred that was not initiated by DCM | Policy Engine evaluation → REVERT/UPDATE/ALERT |
| `ENTITY_HEALTH_CHANGE` | Entity health status changed | Policy Engine evaluation |
| `PROVIDER_DEGRADATION` | Provider itself is degraded | Policy Engine evaluation → reroute new requests |
| `DECOMMISSION_NOTICE` | Provider is decommissioning underlying resource | Policy Engine evaluation → migrate or decommission Entity |

**Event Payload Format:**
All provider lifecycle events must be reported in DCM unified data model format:

```yaml
provider_lifecycle_event:
  event_uuid: <uuid>
  event_type: <one of the types above>
  provider_uuid: <uuid>
  affected_entity_uuids:
    - <uuid of affected Resource/Service Entity>
  event_timestamp: <ISO 8601>
  event_details:
    <event-specific data in DCM unified format>
  severity: <INFO|WARNING|CRITICAL>
  requires_immediate_action: <true|false>
```

**Maximum Reporting Latency:**
Providers must report lifecycle events within the timeframe declared in their provider registration. For CRITICAL severity events, immediate reporting is required. The reporting latency SLA is part of the Provider SLA/Operational Contract.

### 7.3 DCM Capacity Rating

DCM maintains an internal capacity rating per provider, per Resource Type, per location. This rating is used by the Policy Engine for placement decisions.

```yaml
dcm_capacity_rating:
  provider_uuid: <uuid>
  resource_type_uuid: <uuid>
  location_uuid: <uuid>
  last_updated: <ISO 8601>
  update_source: <mode_1_query|mode_2_registration|mode_3_denial>
  available_capacity: <units>
  capacity_confidence: <high|medium|low>
  # high: updated within last scheduled window
  # medium: updated within 2x scheduled window
  # low: stale — beyond 2x scheduled window
  next_scheduled_update: <ISO 8601>
```

---

## 8. Entity Relationships

Every Resource/Service Entity carries a `relationships` section declaring its relationships to other entities — internal DCM entities, external data entities, and business context entities. The relationship model is universal — the same structure is used for all relationship types.

See [Entity Relationships](../entity-relationships/) for the complete relationship model.

```yaml
resource_service_entity:
  uuid: <uuid>
  # ... other entity fields ...
  relationships:
    - relationship_uuid: <uuid — same on both sides>
      this_entity_uuid: <this entity's uuid>
      this_role: <role this entity plays>
      related_entity_uuid: <uuid of related entity or external reference>
      related_entity_type: <internal|external>
      relationship_type: <requires|depends_on|contains|references|peer|manages>
      nature: <constituent|operational|informational>
      lifecycle_policy:
        on_related_destroy: <destroy|retain|detach|notify>
        on_related_suspend: <suspend|retain|detach|notify>
        on_related_modify: <cascade|ignore|notify>
      status: <active|suspended|terminated>
      provenance:
        <standard provenance metadata>
```

---

## 9. DCM System Policies for Resource/Service Entities

The following are **non-overridable DCM System Policies** that apply to all Resource/Service Entities:

| Policy | Rule | Enforcement |
|--------|------|-------------|
| `RSE-001` | Every Resource/Service Entity must belong to exactly one DCM Tenant | Enforced at Entity creation — no Tenant = request rejected |
| `RSE-002` | Every Resource/Service Entity must have a UUID | Enforced at Entity creation |
| `RSE-003` | Every Resource/Service Entity must have a complete provenance chain | Enforced at every state transition |
| `RSE-004` | Realized State payloads must be complete — not a status code | Enforced at provider response receipt |
| `RSE-005` | Decommissioned Entity records are immutable and permanent | Enforced at decommission — records cannot be deleted |
| `RSE-006` | Provider lifecycle events must be recorded in Entity provenance | Enforced at event receipt |
| `RSE-007` | Ownership transfers must be authorized by policy | Enforced at transfer initiation |
| `RSE-008` | Process Resource Entities must reference all affected Entity UUIDs | Enforced at process completion |

---

## 10. Open Questions

| # | Question | Impact | Status |
|---|----------|--------|--------|
| 1 | For Hybrid Transfer — what is the maximum number of ownership transfers allowed, or is it unlimited? | Operational complexity | ❓ Unresolved |
| 2 | For Whole Allocation of bare metal — how is the indivisibility enforced at the provider level? | Provider contract | ❓ Unresolved |
| 3 | Should capacity confidence ratings trigger automatic actions (e.g., LOW confidence triggers a Mode 1 query)? | Capacity model | ❓ Unresolved |
| 4 | For Process Resources — should there be a maximum execution time after which DCM escalates? | Operational governance | ❓ Unresolved |
| 5 | How does the SUSPENDED state interact with cost analysis — is a suspended Entity still billable? | Cost model | ❓ Unresolved |

---

## 11. Related Concepts

- **DCM Tenant** — the mandatory ownership boundary for all Resource/Service Entities
- **Four States** — Intent, Requested, Realized, Discovered — the state lifecycle of a Resource/Service Request and Entity
- **Field-Level Provenance** — every state transition and ownership transfer is recorded in Entity provenance
- **Policy Engine** — evaluates provider events and unsanctioned changes, determines response actions
- **Service Dependencies** — Resource/Service Entities declare dependencies on other Entities
- **Resource Grouping** — Entities belong to a Tenant and optionally to additional Resource Groups
- **Provider Contract** — governs provider obligations including capacity reporting and event notification

---

*Document maintained by the DCM Project. For questions or contributions see [GitHub](https://github.com/dcm-project).*
