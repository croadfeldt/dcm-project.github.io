---
title: "Control Plane Components"
type: docs
weight: 25
---

> **⚠️ Active Development Notice**
>
> The DCM data model and architecture documentation are actively being developed. Concepts, structures, and specifications documented here represent work in progress and are subject to change as design decisions are finalized.
>
> Contributions, feedback, and discussion are welcome via [GitHub](https://github.com/dcm-project).

**Document Status:** 🔄 In Progress
**Document Type:** Architecture Reference
**Related Documents:** [Context and Purpose](00-context-and-purpose.md) | [Four States](02-four-states.md) | [Resource/Service Entities](06-resource-service-entities.md) | [Operational Models](24-operational-models.md) | [Policy Profiles](14-policy-profiles.md)

---

## 1. Purpose

This document formally defines the DCM control plane components that are referenced throughout the data model documents but not previously specified in detail. Two components are defined here:

1. **The Request Orchestrator** — the event bus and coordinator of the request lifecycle pipeline
2. **The Cost Analysis Component** — the internal DCM component that provides cost signals for placement, catalog, and attribution

---

## 2. The Request Orchestrator

### 2.1 Role

The Request Orchestrator is the **event bus and pipeline coordinator** for all DCM request lifecycle operations. It does not perform any pipeline work itself — it listens for events, evaluates which components need to act on them, and routes work to the appropriate components.

The Request Orchestrator embodies DCM's **data-driven, policy-triggered orchestration model**: the pipeline is not a fixed procedural sequence. It is a cascade of event-condition-action responses, where policies define what happens when specific payload states are observed.

### 2.2 Data-Driven Orchestration Principle

**Policies ARE the orchestration.** The Request Orchestrator does not contain hardcoded pipeline logic. It publishes events to the Policy Engine; policies match on payload type and state; policy actions produce new payload states; those new states trigger further policy evaluations.

This means:
- Adding a new pipeline step = writing a new policy (no code change)
- Removing a step = deactivating a policy
- Changing when a step fires = changing a policy condition
- A static workflow (e.g., always require human approval for prod VMs) = a policy that always matches for those conditions
- A dynamic workflow (e.g., route to different approval processes based on cost) = a policy with conditional logic

Static and dynamic flows compose naturally — a static policy defines a guaranteed step; a dynamic policy defines a conditional step. Both are expressed as policies, evaluated by the same engine, producing deterministic outcomes.

**Determinism guarantee:** Dynamic execution remains deterministic because:
- The payload type vocabulary is a closed set
- Policy evaluation order within a domain level is deterministic (domain precedence)
- The payload mutation model is immutable (each policy produces a new payload version)
- The same input state always produces the same output state

### 2.3 The Payload Type Vocabulary

Every event in DCM carries a payload with a declared type. Policies pattern-match on these types. The payload type vocabulary is the foundational contract of the orchestration model.

```yaml
payload_types:
  # Request lifecycle
  request.initiated:          # consumer submitted a request
  request.intent_captured:    # Intent State written
  request.layers_assembled:   # layer assembly complete
  request.policies_evaluated: # all active policies evaluated
  request.placement_complete: # provider selected
  request.dispatched:         # sent to provider
  request.realized:           # provider confirmed realization
  request.failed:             # terminal failure
  request.cancelled:          # cancelled

  # Provider update
  provider_update.received:   # provider submitted update notification
  provider_update.evaluated:  # policy evaluation complete
  provider_update.accepted:   # accepted; Realized State updating
  provider_update.rejected:   # rejected; becomes drift

  # Drift and discovery
  discovery.cycle_complete:
  drift.detected:
  drift.resolved:

  # Recovery
  recovery.timeout_fired:
  recovery.late_response:
  recovery.compensation_triggered:

  # Governance
  policy.activated:
  layer.updated:
  profile.changed:
```

### 2.4 Event Routing Model

```
Event published: { type: "request.initiated", payload: {...}, entity_uuid: X }
  │
  ▼ Request Orchestrator receives event
  │   Routes to Policy Engine: "evaluate all policies matching request.initiated"
  │
  ▼ Policy Engine evaluates in domain precedence order
  │   Matching policies fire; payload mutations accumulated
  │   New payload state produced: { type: "request.layers_assembled", ... }
  │
  ▼ Request Orchestrator receives new event
  │   Routes to Policy Engine for next evaluation cycle
  │   (parallel if no data dependencies between active policies)
  │
  ▼ Continues until terminal state (request.realized or request.failed)
```

**Parallel execution:** Policies that have no data dependencies on each other evaluate concurrently. The Request Orchestrator tracks dependency declarations between policies and executes in parallel where safe.

### 2.5 Static Flow Support

Organizations that require guaranteed sequential flows express them as ordered policy sets:

```yaml
static_flow_policy_group:
  handle: "org/flows/prod-vm-approval-flow"
  concern_type: orchestration_flow
  ordered: true                # policies execute in declared sequence, not parallel
  policies:
    - step: 1
      handle: "org/policies/cost-check"
      condition: "request.initiated AND resource_type=Compute.VirtualMachine AND tenant.profile=prod"
      on_fail: halt
    - step: 2
      handle: "org/policies/manager-approval"
      condition: "request.cost_estimated > 500"
      on_fail: halt
    - step: 3
      handle: "org/policies/security-review"
      condition: "always"
      on_fail: halt
```

A static flow is a Policy Group with `concern_type: orchestration_flow` and `ordered: true`. The Request Orchestrator respects the declared order. Static flows integrate with dynamic policies — a dynamic policy can fire alongside the static flow steps.

### 2.6 Request Orchestrator Responsibilities

| Responsibility | Description |
|----------------|-------------|
| Event routing | Receive all request lifecycle events; route to appropriate components |
| Pipeline coordination | Sequence component interactions per data dependencies |
| Timeout monitoring | Track dispatch_timeout and assembly_timeout; fire recovery triggers |
| Dependency resolution | For compound services, sequence component provisioning per dependency graph |
| Status tracking | Maintain current status of all in-flight requests; respond to status queries |
| Recovery coordination | On timeout/failure, invoke Recovery Policy evaluation |

---

## 3. The Cost Analysis Component

### 3.1 Role

The Cost Analysis Component is an **internal DCM control plane component** that provides cost signals to other components. It is not a billing system and not a provider type. It does not manage financial transactions, produce invoices, or serve as the authoritative financial record. It provides cost *signals* that DCM uses for placement decisions, pre-request estimation, and ongoing attribution.

The authoritative billing record lives in the organization's financial system. A billing system can register as an Information Provider to push authoritative cost data back into DCM for attribution records.

### 3.2 Three Cost Functions

**Function 1 — Pre-request cost estimation:**
Given a catalog item and assembled field values, compute the estimated lifecycle cost. Used by:
- Service Catalog describe endpoint (consumer sees cost before requesting)
- CI pipeline pre-validation (cost estimate in PR comment)
- Placement engine tie-breaker step 4 (cheapest eligible provider)

**Function 2 — Placement cost input:**
During Step 6 placement, provide current cost data per eligible provider for the requested resource type. If Cost Analysis data is unavailable, the placement engine falls back to static declared costs per REG-011.

**Function 3 — Ongoing cost attribution:**
For realized entities, track ongoing consumption and attribute costs to the owning Tenant. Consumed by OBS-005 (consumer cost view) and the resource describe endpoint (`estimated_cost_per_hour` field).

### 3.3 Cost Data Sources

The Cost Analysis Component ingests cost data from two sources, following the REG-011 hybrid model:

```yaml
cost_data_sources:
  static:
    source: provider_registration     # declared at provider registration time
    update_frequency: manual          # updated when rates change
    fields: [capex_per_unit, opex_per_unit_per_hour, currency]

  dynamic:
    source: external_cost_api         # external billing API or cloud pricing API
    registered_as: information_provider
    query_interval: PT1H
    fallback: static                  # use static if dynamic unavailable
    fallback_max_age: PT24H
```

### 3.4 Cost Estimation Model

```yaml
cost_estimation_request:
  catalog_item_uuid: <uuid>
  assembled_fields:
    cpu_count: 4
    memory_gb: 8
    storage_gb: 100
  tenant_uuid: <uuid>
  requested_duration: P30D           # optional; lifecycle estimate

cost_estimation_response:
  estimated_cost:
    per_hour: 0.32
    per_month: 230.40
    lifecycle_estimate: 691.20       # if requested_duration provided
    currency: USD
    confidence: high                 # high: current Cost Analysis data
                                     # medium: data > PT1H old
                                     # low: static fallback
    breakdown:
      - component: compute
        per_hour: 0.28
      - component: ip_allocation
        per_hour: 0.04
  cost_data_timestamp: <ISO 8601>
```

### 3.5 Cost Attribution for Realized Entities

```yaml
entity_cost_attribution:
  entity_uuid: <uuid>
  tenant_uuid: <uuid>
  billing_state: billable            # billable | non_billable | reduced_rate
  current_rate:
    per_hour: 0.32
    currency: USD
    rate_effective_since: <ISO 8601>
  monthly_accrual: 230.40
  cost_data_source: cost_analysis    # cost_analysis | static | unknown
```

### 3.6 Integration with Placement Engine

The placement engine queries Cost Analysis at step 4 of the tie-breaking hierarchy:

```
Step 4 — Cost Analysis (if available and determinable):
  Query Cost Analysis for each eligible provider
  Cost Analysis returns: estimated cost per unit per provider
  Placement engine prefers lowest cost among equally-ranked candidates
  If Cost Analysis unavailable: skip step 4; proceed to step 5
  # Cost Analysis unavailability never blocks placement
```

---

## 4. Related Policies

| Policy | Rule |
|--------|------|
| `CTL-001` | The Request Orchestrator is the single event bus for all request lifecycle events. No component communicates directly with another component outside of events published to the Request Orchestrator. |
| `CTL-002` | Policies ARE the orchestration. The Request Orchestrator does not contain hardcoded pipeline logic. Pipeline behavior is modified by adding, removing, or changing policies — not by changing the orchestrator. |
| `CTL-003` | Dynamic and static flows compose naturally. Static flows are Policy Groups with concern_type: orchestration_flow and ordered: true. Both types are evaluated by the same Policy Engine. |
| `CTL-004` | Cost Analysis is not a billing system. It provides cost signals for placement and attribution. The authoritative billing record lives in the organization's financial system, which may register as an Information Provider. |
| `CTL-005` | Cost Analysis unavailability never blocks placement. The placement engine falls back to static declared costs per REG-011 and skips the Cost Analysis tie-breaking step. |

---

*Document maintained by the DCM Project. For questions or contributions see [GitHub](https://github.com/dcm-project).*
