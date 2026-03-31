# DCM — Examples and Use Cases

**Document Status:** ✅ Complete
**Status:** Draft — Examples document - no WIP status needed; always current with architecture.
**Document Type:** Reference Examples
**Related Documents:** [Foundational Abstractions](../data-model/00-foundations.md) | [Provider Contract](../data-model/A-provider-contract.md) | [Policy Contract](../data-model/B-policy-contract.md) | [Consumer API](consumer-api-spec.md) | [Admin API](dcm-admin-api-spec.md) | [Registration](dcm-registration-spec.md) | [OPA Integration](dcm-opa-integration-spec.md)

---

## Overview

This document provides end-to-end worked examples for the most important DCM use cases. Each example shows the complete interaction — payloads, state transitions, API calls, and Rego policies where applicable — so implementors can trace exactly what happens at each step.

Examples are organized by the three foundational abstractions:
- **Section 1** — Orchestration examples (Policy)
- **Section 2** — Provider interaction examples (Provider)
- **Section 3** — API interaction examples (Consumer API, Admin API)
- **Section 4** — Registration flow examples

---

# Section 1 — Orchestration Examples

## 1.1 Basic Request Lifecycle (End-to-End)

The complete path for a consumer requesting a VM. Shows all payload type events, which policies fire at each step, and the state transitions.

### Setup: Active artifacts

```yaml
# Named workflow (Level 1 orchestration)
Orchestration Flow Policy: system/workflows/request-lifecycle
  ordered: true
  steps: [request.initiated, request.intent_captured,
          request.layers_assembled, request.placement_complete,
          request.dispatched]

# Dynamic policies (Level 2 orchestration)
GateKeeper:      org/gatekeeper/vm-size-limits         (fires on request.layers_assembled)
Transformation:  org/transformation/inject-monitoring  (fires on request.layers_assembled)
GateKeeper:      system/gatekeeper/sovereignty-check   (fires on request.placement_complete)
```

### Step-by-step

**Step 1 — Consumer submits request:**
```
POST /api/v1/requests
{ "catalog_item_uuid": "vm-standard-uuid",
  "fields": { "cpu_count": 4, "memory_gb": 8, "os_family": "rhel" } }

→ Response 202: { "request_uuid": "req-001", "entity_uuid": "ent-001",
                  "status": "ACKNOWLEDGED" }
→ Event published: { "type": "request.initiated", "entity_uuid": "ent-001",
                     "payload": { "fields": {...} } }
→ Intent State written to Intent Store
```

**Step 2 — Layer assembly:**
```
Event: request.initiated
→ Named workflow step 1 fires: capture-intent policy acknowledges
→ New event: request.intent_captured

Event: request.intent_captured
→ Named workflow step 2 fires: assemble-layers policy runs
→ Base layer applied: data_center = "EU-WEST-DC1"
→ Org layer applied: monitoring_agent = "datadog-agent:7.42"
→ Policy layer applied: backup_policy = "daily-30d-eu-west"
→ New event: request.layers_assembled
  payload now includes all merged fields with provenance
```

**Step 3 — Dynamic policies fire on request.layers_assembled:**
```
Event: request.layers_assembled
→ [PARALLEL] All policies matching this payload type evaluate simultaneously:

  GateKeeper vm-size-limits evaluates:
    input.payload.fields.cpu_count.value = 4
    4 <= 32 → allow: true

  Transformation inject-monitoring evaluates:
    monitoring_endpoint not in payload → mutation:
    { field: "fields.monitoring_endpoint",
      operation: "set",
      value: "https://metrics.internal.prod.example.com" }

→ All GateKeepers: allow
→ Transformations applied to payload
→ New event: request.policies_evaluated
```

**Step 4 — Placement:**
```
Event: request.policies_evaluated
→ Named workflow step 3: run-placement policy

→ Placement Engine:
  Step 1: Sovereignty filter — EU-WEST-DC1 requirement → 3 providers eligible
  Step 2: Accreditation filter — no PHI in payload → all 3 pass
  Step 3: Capability filter — all support VirtualMachine → all 3 pass
  Step 4: Reserve query → parallel queries to EU-WEST-Prod-1,2,3
    EU-WEST-Prod-1: confirmed, utilization 42%, cost $0.32/hr
    EU-WEST-Prod-2: confirmed, utilization 61%, cost $0.32/hr
    EU-WEST-Prod-3: insufficient capacity
  Step 5: Tie-break → Step 4 cost equal → Step 5 least loaded → Prod-1 wins
  Step 6: Confirm Prod-1; release holds on Prod-2

→ Requested State written to Requested Store
  (requested.yaml + assembly-provenance.yaml + placement.yaml + dependencies.yaml)
→ New event: request.placement_complete
```

**Step 5 — Dispatch and realization:**
```
Event: request.placement_complete
→ Governance Matrix evaluated: payload data_classification = internal/public → ALLOW
→ Named workflow step 4: dispatch policy
→ Provider EU-WEST-Prod-1 receives dispatch payload
→ Provider naturalizes to OpenStack Nova format
→ OpenStack provisions VM
→ Provider denaturalizes result → DCM unified format
→ Realized State written (with provider_entity_id: "vm-0a1b2c3d")
→ Status callback: COMPLETED

Consumer polls: GET /api/v1/requests/req-001/status
→ { "status": "COMPLETED", "entity_uuid": "ent-001" }
```

---

## 1.2 Human Approval Gate (Conditional Step Insertion)

A production VM request that requires manager approval before dispatch. Shows how a GateKeeper policy inserts a waiting step without modifying the named workflow.

### Setup: Additional active policy

```rego
# GateKeeper fires on request.policies_evaluated for prod VMs over $100/month
package dcm.gatekeeper.prod_vm_approval_gate

deny contains reason if {
    input.payload.type == "request.policies_evaluated"
    input.deployment.deployment_posture == "prod"
    input.payload.cost_estimate.per_month > 100
    not input.payload.approvals["manager_approval"]
    reason := "Production VMs over $100/month require manager approval"
}

# Signal that approval is the resolution path (not a permanent reject)
requires_approval := true if count(deny) > 0
approval_type := "manager_approval" if count(deny) > 0
```

### Step-by-step

```
After Step 3 (dynamic policies evaluate):
→ GateKeeper prod_vm_approval_gate fires
→ deny: ["Production VMs over $100/month require manager approval"]
→ requires_approval: true, approval_type: "manager_approval"

→ Policy Engine sees GateKeeper deny WITH requires_approval flag
→ Entity enters AWAITING_APPROVAL state (not FAILED)
→ Notification dispatched:
    audience: manager (from actor's group membership via relationship graph)
    event_type: request.requires_approval
    action_url: /api/v1/requests/req-001:approve
    action_deadline: PT24H

Manager approves:
POST /api/v1/requests/req-001:approve
{ "approval_type": "manager_approval", "approver_uuid": "mgr-001" }

→ payload.approvals["manager_approval"] = { approved: true, by: "mgr-001" }
→ GateKeeper re-evaluates: approval present → allow
→ Pipeline resumes from request.policies_evaluated
→ Placement → Dispatch → Realization (same as 1.1 Steps 4-5)
```

---

## 1.3 Policy-Gated Request — Hard Block with Clear Error

Shows a request blocked by a hard GateKeeper with a consumer-visible error message.

```rego
package dcm.gatekeeper.approved_os_images

deny contains reason if {
    input.payload.type == "request.layers_assembled"
    not input.payload.fields.os_family.value in {"rhel", "ubuntu-lts", "coreos"}
    reason := sprintf(
        "OS '%s' is not in the approved image list. Approved: rhel, ubuntu-lts, coreos",
        [input.payload.fields.os_family.value]
    )
}
```

```
Consumer submits: { "os_family": "windows-server" }

→ request.layers_assembled fires
→ GateKeeper approved_os_images: deny
→ Entity → FAILED (no requires_approval flag → hard block)

Consumer response:
{ "status": "FAILED",
  "failure_reason": "OS 'windows-server' is not in the approved image list.",
  "retry_eligible": true,
  "policy_uuid": "gatekeeper-approved-os-uuid",
  "suggestion": "Resubmit with os_family: rhel, ubuntu-lts, or coreos" }
```

---

## 1.4 Compound Service — Meta Provider with Dependency Ordering

A web application stack provisioned as a single catalog item: VM + IP + DNS + LoadBalancer.

### Named workflow for compound service

```rego
package dcm.orchestration.webapp_stack

steps := [
    {"step": 1, "payload_type": "request.initiated",
     "policy_handle": "system/orchestration/capture-intent", "on_fail": "halt"},
    {"step": 2, "payload_type": "request.intent_captured",
     "policy_handle": "system/orchestration/assemble-compound", "on_fail": "halt"},
    {"step": 3, "payload_type": "request.compound_assembled",
     "policy_handle": "system/orchestration/resolve-dependencies", "on_fail": "halt"},
    {"step": 4, "payload_type": "request.dependencies_resolved",
     "policy_handle": "system/orchestration/dispatch-constituents", "on_fail": "compensate"}
]

ordered := true
```

### Execution

```
Meta Provider receives compound dispatch payload:
  component.ip:  { resource_type: Network.IPAddress, depends_on: [] }
  component.vm:  { resource_type: Compute.VirtualMachine, depends_on: [] }
  component.dns: { resource_type: DNS.Record, depends_on: [ip, vm], required: partial }
  component.lb:  { resource_type: Network.LoadBalancer, depends_on: [vm, ip], required: partial }

Dependency-ordered execution:
  Round 1 (no dependencies): ip, vm  → provisioned in parallel
    ip  → REALIZED: 10.1.45.23/32
    vm  → REALIZED: vm-0a1b2c3d

  Round 2 (depend on ip+vm): dns, lb → provisioned in parallel
    dns → FAILED (DNS service degraded)
    lb  → REALIZED: lb-7f8e9d

  Compound evaluation:
    dns: required_for_delivery = partial → DEGRADED, not FAILED
    lb: required_for_delivery = partial → REALIZED

Compound entity state: DEGRADED (dns failed; vm+ip+lb realized)
Notification: owner notified "WebApp Stack provisioned in degraded state — DNS unavailable"

Recovery policy fires (PARTIAL_REALIZATION trigger):
  profile=prod → NOTIFY_AND_WAIT
  Consumer sees notification with options: accept degraded | trigger dns retry
```

---

## 1.5 Drift Detection and Automated Remediation

Discovery finds VM memory has changed without a DCM request. Shows the full drift → policy → revert flow.

```
Scheduled discovery (PT15M interval):
→ Provider queried for vm-0a1b2c3d
→ Discovered: memory_gb = 16
→ Realized State: memory_gb = 8
→ No Requested State record explains the change

Drift Reconciliation Component:
  field: memory_gb
  realized_value: 8, discovered_value: 16
  change_magnitude: 100% increase → "significant" (standard profile: 10-50% threshold)
  field_criticality: medium (from Resource Type Spec)
  unsanctioned: true → elevate one level → "critical"

Drift record created:
  overall_severity: critical
  unsanctioned: true

Policy Engine evaluates drift record:
  Active drift response policy (standard profile, critical severity, unsanctioned):
    action: ESCALATE → notify platform admin + SRE + owner

Notifications dispatched:
  Owner: "Critical unsanctioned change on vm-0a1b2c3d: memory_gb 8→16"
  Platform Admin: same (urgency: critical)
  SRE on-call: same (via PagerDuty Notification Provider)

If consumer submits: REVERT
→ New request submitted from Realized State (memory_gb: 8)
→ Full governance pipeline → new Requested State → dispatch → revert
→ Next discovery: memory_gb = 8 → drift.resolved event
```

---

## 1.6 Recovery Flow — Dispatch Timeout with NOTIFY_AND_WAIT

Provider does not respond within PT30M. Profile is `prod` → `recovery-notify-and-wait`.

```
T+0:    Request dispatched to EU-WEST-Prod-1
T+30M:  Dispatch timeout fires
        Entity → TIMEOUT_PENDING
        Recovery trigger: DISPATCH_TIMEOUT

Recovery Policy (prod profile → recovery-notify-and-wait):
  action: NOTIFY_AND_WAIT
  deadline: PT4H
  on_deadline_exceeded: ESCALATE

Notifications dispatched:
  Owner: "Request req-001 timed out. Choose how to proceed by T+4H."
  action_url: /api/v1/resources/ent-001/recovery-decisions

Consumer queries:
GET /api/v1/resources/ent-001/recovery-decisions
→ { "trigger": "DISPATCH_TIMEOUT",
    "deadline": "...",
    "available_actions": [
      { "action": "DRIFT_RECONCILE",
        "description": "Let discovery determine actual state" },
      { "action": "DISCARD_AND_REQUEUE",
        "description": "Clean up and retry" }
    ] }

T+45M:  Provider responds (late response) with realized payload
        Entity in TIMEOUT_PENDING → LATE_RESPONSE_RECEIVED fires

Recovery policy for LATE_RESPONSE_RECEIVED (prod → notify-and-wait):
  action: NOTIFY_AND_WAIT (same — human decides whether to accept late work)
  notification updated: "Provider completed after timeout. Accept or discard?"

Consumer POSTs: { "action": "DISCARD_AND_REQUEUE" }
→ Best-effort cleanup sent to provider
→ Entity → FAILED
→ New request cycle created (same entity_uuid)
→ Orphan detection triggered for EU-WEST-Prod-1
```

---

## 1.7 Federation-Routed Request

Consumer in Regional DCM A requests a resource that gets placed on a provider registered with Regional DCM B via Hub DCM.

```
Consumer → Regional DCM A:
  POST /api/v1/requests { resource_type: Compute.VirtualMachine, ... }

Regional DCM A Placement Engine:
  Step 1: Sovereignty filter → local providers all at capacity
  Step 2: Query Hub DCM (Peer DCM provider) for available regional capacity
    → Hub responds: Regional DCM B has EU-WEST-Prod-2 with capacity

Governance Matrix check (Regional DCM A → Hub DCM):
  subject: dcm_peer (Regional DCM A)
  data.classification: internal (assembled payload fields)
  target: dcm_peer (Hub DCM), trust_posture: verified
  → Decision: ALLOW (internal data, verified peer)

Hub DCM routes to Regional DCM B:
  Governance Matrix check (Hub → Regional DCM B):
    same: ALLOW
  Regional DCM B forwards to EU-WEST-Prod-2

Realized State flows back:
  Provider → Regional DCM B → Hub DCM → Regional DCM A
  Each hop: Governance Matrix evaluated
  Final Realized State written to Regional DCM A's Realized Store
  entity_uuid preserved throughout
  provider_entity_id: "vm-eu-west-b-0012"
```

---

## 1.8 Brownfield Ingestion Workflow

An existing VM discovered by a provider that DCM did not provision.

```rego
# Orchestration Flow Policy for brownfield ingestion
package dcm.orchestration.brownfield_ingestion

steps := [
    {"step": 1, "payload_type": "discovery.new_entity_found",
     "policy_handle": "system/ingestion/create-transitional-record"},
    {"step": 2, "payload_type": "ingestion.transitional_created",
     "policy_handle": "system/ingestion/enrich-from-information-providers"},
    {"step": 3, "payload_type": "ingestion.enriched",
     "policy_handle": "system/ingestion/await-operator-promotion"},
    {"step": 4, "payload_type": "ingestion.promotion_approved",
     "policy_handle": "system/ingestion/promote-to-tenant"}
]
ordered := true
```

```
Discovery cycle finds vm-legacy-0001 (no matching Realized State UUID):

Step 1: Event: discovery.new_entity_found
→ INGEST: create Transitional entity in __transitional__ Tenant
  entity_uuid assigned
  lifecycle_state: INGESTION_PENDING
  data_classification: internal (default)

Step 2: Event: ingestion.transitional_created
→ ENRICH: Information Providers queried:
  CMDB (authority: primary):
    business_unit: "Payments Platform"
    cost_center: "PAYM-4421"
    product_owner: "Jane Smith"
    compliance_scope: "PCI-DSS"
  HR System (authority: secondary):
    team: "payments-platform-eng"

Step 3: Event: ingestion.enriched
→ Notification to Platform Admin:
  "Brownfield entity discovered. Review and assign to Tenant."
  action_url: /api/v1/admin/ingestion/ing-001:promote

Step 4: Operator approves:
POST /api/v1/admin/ingestion/ing-001:promote
{ "target_tenant_uuid": "payments-tenant-uuid",
  "compliance_overlay": "pci-dss" }

→ Entity moved from __transitional__ to payments-tenant
→ Intent State created from discovered configuration
→ drift detection activated
→ lifecycle_state: OPERATIONAL
```

---


## 1.9 VM Lifecycle — Static Replace

Re-provision a VM using its existing Requested State payload exactly as it was
dispatched, without re-running layer enrichment or policy evaluation. The result
is a functionally identical resource to the one being replaced.

**When to use Static Replace vs Rehydration:**

| | Static Replace | Rehydration |
|-|---------------|-------------|
| Uses | Original Requested State (the exact dispatch payload) | Original Intent State (what the consumer asked for) |
| Policy re-evaluation | No — payload is used as-is | Yes — full layer enrichment + policy evaluation runs again |
| Standards compliance | Reflects policies at time of original provisioning | Reflects current policies and current layers |
| Use case | Known-good rebuild, emergency restore, hardware swap | Standards refresh, datacenter migration, DR in a new zone |
| AEP endpoint | `POST /api/v1/resources/{entity_uuid}:rehydrate` with `mode: static` | `POST /api/v1/resources/{entity_uuid}:rehydrate` with `mode: intent` |

**Preconditions:**
- Entity exists in DCM with status `OPERATIONAL` or `SUSPENDED`
- A Requested State record exists (all DCM-provisioned resources have one)
- The Service Provider that originally provisioned the resource is still registered and healthy
- The target resource type has not had a breaking schema change (VER-009)

**Workflow:**

```
Consumer: POST /api/v1/resources/{entity_uuid}:rehydrate
  {
    "mode": "static",
    "reason": "Hardware failure on host — replacing on equivalent host in same zone",
    "target_zone": null,             // null = same zone as original
    "retain_entity_uuid": true,      // DCM entity UUID is preserved
    "pre_rehydration_backup": true   // optional: snapshot before proceeding
  }

Response 200 OK — returns Operation:
  {
    "name": "/api/v1/operations/{request_uuid}",
    "done": false,
    "metadata": {
      "stage": "REHYDRATION_INITIATED",
      "resource_uuid": "{entity_uuid}",
      "rehydration_mode": "static",
      "source_requested_state_uuid": "{original_requested_state_uuid}"
    }
  }
```

**What DCM does:**

```
1. Retrieve the most recent Requested State record for entity_uuid
   (this is the exact payload that was dispatched at original provisioning time)

2. Entity enters REHYDRATING lifecycle state
   (incoming traffic should be shifted away at LTM/GTM level before initiating)

3. Decommission the existing resource via the Service Provider
   DELETE /{resource_id} → operator removes the resource
   Decommission callback received → entity status: DECOMMISSIONED (transient)

4. Re-dispatch the original Requested State payload to the Service Provider
   POST / with the original CreateRequest body
   No layer enrichment — payload is used verbatim
   No policy re-evaluation — payload is used verbatim
   NOTE: resource_type_uuid and resource_type_name are still validated
         against the current Resource Type Registry (VER-009 compatibility check)

5. Realization callback received → entity returns to OPERATIONAL
   A new Realized State record is written (linked to the original Requested State)
   The entity_uuid is preserved — external references remain valid

6. Operation reaches done: true
   operation.response contains the realized entity
```

**The key distinction from Rehydration (intent mode):**
Static Replace bypasses the entire layer assembly and policy evaluation pipeline.
It takes the already-assembled, already-approved Requested State and re-executes it.
This makes it deterministic — the result is the same resource on equivalent hardware.
If standards have changed since the original provisioning and you need the resource
to comply with current standards, use `mode: intent` (Rehydration) instead.

**Precaution — IaC parity:**
For Static Replace to be reliable, the application and its data must be on a separate
partition or external storage. The VM's OS and configuration layers are what Static
Replace rebuilds. Application data on the OS volume will be lost. This mirrors the
assumption stated in the PDF architecture: *"Application install and data exist on
separate partition."*

**Orchestration Flow Policy (Static Replace):**

```rego
package dcm.orchestration.static_replace

# Fired when consumer requests static rehydration
steps := [
    {"step": 1, "payload_type": "lifecycle.rehydration_requested",
     "condition": "payload.mode == 'static'",
     "policy_handle": "system/lifecycle/validate-static-replace-preconditions"},
    {"step": 2, "payload_type": "lifecycle.static_replace_validated",
     "policy_handle": "system/provider/decommission-for-replace"},
    {"step": 3, "payload_type": "lifecycle.decommission_confirmed",
     "policy_handle": "system/provider/dispatch-original-requested-state"},
    {"step": 4, "payload_type": "realization.completed",
     "policy_handle": "system/lifecycle/restore-operational-state"},
]
```

**Related use cases:** See Section 1.8 (Brownfield Ingestion) for bringing existing
resources under DCM management. See Section 1.5 (Drift Detection) for reconciling
drift rather than replacing. See the Ingestion Model (doc 13) for the `mode: intent`
Rehydration flow (replaying intent through current policies).

---

## 1.10 VM Lifecycle — In-Place Upgrade (Leapp / IPU Pattern)

Upgrade the OS of a running VM in-place, managed as a DCM lifecycle event.
This preserves the VM entity UUID, Requested State, and Realized State chain —
the VM is the same DCM entity before and after the upgrade.

**Preconditions:**
- Entity is `OPERATIONAL`
- The upgrade automation exists as a registered Process Resource Type
  (e.g., `Process.LeappUpgrade`, `Process.OSUpgrade`)
- A backup or snapshot policy is active for this entity

**Workflow:**

```
Consumer: POST /api/v1/requests
  {
    "catalog_item_uuid": "{leapp-upgrade-catalog-item-uuid}",
    "fields": {
      "target_entity_uuid": "{vm-entity-uuid}",
      "target_os_version": "RHEL 9.4",
      "pre_upgrade_snapshot": true,
      "maintenance_window_uuid": "{mw-uuid}"   // optional
    }
  }
```

**What DCM does:**

```
1. Policy Engine validates:
   - Target entity is OPERATIONAL
   - Target OS version is in the approved versions list (Core Policy)
   - Maintenance window is active (if required by policy)
   - Pre-upgrade snapshot capability exists on the provider

2. Entity enters UPDATING lifecycle state
   (DCM marks entity in maintenance — routing at LTM layer should drain)

3. Process Resource entity created (Process.LeappUpgrade)
   UUID assigned; linked to the VM entity via 'operational' relationship
   Dispatched to the Service Provider as a process execution request

4. Service Provider executes upgrade automation
   Interim status callbacks update the Process Resource entity status
   VM entity remains UPDATING throughout

5. Post-upgrade validation runs:
   - Health checks pass
   - OS version matches target_os_version in the Realized State

6. New Realized State record written for the VM entity
   delta_fields: {os_version: "RHEL 9.4", last_upgraded_at: <timestamp>}
   The Process Resource entity moves to DECOMMISSIONED (process complete)

7. Entity returns to OPERATIONAL
   Maintenance mode released — routing restored
```

**Key DCM properties preserved:**
The VM entity UUID does not change. The Requested State (original intent) does not
change. The upgrade is recorded as a new Realized State record with `delta_fields`
carrying the changed values, linked to the prior Realized State. The full provenance
chain is intact for audit.

---


# Section 2 — Provider Interaction Examples

## 2.1 Service Provider — Full Dispatch Cycle

```
DCM sends dispatch payload to Service Provider endpoint:

POST https://provider.example.com/dispatch
Authorization: mTLS + scoped credential (scope: dispatch, entity: ent-001, ttl: PT15M)
Content-Type: application/json

{
  "dispatch_uuid": "disp-001",
  "entity_uuid": "ent-001",
  "requested_state_uuid": "req-state-001",
  "payload": {
    "resource_type": "Compute.VirtualMachine",
    "fields": {
      "cpu_count": { "value": 4, "provenance": {...} },
      "memory_gb": { "value": 8, "provenance": {...} },
      "os_family": { "value": "rhel", "provenance": {...} },
      "monitoring_endpoint": {
        "value": "https://metrics.internal.prod.example.com",
        "provenance": { "origin": { "source_type": "policy",
                                    "source_uuid": "transform-inject-monitoring" } }
      }
    }
  }
}

Provider naturalizes (DCM → OpenStack Nova):
{
  "server": {
    "name": "ent-001",
    "flavorRef": "m1.xlarge",    # 4 vCPU, 8GB
    "imageRef": "rhel-9.2-latest",
    "metadata": { "dcm_entity_uuid": "ent-001",
                  "dcm_requested_state": "req-state-001",
                  "monitoring_endpoint": "https://metrics..." }
  }
}

OpenStack provisions → returns server object.

Provider denaturalizes (OpenStack → DCM unified):
{
  "realized_state_uuid": "real-001",
  "entity_uuid": "ent-001",
  "corresponding_requested_state_uuid": "req-state-001",
  "source_type": "initial_realization",
  "fields": {
    "cpu_count": { "value": 4, ... },
    "memory_gb": { "value": 8, ... },
    "provider_entity_id": { "value": "vm-0a1b2c3d" },
    "assigned_ip_address": { "value": "10.1.45.23" },
    "hypervisor_host": { "value": "compute-07.eu-west" }
  }
}

DCM receives → writes to Realized Store.
```

## 2.2 Information Provider — Assembly Enrichment

```
During layer assembly Step 2 (layer resolution), DCM queries CMDB Information Provider:

POST https://cmdb.corp.example.com/query
Authorization: mTLS
{
  "query_uuid": "qry-001",
  "data_type": "business_data",
  "lookup_key": { "type": "actor_uuid", "value": "actor-payments-001" }
}

Response:
{
  "data": {
    "business_unit": { "value": "Payments Platform",
                       "confidence": { "band": "very_high", "score": 97 },
                       "authority_level": "primary" },
    "cost_center": { "value": "PAYM-4421",
                     "confidence": { "band": "very_high", "score": 97 } },
    "product_owner": { "value": "Jane Smith",
                       "confidence": { "band": "high", "score": 85 } }
  },
  "data_freshness": "2026-03-15T08:00:00Z"
}

DCM injects into assembled payload as a data layer:
  business_unit.provenance.origin.source_type = "information_provider"
  business_unit.provenance.origin.source_uuid = "cmdb-provider-uuid"
```

## 2.3 Policy Provider Mode 3 — OPA Sidecar Evaluation

```
Assembly reaches Step 5 (pre-placement policy processing):

DCM sends payload to OPA sidecar:
POST http://opa-sidecar:8181/v1/data/dcm/gatekeeper/vm_size_limits
{
  "input": {
    "payload": {
      "type": "request.layers_assembled",
      "fields": { "cpu_count": { "value": 4 }, ... }
    },
    "actor": { "uuid": "actor-001", "roles": ["developer"],
               "tenant_uuid": "payments-uuid" },
    "deployment": { "deployment_posture": "prod",
                    "compliance_domains": ["hipaa"] },
    "entity": null,
    "provider": null
  }
}

OPA response:
{
  "result": {
    "allow": true,
    "deny": [],
    "field_locks": [],
    "warnings": []
  }
}

DCM Policy Engine reads result → allow → pipeline continues.
```

## 2.4 Notification Provider — Relationship Graph Audience

```
Event: entity.decommissioning (VLAN-100 entering DECOMMISSIONING state)

Notification Router:
  1. Load relationship graph for VLAN-100:
     VM-A (AppTeam, attached_to, stake_strength: required)
     VM-B (DevTeam, attached_to, stake_strength: required)
     VM-C (OpsTeam, attached_to, stake_strength: optional)

  2. Resolve audiences:
     VLAN-100 owner (NetworkOps): audience_role = owner
     VM-A owner (AppTeam admin): audience_role = stakeholder
       stakeholder_reason: { via_entity: "VM-A", via_relationship: "attached_to" }
     VM-B owner (DevTeam admin): audience_role = stakeholder
     VM-C owner (OpsTeam admin): audience_role = observer (optional stake)

  3. Per-actor notification envelopes generated (4 total)

POST https://slack-notif.corp.example.com/deliver
{
  "notification_uuid": "notif-001",
  "event_type": "entity.decommissioning",
  "urgency": "high",
  "entity": { "uuid": "vlan-100-uuid", "display_name": "VLAN-100" },
  "audience": {
    "actor_uuid": "appteam-admin-uuid",
    "audience_role": "stakeholder",
    "stakeholder_reason": {
      "via_entity_uuid": "vm-a-uuid",
      "via_entity_display_name": "VM-A (payments-api-server-01)",
      "via_relationship_type": "attached_to"
    }
  },
  "context": { "change_summary": "VLAN-100 decommission initiated" },
  "requires_action": false
}

Slack provider delivers:
  "#payments-platform: ⚠️ VLAN-100 is being decommissioned.
   Your VM 'payments-api-server-01' is attached to it.
   Action required: migrate VM network attachment before decommission completes."
```

---

# Section 3 — Consumer API Examples

## 3.1 Complete Request Lifecycle (API Perspective)

```
# 1. Browse catalog
GET /api/v1/catalog?category=Compute
X-DCM-Tenant: payments-tenant-uuid
Authorization: Bearer <token>

Response: { "catalog_items": [
  { "catalog_item_uuid": "vm-standard-uuid",
    "resource_type": "Compute.VirtualMachine",
    "display_name": "Standard Linux VM",
    "estimated_cost": { "per_hour": 0.32, "currency": "USD" },
    "accreditations": [{ "framework": "hipaa", "status": "active" }]
  }
] }

# 2. Describe catalog item (see schema + constraints)
GET /api/v1/catalog/vm-standard-uuid

Response includes:
  "schema.fields[cpu_count].constraint": { "type": "range", "min": 1, "max": 32 }
  "schema.fields[monitoring_agent].constraint.visibility": "hidden"  # injected by policy

# 3. Submit request
POST /api/v1/requests
{ "catalog_item_uuid": "vm-standard-uuid",
  "fields": { "cpu_count": 4, "memory_gb": 8, "os_family": "rhel",
              "name": "payments-api-server-01" } }

Response 202: { "request_uuid": "req-001", "entity_uuid": "ent-001",
                "status": "ACKNOWLEDGED",
                "status_url": "/api/v1/requests/req-001/status" }

# 4. Poll status (or use webhook)
GET /api/v1/requests/req-001/status

Sequence of responses:
  { "status": "ASSEMBLING" }           # layer assembly running
  { "status": "DISPATCHED" }           # sent to provider
  { "status": "PROVISIONING" }         # provider executing
  { "status": "COMPLETED",
    "resource_url": "/api/v1/resources/ent-001" }

# 5. Get realized resource
GET /api/v1/resources/ent-001

Response:
{ "entity_uuid": "ent-001",
  "lifecycle_state": "OPERATIONAL",
  "drift_status": "clean",
  "fields": {
    "cpu_count": { "value": 4, "confidence": { "band": "very_high" } },
    "assigned_ip_address": { "value": "10.1.45.23",
                              "confidence": { "band": "very_high" } }
  },
  "estimated_cost_per_hour": 0.32 }
```

## 3.2 Provider Update Notification — Consumer Approval Flow

```
# Provider submits auto-scale notification (memory doubled)
POST /api/v1/provider/entities/ent-001/update-notification
Authorization: mTLS (provider cert)
{ "provider_uuid": "eu-west-prod-1-uuid",
  "notification_uuid": "notif-001",
  "notification_type": "auto_scale",
  "changed_fields": {
    "memory_gb": { "previous_value": 8, "new_value": 16,
                   "change_reason": "Auto-scale at 85% utilization" }
  } }

→ DCM evaluates: no pre-authorization policy for this tenant → REQUIRES_CONSUMER_APPROVAL
→ Entity → PENDING_REVIEW
→ Notification to owner: "Provider requests to update memory_gb: 8→16. Approve?"

# Consumer reviews pending notification
GET /api/v1/resources/ent-001/provider-notifications

Response: { "notifications": [{
  "notification_uuid": "notif-001",
  "notification_type": "auto_scale",
  "status": "pending_approval",
  "change_summary": "memory_gb: 8 → 16",
  "change_reason": "Auto-scale at 85% utilization"
}] }

# Consumer approves
POST /api/v1/resources/ent-001/provider-notifications/notif-001:approve
{ "decision": "approve", "reason": "Legitimate auto-scale event" }

Response 202: { "decision": "approve", "realized_state_uuid": "real-002" }

→ New Requested State created (source_type: provider_update)
→ New Realized State snapshot written (memory_gb: 16)
→ Audit: PROVIDER_UPDATE_APPLIED
```

---

# Section 4 — Admin API Examples

## 4.1 Review and Approve Provider Registration

```
# New provider submitted registration
# Platform admin receives notification (urgency: medium)
# "New provider registration pending review: eu-west-prod-1"

# List pending registrations
GET /api/v1/admin/registrations/pending
Authorization: Bearer <platform-admin-token>

Response: { "registrations": [{
  "registration_uuid": "reg-001",
  "provider_type_id": "service_provider",
  "handle": "org/compute/eu-west-prod-1",
  "submitted_at": "2026-03-15T09:00:00Z",
  "validation_status": "passed",        # all 8 automated checks passed
  "sovereignty_zone": "eu-west-sovereign",
  "accreditations": [{ "framework": "hipaa", "type": "baa" }],
  "health_check_status": "healthy",
  "governance_matrix_pre_check": "ALLOW"
}] }

# Admin reviews and approves
POST /api/v1/admin/registrations/reg-001:approve
{ "review_notes": "Certificate verified against corp CA. BAA reviewed and valid." }

Response: { "registration_uuid": "reg-001", "status": "ACTIVE" }

→ Provider enters active registry
→ Governance Matrix re-evaluated with this provider active
→ Notification to provider operator: "Registration approved. Provider UUID: eu-west-prod-1-uuid"
```

## 4.2 Resolve Orphan Candidate

```
# Discovery found vm-legacy-0001 after a timeout-cancelled request

GET /api/v1/admin/orphans
Response: { "orphan_candidates": [{
  "orphan_candidate_uuid": "orp-001",
  "provider_uuid": "eu-west-prod-1-uuid",
  "provider_entity_id": "vm-legacy-0001",
  "suspected_request_uuid": "req-failed-001",
  "resource_type": "Compute.VirtualMachine",
  "discovered_at": "2026-03-15T10:30:00Z",
  "status": "under_review"
}] }

# Admin investigates: vm-legacy-0001 matches the timed-out request
# Decision: adopt into DCM lifecycle under the original requesting tenant

POST /api/v1/admin/orphans/orp-001/resolve
{ "resolution": "adopt_into_dcm",
  "reason": "Confirmed match for timed-out request req-failed-001",
  "target_tenant_uuid": "payments-tenant-uuid" }

Response: { "resolution": "adopt_into_dcm",
            "new_entity_uuid": "ent-001",    # original entity UUID preserved
            "status": "OPERATIONAL" }

→ Entity promoted from orphan candidate to full DCM lifecycle
→ Realized State written
→ drift detection activated
→ original request_uuid marked COMPLETED (late completion)
```

---

# Section 5 — Registration Flow Example

## 5.1 Complete Provider Onboarding — Service Provider

```
# Step 1: Platform admin issues registration token
POST /api/v1/admin/registration-tokens
{ "provider_type_id": "service_provider",
  "expires_in": "PT72H",
  "scope": {
    "provider_handle_pattern": "org/compute/eu-west-*",
    "sovereignty_zone": "eu-west-sovereign",
    "grants_auto_approval": false    # human review still required
  },
  "purpose": "EU-WEST production compute provider onboarding" }

Response: { "token_uuid": "tok-001",
            "token_value": "DCM_REG_abc123...",   # shown once only
            "expires_at": "2026-03-18T09:00:00Z" }

# Step 2: Provider operator submits registration
POST /api/v1/provider/register
X-DCM-Registration-Token: DCM_REG_abc123...
Content-Type: application/json
# (mTLS certificate presented at TLS layer)
{
  "provider_type_id": "service_provider",
  "handle": "org/compute/eu-west-prod-1",
  "display_name": "EU West Production Compute",
  "version": "2.1.0",
  "sovereignty_declaration": {
    "operating_jurisdictions": ["DE", "FR", "NL"],
    "data_residency_zones": ["eu-west-sovereign"]
  },
  "accreditations": [
    { "accreditation_uuid": "acc-hipaa-001", "framework": "hipaa",
      "accreditation_type": "baa", "status": "active" }
  ],
  "capabilities": {
    "resource_types": [
      { "fqn": "Compute.VirtualMachine", "spec_version": "2.1.0",
        "catalog_item_uuid": "vm-standard-uuid" }
    ],
    "cancellation": { "supports_cancellation": true,
                      "cancellation_supported_during": ["DISPATCHED", "PROVISIONING"] },
    "discovery": { "supports_discovery": true, "discovery_method": "api_query" },
    "cost_metadata": { "opex_per_unit_per_hour": 0.28, "currency": "USD" }
  },
  "health_endpoint": "https://eu-west-prod-1.corp.example.com/health",
  "delivery_endpoint": "https://eu-west-prod-1.corp.example.com/dispatch"
}

Response 202: { "registration_uuid": "reg-001", "status": "VALIDATING",
                "token_recognized": true, "auto_approval_eligible": false }

# Step 3: Automated validation runs (8 checks)
# V1: service_provider enabled in prod profile ✓
# V2: Governance Matrix pre-check: ALLOW ✓
# V3: Token valid, matches handle pattern ✓
# V4: mTLS certificate valid, corp CA chain ✓
# V5: Sovereignty declaration complete ✓
# V6: Capability declaration internally consistent ✓
# V7: Health endpoint reachable, returns { "status": "healthy" } ✓
# V8: BAA accreditation present (prod requires accreditation submission) ✓
→ Status → PENDING_APPROVAL

# Step 4: Platform admin notified, reviews, approves (see Section 4.1)
# Step 5: Status → ACTIVE
# Provider enters registry, capacity monitoring begins
```

---

*Document maintained by the DCM Project. For questions or contributions see [GitHub](https://github.com/dcm-project).*

# Section 6 — Provider Type Examples

## 6.1 Storage Provider — State Store Write and Read

A Storage Provider persists and streams DCM internal state. This example shows
the full lifecycle: DCM writing a Requested State record to a PostgreSQL-backed
Storage Provider, followed by the Request Orchestrator reading it back.

**Provider registration excerpt:**

```yaml
storage_provider_registration:
  provider_type: storage_provider
  display_name: "Primary PostgreSQL State Store"
  endpoint: https://pg-state.internal:5432
  storage_sub_type: relational_state
  stores_owned:
    - store_type: requested_state
    - store_type: realized_state
    - store_type: intent_state
  consistency_guarantee: strong          # synchronous write confirmation
  replication:
    strategy: synchronous_replica
    replica_endpoints:
      - https://pg-state-replica-1.internal:5432
      - https://pg-state-replica-2.internal:5432
  provenance_emission: true              # emits audit event on every write
```

**Write: DCM persists a Requested State record**

```
DCM Request Orchestrator
  │
  ▼ POST https://pg-state.internal/api/v1/records
    Authorization: Bearer <dcm-interaction-credential>
    Content-Type: application/json
    {
      "record_type": "requested_state",
      "entity_uuid": "a1b2c3d4-...",
      "tenant_uuid": "t1t2t3t4-...",
      "request_uuid": "r1r2r3r4-...",
      "payload": { ... assembled request payload ... },
      "written_at": "2026-03-31T10:00:00Z"
    }

Provider response:
    {
      "record_uuid": "s1s2s3s4-...",
      "written_at": "2026-03-31T10:00:00.042Z",
      "replicated": true
    }

Provider emits provenance event:
    event_type: storage.record_written
    record_type: requested_state
    record_uuid: s1s2s3s4-...
    entity_uuid: a1b2c3d4-...
    store_provider_uuid: <provider-uuid>
```

**Read: Drift scheduler retrieves Realized State for comparison**

```
DCM Drift Scheduler
  │
  ▼ GET https://pg-state.internal/api/v1/records
    ?entity_uuid=a1b2c3d4-...
    &record_type=realized_state
    &version=latest
    Authorization: Bearer <dcm-interaction-credential>

Provider response:
    {
      "record_uuid": "z9z8z7z6-...",
      "entity_uuid": "a1b2c3d4-...",
      "record_type": "realized_state",
      "payload": { ... realized state snapshot ... },
      "written_at": "2026-03-31T09:55:00Z",
      "supersedes_uuid": "y8y7y6y5-..."
    }
```

---

## 6.2 Auth Provider — OIDC Cutover (GitHub OAuth → Corporate OIDC)

DCM's auth configuration is a versioned artifact. Adding a new Auth Provider
and cutting over is a standard GitOps PR workflow — no downtime.

**Step 1: Register the corporate OIDC provider**

```yaml
# GitOps PR: auth-providers/corporate-oidc-v1.yaml
auth_provider:
  handle: "auth-providers/corporate-oidc"
  version: "1.0.0"
  status: developing               # shadow mode — not yet enforced
  provider_type: oidc
  display_name: "Corporate OIDC (Keycloak)"
  endpoint: https://sso.corp.internal/realms/dcm
  client_id: dcm-control-plane
  client_secret_ref: credential://vault/dcm/oidc-client-secret
  scopes: [openid, profile, email, groups]
  group_claim: "dcm_groups"       # claim containing DCM group memberships
  mfa_required: true
  profile_overlay: standard       # overrides to fsi/sovereign possible
```

**Step 2: Shadow evaluation (parallel run)**

```
Platform Admin: PATCH /api/v1/admin/auth-providers/{uuid}
  { "status": "proposed" }

DCM response:
  Both providers now evaluate all logins in parallel.
  auth.session_created events include shadow_auth_result for comparison.
  Divergences (user authenticated by one provider but not the other)
  are surfaced via governance.auth_shadow_divergence events.

After 72 hours of shadow evaluation:
  Shadow report: 1,847 logins evaluated
    Converged: 1,845 (99.9%)
    Diverged: 2 (both: OIDC rejected due to missing group claim — fixed)
```

**Step 3: Activate and retire GitHub OAuth**

```
Platform Admin: PATCH /api/v1/admin/auth-providers/{oidc-uuid}
  { "status": "active" }

Platform Admin: PATCH /api/v1/admin/auth-providers/{github-uuid}
  { "status": "deprecated" }

DCM response:
  Corporate OIDC: primary, enforced
  GitHub OAuth: accepted for 30 days (configured sunset), then retired
  All existing sessions: revoked (auth.session_revoked × N users)
  Users: re-authenticate on next request
```

---

## 6.3 Credential Provider — SSH Key Issuance After VM Realization

After a VM is realized, the Credential Provider issues an SSH key pair to the
requesting consumer — scoped to that specific entity.

**Flow:**

```
1. Consumer: POST /api/v1/requests
     catalog_item_uuid: <compute-vm-catalog-item>
     fields: { cpu: 4, ram_gb: 16, os: "RHEL 9.4" }

2. Policy evaluation — Transformation policy injects credential requirement:
     fields.credential_requirements:
       - credential_type: ssh_key
         issued_to: requesting_actor
         scope: [ssh_access]
         ttl: P90D             # 90-day key lifetime

3. VM realization completes → entity_uuid: vm-abc123

4. DCM dispatches credential issuance sub-request:
   POST https://vault.internal/api/v1/credentials
     {
       "credential_type": "ssh_key",
       "entity_uuid": "vm-abc123",
       "issued_to_actor_uuid": "actor-xyz",
       "scope": ["ssh_access"],
       "ttl": "P90D"
     }

5. Credential Provider (HashiCorp Vault) response:
     {
       "credential_uuid": "cred-456",
       "public_key": "ssh-ed25519 AAAA...",
       "private_key_ref": "vault://dcm/ssh-keys/cred-456/private",
       "valid_until": "2026-06-30T00:00:00Z"
     }

6. Consumer retrieves credential:
   GET /api/v1/resources/vm-abc123/credentials/cred-456/value
     Authorization: Bearer <consumer-session>

   Response:
     {
       "credential_uuid": "cred-456",
       "credential_type": "ssh_key",
       "public_key": "ssh-ed25519 AAAA...",
       "private_key": "-----BEGIN OPENSSH PRIVATE KEY-----\n...",
       "valid_until": "2026-06-30T00:00:00Z"
     }
   Note: private_key delivered once at retrieval; not stored in DCM.
```

**Rotation at P45D (50% of lifetime):**

```
Credential Provider fires: credential.rotation_due
  credential_uuid: cred-456
  entity_uuid: vm-abc123
  days_until_expiry: 45

DCM Policy: Transformation → auto-issue renewal credential
  New credential_uuid: cred-789
  valid_until: 2026-09-30 (new 90-day window)

credential.rotated event → consumer notified via webhook
Old credential (cred-456): valid_until unchanged, both active during overlap
At valid_until: cred-456 → expired, credential.expired event
```

---

## 6.4 Meta Provider — Three-Tier Web Application Stack

A Meta Provider composes multiple atomic service providers into a single catalog
item. The consumer requests one thing; DCM orchestrates the constituent parts.

**Meta Provider registration (compound service):**

```yaml
meta_provider_registration:
  provider_type: meta_provider
  display_name: "Three-Tier Web App Stack"
  resource_types_composed:
    - fqn: ApplicationStack.WebApp
      version: "1.0.0"
      constituents:
        - component_id: db
          resource_type: Compute.VirtualMachine
          provided_by: external            # DCM selects a compute provider
          depends_on: []
          required_for_delivery: required

        - component_id: app
          resource_type: Compute.VirtualMachine
          provided_by: external
          depends_on: [db]                 # waits for db realization
          inject_from:
            - component: db
              field: realized_fields.primary_ip
              into: fields.db_host
          required_for_delivery: required

        - component_id: lb
          resource_type: Network.LoadBalancer
          provided_by: external
          depends_on: [app]
          inject_from:
            - component: app
              field: realized_fields.primary_ip
              into: fields.backend_pool[0]
          required_for_delivery: required

        - component_id: dns
          resource_type: Network.DNSRecord
          provided_by: external
          depends_on: [lb]
          inject_from:
            - component: lb
              field: realized_fields.vip
              into: fields.record_value
          required_for_delivery: optional  # stack delivered without DNS if it fails
```

**Consumer request:**

```
POST /api/v1/requests
  {
    "catalog_item_uuid": "<webapp-stack-catalog-item>",
    "fields": {
      "app_name": "payments-api",
      "environment": "prod",
      "db_size": "large",
      "app_replicas": 3
    }
  }
```

**What DCM orchestrates (transparent to consumer):**

```
Request 1 → db VM (dispatched immediately)
  Realized: db.primary_ip = 10.0.1.5

Request 2 → app VM (dispatched after db realized)
  fields.db_host = 10.0.1.5 (injected from db realization)
  Realized: app.primary_ip = 10.0.1.10

Request 3 → load balancer (dispatched after app realized)
  fields.backend_pool[0] = 10.0.1.10 (injected)
  Realized: lb.vip = 203.0.113.42

Request 4 → DNS record (dispatched after lb realized)
  fields.record_value = 203.0.113.42 (injected)
  Realized: dns.fqdn = payments-api.corp.example.com

Consumer entity: ApplicationStack.WebApp
  Status: OPERATIONAL
  Constituent entities: [db-uuid, app-uuid, lb-uuid, dns-uuid]
  Logical endpoint: payments-api.corp.example.com
```

---

## 6.5 ITSM Provider — ServiceNow Change Request Lifecycle

An ITSM Provider creates and manages change tickets in ServiceNow as part of
DCM request lifecycle gates. The ITSM ticket becomes the approval gate.

**Provider registration:**

```yaml
itsm_provider_registration:
  provider_type: itsm_provider
  display_name: "ServiceNow — Production ITSM"
  endpoint: https://corp.service-now.com
  itsm_system: servicenow
  supported_actions:
    - create_change_request
    - update_change_request
    - close_change_request
    - get_approval_status
  field_mapping_ref: "itsm-mappings/servicenow-prod-v1.yaml"
  cmdb_ci_type_map:
    Compute.VirtualMachine: cmdb_ci_server
    Network.VLAN: cmdb_ci_network
```

**Lifecycle: DCM request requiring Change Approval:**

```
1. Consumer: POST /api/v1/requests
     fields: { ... VM configuration ... }

2. GateKeeper policy fires (prod tenant + restricted network):
     action: require_itsm_approval
     itsm_provider_uuid: <servicenow-provider-uuid>
     change_type: standard
     risk_level: medium

3. DCM → ITSM Provider: create_change_request
     POST https://corp.service-now.com/api/dcm/v1/changes
     {
       "short_description": "DCM: Provision Compute.VirtualMachine",
       "dcm_request_uuid": "req-abc123",
       "change_type": "standard",
       "risk": "medium",
       "implementation_plan": "DCM automated provisioning",
       "configuration_item": "vm-payments-prod-07",
       "requested_by": "jane.smith@corp.example.com"
     }

   ServiceNow response:
     { "change_number": "CHG0012345", "state": "Assess", "sys_id": "abc123" }

4. DCM request status: AWAITING_EXTERNAL_APPROVAL
   Consumer notified: "Change request CHG0012345 created — awaiting approval"

5. ServiceNow CAB approves → webhook to DCM:
   POST /api/v1/admin/itsm-events
   {
     "itsm_provider_uuid": "<uuid>",
     "change_number": "CHG0012345",
     "dcm_request_uuid": "req-abc123",
     "event_type": "approved",
     "approved_by": "change.manager@corp.example.com",
     "approved_at": "2026-03-31T14:00:00Z"
   }

6. DCM resumes request dispatch → VM provisioned
   ITSM Provider: update_change_request → state: Implement

7. VM realized → ITSM Provider: close_change_request
     { "state": "Closed Complete", "close_notes": "DCM: entity vm-xyz OPERATIONAL" }
```

---

## 6.6 Message Bus Provider — External System Event Bridge

A Message Bus Provider bridges DCM events to external messaging infrastructure.
This example shows DCM publishing entity lifecycle events to an Apache Kafka topic.

**Provider registration:**

```yaml
message_bus_provider_registration:
  provider_type: message_bus_provider
  display_name: "Kafka Event Bridge — Infrastructure Events"
  endpoint: https://kafka-bridge.internal:9092
  protocol: kafka
  subscribed_event_types:
    - entity.lifecycle_changed
    - drift.detected
    - accreditation.status_changed
    - provider.status_changed
  topic_mapping:
    entity.lifecycle_changed: dcm.infrastructure.lifecycle
    drift.detected: dcm.infrastructure.drift
    accreditation.status_changed: dcm.compliance.accreditation
    provider.status_changed: dcm.infrastructure.providers
  delivery_guarantee: at_least_once
  dead_letter_topic: dcm.dlq
```

**Flow: VM reaches OPERATIONAL → Kafka message published:**

```
DCM internal: entity.lifecycle_changed event fires
  entity_uuid: vm-abc123
  resource_type: Compute.VirtualMachine
  from_state: PROVISIONING
  to_state: OPERATIONAL
  tenant_uuid: t1t2...

Message Bus Provider receives event, publishes to Kafka:
  Topic: dcm.infrastructure.lifecycle
  Key: vm-abc123
  Value: {
    "event_type": "entity.lifecycle_changed",
    "entity_uuid": "vm-abc123",
    "resource_type": "Compute.VirtualMachine",
    "from_state": "PROVISIONING",
    "to_state": "OPERATIONAL",
    "tenant_uuid": "t1t2...",
    "timestamp": "2026-03-31T10:05:33Z",
    "dcm_instance_uuid": "<dcm-uuid>"
  }

External consumer (monitoring pipeline) processes message:
  → Updates CMDB record
  → Triggers monitoring agent installation
  → Notifies application team
```

**Dead letter handling:**

```
Kafka publish fails (broker unreachable):
  Message Bus Provider: retry with exponential backoff (3 attempts)
  After threshold: publish to dcm.dlq with failure metadata
  Fire: message_bus.delivery_failed (urgency: medium) → Platform Admin
  DCM: event stored in Message Bus Provider's local queue for replay
```

---

# Section 7 — Policy Type Examples

## 7.1 Transformation Policy — Automatic Data Enrichment

Transformation policies modify the request payload before dispatch. They run
after validation passes and before placement selection.

**Use case:** Auto-inject the required OS image version based on the requested
OS name and the current approved version from an Information Provider.

```rego
package dcm.policy.transform.os_image_injection

import future.keywords.if

# When consumer requests a VM with os_name but no os_image_uuid:
transform if {
    input.payload.resource_type == "Compute.VirtualMachine"
    input.payload.fields.os_name != null
    input.payload.fields.os_image_uuid == null
}

output := {
    "output_type": "transformation",
    "field_injections": [{
        "field": "fields.os_image_uuid",
        "value": data.information_providers.os_registry.current_approved[
            input.payload.fields.os_name
        ],
        "source": "policy/transform/os-image-injection",
        "immutable": true      # consumer cannot override after injection
    }],
    "audit_annotations": [{
        "key": "os_image_injected_at",
        "value": time.now_ns()
    }]
}
```

**In practice:**

```
Consumer submits:
  { "os_name": "RHEL 9", "cpu": 4, "ram_gb": 16 }

After transformation:
  { "os_name": "RHEL 9", "cpu": 4, "ram_gb": 16,
    "os_image_uuid": "img-rhel9-20260315",   ← injected
    "_provenance": {
      "os_image_uuid": {
        "source": "policy/transform/os-image-injection",
        "immutable": true,
        "injected_at": 1743412800000
      }
    }
  }

If consumer tries to override os_image_uuid: Policy Engine rejects with:
  { "code": "FIELD_IMMUTABLE",
    "field": "fields.os_image_uuid",
    "set_by": "policy/transform/os-image-injection" }
```

---

## 7.2 Placement Policy — Provider Selection with Constraints

Placement policies express where a resource should be dispatched. DCM's
Placement Engine evaluates all registered providers against placement policies
plus the Scoring Model.

**Use case:** For a PHI-classified VM, require a provider with HIPAA BAA
accreditation, in Zone A or Zone B, with at least 30% capacity remaining.

```rego
package dcm.policy.placement.phi_vm

import future.keywords.if

placement if {
    input.payload.resource_type == "Compute.VirtualMachine"
    input.payload.data_classification == "phi"
}

output := {
    "output_type": "placement",
    "require": {
        "accreditations": ["hipaa_baa"],          # provider must hold active BAA
        "sovereignty_zones": ["US-EAST", "US-WEST"], # data must stay in US
        "availability_zones": ["zone-a", "zone-b"],
        "minimum_capacity_pct": 30
    },
    "prefer": {
        "accreditations": ["fedramp_moderate"],   # prefer FedRAMP if available
        "availability_zones": ["zone-a"]          # prefer zone-a (lower latency)
    },
    "exclude": {
        "provider_uuids": []                      # no explicit exclusions
    }
}
```

**Placement Engine evaluation:**

```
Candidate providers for Compute.VirtualMachine:
  Provider A: hipaa_baa=✅  zone-a=✅  capacity=45%  fedramp=❌
  Provider B: hipaa_baa=✅  zone-b=✅  capacity=72%  fedramp=✅
  Provider C: hipaa_baa=❌  zone-a=✅  capacity=88%

Filtering (require):
  Provider C: eliminated (no hipaa_baa)

Scoring (prefer + Scoring Model):
  Provider B: higher score (fedramp preferred, higher capacity)
  Provider A: lower score (no fedramp)

Selected: Provider B
  dispatch: CreateRequest → Provider B
  placement_audit:
    policy: placement/phi-vm
    evaluated: [provider-a, provider-b, provider-c]
    eliminated: [provider-c (missing: hipaa_baa)]
    selected: provider-b
    selection_reason: "highest scoring after require filter"
```

---

## 7.3 Shadow Execution — Safe Policy Rollout

Shadow execution lets a new policy run against real traffic without affecting
outcomes. Divergences are surfaced for review before the policy goes active.

**Use case:** Testing a new cost-cap gatekeeper before enforcement.

```yaml
# GitOps PR: policies/cost-cap-v1.yaml
policy:
  handle: "tenant/acme/cost-cap-1000"
  version: "1.0.0"
  status: proposed               # shadow mode — evaluates but does not enforce
  type: gatekeeper
  rules:
    - condition: "cost_estimate.monthly_usd > 1000 AND tenant.uuid == 'acme-uuid'"
      action: gate
      message: "Estimated monthly cost exceeds $1,000 limit for this tenant"
  shadow_target: "tenant/acme/cost-cap-500"   # compare against existing policy
```

**Shadow evaluation in practice:**

```
Request: VM with estimated cost $800/month (tenant: acme)

existing policy (cost-cap-500, active):  GATE — $800 > $500 limit → request blocked
new policy    (cost-cap-1000, shadow):   PASS — $800 < $1,000 limit

Divergence detected:
  policy.shadow_divergence event:
    shadow_policy: cost-cap-1000
    active_policy: cost-cap-500
    divergence_type: active_gated_shadow_passed
    request_uuid: req-abc123
    estimated_cost: 800.00

After 7 days of shadow evaluation:
  Report: 234 requests evaluated
    Converged (both gate):    89 (38%)
    Converged (both pass):   118 (50%)
    Diverged (active gates, shadow passes):  27 (12%)
       ← these are requests that would be UNBLOCKED by the new policy

Platform Admin reviews divergence report:
  Decision: the 27 unblocked requests are legitimate — activate cost-cap-1000
  PATCH /api/v1/admin/policies/{shadow-uuid} → { "status": "active" }
  PATCH /api/v1/admin/policies/{old-uuid}    → { "status": "deprecated" }
```

---

# Section 8 — Lifecycle and Model Examples

## 8.1 Scheduled Request — Deferred Provisioning with Maintenance Window

A new database VM is required, but the network team's policy requires all new
network allocations to happen inside an approved maintenance window.

```
Consumer: POST /api/v1/requests
  {
    "catalog_item_uuid": "<database-vm-catalog-item>",
    "fields": {
      "db_engine": "postgresql",
      "storage_gb": 500,
      "environment": "prod"
    },
    "scheduled_at": null,           # not setting explicit time
    "schedule": {
      "dispatch": "window",
      "window_id": "mw-network-weekly-saturday",   # declared maintenance window
      "not_after": "2026-05-01T00:00:00Z"          # cancel if no window before May
    }
  }

Response 200 — returns Operation:
  {
    "name": "/api/v1/operations/req-abc123",
    "done": false,
    "metadata": {
      "stage": "SCHEDULED",
      "resource_uuid": null,
      "request_uuid": "req-abc123",
      "scheduled_dispatch": "window",
      "window_id": "mw-network-weekly-saturday",
      "next_window_opens": "2026-04-05T02:00:00Z"
    }
  }

At 2026-04-05T02:00:00Z (maintenance window opens):
  DCM dispatches request to Database Service Provider
  Stage advances: SCHEDULED → DISPATCHED → PROVISIONING → OPERATIONAL

If window is missed and 2026-05-01 arrives without dispatch:
  Request → CANCELLED
  reason: "Scheduled dispatch deadline exceeded"
  consumer notified via webhook
```

---

## 8.2 Request Dependency Graph — Three-Tier App with Field Injection

A consumer submits a three-tier application as a coordinated dependency group.
DCM dispatches each tier in order, injecting realized values between tiers.

```
Consumer: POST /api/v1/request-groups
  {
    "group_handle": "payments-v2-deploy",
    "requests": [
      {
        "request_uuid": "req-db-001",         # created beforehand or inline
        "depends_on": [],
        "catalog_item_uuid": "<postgresql-vm>",
        "fields": { "storage_gb": 500, "environment": "prod" }
      },
      {
        "request_uuid": "req-app-001",
        "depends_on": [
          {
            "request_uuid": "req-db-001",
            "wait_for": "realized",
            "inject_fields": [
              {
                "from_field": "realized_fields.primary_ip",
                "to_field": "fields.db_host"
              },
              {
                "from_field": "realized_fields.db_port",
                "to_field": "fields.db_port"
              }
            ]
          }
        ],
        "catalog_item_uuid": "<app-vm>",
        "fields": { "app": "payments-api", "environment": "prod" }
      },
      {
        "request_uuid": "req-lb-001",
        "depends_on": [
          {
            "request_uuid": "req-app-001",
            "wait_for": "realized",
            "inject_fields": [
              {
                "from_field": "realized_fields.primary_ip",
                "to_field": "fields.backend_pool[0]"
              }
            ]
          }
        ],
        "catalog_item_uuid": "<load-balancer>",
        "fields": { "protocol": "HTTPS", "port": 443 }
      }
    ]
  }

Execution sequence:
  T+0s:   req-db-001 dispatched (no dependencies)
  T+45s:  req-db-001 REALIZED → db.primary_ip=10.0.1.5
  T+45s:  req-app-001 dispatched (dependency met; db_host=10.0.1.5 injected)
  T+90s:  req-app-001 REALIZED → app.primary_ip=10.0.1.10
  T+90s:  req-lb-001 dispatched (dependency met; backend_pool[0]=10.0.1.10 injected)
  T+105s: req-lb-001 REALIZED → lb.vip=203.0.113.42

GET /api/v1/request-groups/payments-v2-deploy:
  {
    "group_status": "completed",
    "requests": [
      { "request_uuid": "req-db-001",  "status": "REALIZED", "entity_uuid": "vm-db-..." },
      { "request_uuid": "req-app-001", "status": "REALIZED", "entity_uuid": "vm-app-..." },
      { "request_uuid": "req-lb-001",  "status": "REALIZED", "entity_uuid": "lb-..." }
    ]
  }
```

---

## 8.3 Authority Tier Routing — Tiered Approval for High-Impact Change

DCM routes approval requests based on the authority tier required by matching
policies. This example shows a sovereign-profile decommission routed through
two sequential approval tiers.

**Authority tier definition (organization-configured):**

```yaml
authority_tiers:
  - name: operator
    weight: 10
    description: "Day-to-day platform operator"
  - name: team_lead
    weight: 30
    description: "Technical team lead or senior engineer"
  - name: platform_admin
    weight: 60
    description: "Platform administration team"
  - name: ciso_office
    weight: 100
    description: "CISO office — for high-impact or compliance-relevant changes"
```

**GateKeeper policy requiring CISO approval:**

```rego
package dcm.policy.gate.sovereign_decommission

gate if {
    input.payload.lifecycle_action == "decommission"
    input.payload.data_classification == "restricted"
    input.profile == "sovereign"
}

output := {
    "output_type": "gatekeeper",
    "action": "require_approval",
    "approval_tiers": ["platform_admin", "ciso_office"],   # sequential
    "approval_mode": "sequential",
    "approval_deadline": "P7D",
    "gate_message": "Decommission of restricted-classified resource in sovereign profile requires Platform Admin and CISO approval"
}
```

**Approval flow:**

```
Request: Decommission VM (restricted data, sovereign profile)

GateKeeper fires:
  Request → AWAITING_APPROVAL (tier: platform_admin)
  Notification → Platform Admin audience (urgency: high)

Platform Admin approves:
  POST /api/v1/approvals/{approval-uuid}/approve
  Request → AWAITING_APPROVAL (tier: ciso_office)
  Notification → CISO audience (urgency: high)

CISO approves:
  POST /api/v1/approvals/{approval-uuid}/approve
  Request → DISPATCHED → DECOMMISSIONED

Audit trail:
  gate_evaluation: platform_admin approved by actor-123 at T+2h
  gate_evaluation: ciso_office approved by actor-456 at T+18h
  total_gate_duration: 20 hours
```

---

## 8.4 Rehydration (Intent Mode) — DR Failover to New Datacenter

A business unit needs to redeploy their application in DC2 after DC1 becomes
unavailable. Rehydration replays original intent through current policies —
applying today's standards to the original request.

**Contrast with Static Replace** (Section 1.9): Static Replace re-executes the
Requested State verbatim. Rehydration (intent mode) re-runs the full pipeline
from Intent State — layer assembly, policy evaluation, and placement selection
all run fresh.

```
Consumer: POST /api/v1/resources/{entity_uuid}:rehydrate
  {
    "mode": "intent",
    "reason": "DR failover — DC1 unavailable, deploying to DC2",
    "placement_constraints": {
      "require_zones": ["DC2-ZONE-A", "DC2-ZONE-B"],
      "exclude_zones": ["DC1"]
    },
    "reuse_intent_version": null    # null = use original intent as-is
  }

DCM pipeline:
  1. Retrieve Intent State for entity_uuid
     (the consumer's original request, before any policy processing)

  2. Layer assembly runs fresh against current layers
     (DC2 data center layer, current security baseline, current network config)

  3. Policy evaluation runs fresh
     (current GateKeeper, Validation, Transformation, Placement policies)
     Note: Placement constraint: exclude DC1, require DC2

  4. Placement Engine selects DC2 provider
     (new provider_uuid in the dispatch payload)

  5. Dispatch → DC2 Service Provider
     New entity realized in DC2

  6. Original entity (DC1): status → INDETERMINATE_REALIZATION
     (DC1 resources may still exist — drift reconciliation queued)

  7. New entity (DC2): OPERATIONAL
     entity_uuid: new (original entity retired)
     intent_state links to original intent_uuid (provenance preserved)

Result:
  - New VM in DC2 with DC2 network addressing, current OS image, current policies
  - Full provenance chain: original intent → DC1 realization → DC2 rehydration
  - Audit record: rehydration_reason, original_entity_uuid, new_entity_uuid
```

---

## 8.5 Session Revocation — Security Incident Response

A security team detects that an actor's credentials may have been compromised.
Emergency revocation immediately invalidates all active sessions.

```
Security Team: POST /api/v1/admin/actors/{actor_uuid}/sessions:revoke-all
  {
    "reason": "Suspected credential compromise — security incident INC-2026-042",
    "revocation_scope": "all_sessions",
    "urgency": "emergency"
  }

DCM processes:
  1. All active sessions for actor_uuid → status: revoked
     Sessions affected: 3 (web console, API client, CLI)
     revoked_at: 2026-03-31T16:42:00Z
     revocation_trigger: security_incident
     revoked_by: actor-security-team

  2. Session UUIDs added to Session Revocation Registry
     (fast cache — all API components check this on every request)

  3. Next API request from compromised actor:
     GET /api/v1/resources (any request)
     → 401 Unauthorized
     { "code": "SESSION_REVOKED",
       "message": "Session has been revoked. Please re-authenticate.",
       "revoked_at": "2026-03-31T16:42:00Z" }

  4. Events fired:
     auth.session_revoked × 3 (one per session)
     auth.emergency_revocation (urgency: critical)
     → Security Team notified
     → Audit records written (non-suppressable)

  5. In-flight requests (if any):
     Requests already dispatched to providers: allowed to complete
     (provider callbacks authenticated separately via provider callback credential)
     New requests from this actor: blocked immediately

  6. Actor status → suspended (pending security review)
     actor.suspended event → Platform Admin

Recovery:
  After investigation: actor cleared
  POST /api/v1/admin/actors/{uuid}:unsuspend
  Actor re-authenticates via Auth Provider → new session issued
```

---

## 8.6 Workload Analysis — Brownfield VM Classification

A platform admin runs brownfield ingestion on a newly discovered VM. The
Workload Analysis pipeline classifies it and populates the WorkloadProfile.

```
Discovery Scheduler finds: vm-legacy-0007
  provider_entity_id: vm-legacy-0007
  no matching DCM entity in Realized State

Ingestion record created (status: INGESTED):
  entity_uuid: vm-new-abc123
  tenant_uuid: __transitional__
  resource_type: Compute.VirtualMachine (inferred from provider)

Workload Analysis triggered (WLA-001):
  WorkloadProfile entity created: wla-xyz789
  linked to: vm-new-abc123

Step 2 — Information Providers queried:
  Port scan:
    open ports: [443, 8443, 3000]
  Process list:
    [nginx, node, pm2, postgres-client]
  OS metadata:
    os: RHEL 8.6 / os_eol: 2029-05-31
    mounts: / (50GB), /data (500GB — separate partition)
  MTA assessment:
    containerization_score: 7
    blockers: []
    suggested_target: Platform.KubernetesDeployment
    archetype: web_server

Step 3 — Classification (WLA-001 policy):
  workload_archetype: web_server (confidence: high)
  resource_type_match:
    primary: Compute.VirtualMachine (confidence: high)
    alternative: Platform.Container (confidence: medium — MTA score 7)
  lifecycle_recommendation:
    dcm_lifecycle_model: standard
    rehydration_eligible: true      ← /data on separate partition
    notes: "Containerization candidate per MTA score"

WorkloadProfile → OPERATIONAL:
  GET /api/v1/resources/vm-new-abc123/workload-profile
  {
    "workload_archetype": "web_server",
    "resource_type_match": { "primary": "Compute.VirtualMachine", "confidence": "high" },
    "migration_readiness": { "containerization_score": 7, "suggested_target": "Platform.KubernetesDeployment" },
    "lifecycle_recommendation": { "rehydration_eligible": true }
  }

Ingestion advances:
  INGESTED → ENRICHING (WorkloadProfile confidence: high → no manual review needed)
  Tenant auto-assignment: web_server in /data subnet → Tenant: "payments-platform"
  ENRICHING → PROMOTED → OPERATIONAL
```

---

## 8.7 Scoring Model — Placement Tie-Breaking

Two providers both satisfy all required placement constraints. The Scoring Model
determines which is selected.

**Scenario:** Four providers qualify for a FedRAMP High VM request.

```
Request:
  resource_type: Compute.VirtualMachine
  data_classification: restricted
  required_accreditations: [fedramp_high]
  tenant: payments-platform

Providers qualifying after placement require-filter:
  Provider A: fedramp_high=✅  zone=US-EAST-1a  capacity=60%
  Provider B: fedramp_high=✅  zone=US-EAST-1b  capacity=82%
  Provider C: fedramp_high=✅  zone=US-EAST-1a  capacity=35%
  Provider D: fedramp_high=✅  zone=US-EAST-1b  capacity=91%

Scoring Model evaluation:

Signal 1 — Provider Health Score (weight: 0.30)
  All four: status=healthy, 99.9% uptime
  Scores: A=0.98, B=0.97, C=0.99, D=0.96

Signal 2 — Capacity Headroom (weight: 0.25)
  A=0.60, B=0.82, C=0.35, D=0.91
  (normalized — higher headroom = lower risk)

Signal 3 — Request Risk Score (weight: 0.20)
  Cost estimate: $180/mo — medium risk
  All providers: identical input → same score

Signal 4 — Policy Preference Score (weight: 0.15)
  Placement policy prefers US-EAST-1a:
  A=1.0 (preferred zone), B=0.7, C=1.0, D=0.7

Signal 5 — Accreditation Richness (weight: 0.10)
  Provider B: fedramp_high + iso_27001 + soc2_type2 + verified_P1D → multiplier 1.0 → score: 0.82
  Provider D: fedramp_high + soc2_type2 + verified_P7D → multiplier 0.9 → score: 0.71
  Provider A: fedramp_high + verified_P1D → score: 0.52
  Provider C: fedramp_high + stale_verification → multiplier 0.4 → score: 0.25

Aggregate scores (weighted):
  Provider A: 0.30×0.98 + 0.25×0.60 + 0.20×0.75 + 0.15×1.0 + 0.10×0.52 = 0.792
  Provider B: 0.30×0.97 + 0.25×0.82 + 0.20×0.75 + 0.15×0.7 + 0.10×0.82 = 0.826
  Provider C: 0.30×0.99 + 0.25×0.35 + 0.20×0.75 + 0.15×1.0 + 0.10×0.25 = 0.712
  Provider D: 0.30×0.96 + 0.25×0.91 + 0.20×0.75 + 0.15×0.7 + 0.10×0.71 = 0.822

Selected: Provider B (score: 0.826)
  Note: Provider C's stale accreditation verification cost it the placement
        despite having preferred zone.

Placement audit record:
  evaluated: [A, B, C, D]
  scores: {A: 0.792, B: 0.826, C: 0.712, D: 0.822}
  selected: B
  selection_margin: 0.004 over Provider D
  key_differentiator: "Signal 5 — Provider B richer accreditation portfolio"
```

---

## 8.8 Accreditation Monitor — FedRAMP Status Change Detection

The Accreditation Monitor polls the FedRAMP marketplace and detects that a
provider's authorization has been downgraded mid-cycle.

```
Accreditation Monitor — daily poll cycle:

  Provider: eu-west-prod-1 (Service Provider)
  Accreditation: fedramp_high
  external_registry_id: "FR2024-0042"
  DCM status: active
  last_verified_at: 2026-03-30T03:00:00Z

  Query:
  GET https://marketplace.fedramp.gov/api/products?id=FR2024-0042

  Response:
  {
    "id": "FR2024-0042",
    "status": "In Process",          ← was "Authorized"
    "impact_level": "Moderate",      ← was "High"
    "last_updated": "2026-03-31"
  }

  Mismatch detected:
    DCM record:   status=authorized, impact_level=high
    External:     status=in_process, impact_level=moderate

  ACM-002 applies (not immediate revocation — status is not "Revoked"):
    Accreditation: status → pending_review
    last_verified_at: 2026-03-31T03:00:00Z
    last_result: status_changed

  Events fired:
    accreditation.status_changed (urgency: high)
      from_status: authorized / fedramp_high
      to_status: in_process / fedramp_moderate
      external_source: fedramp_marketplace
      action_taken: pending_review

  Notifications:
    → Platform Admin (urgency: high): "FedRAMP authorization changed for eu-west-prod-1"
    → Compliance Team

  Governance Matrix impact:
    Any new request placing fedramp_high workloads on eu-west-prod-1:
    → Check 3 fails (required accreditation pending_review)
    → New requests: BLOCKED until Platform Admin resolves

  Active resources (already on eu-west-prod-1):
    No immediate action (ACM-002 — not immediate revocation)
    Drift reconciliation queued for governance review
    Provider flagged: ACCREDITATION_PENDING_REVIEW

Platform Admin investigation:
  Confirms: FedRAMP PMO initiated annual re-authorization (routine, not security event)
  Decision: retain accreditation — provider continues under monitoring

  POST /api/v1/admin/accreditations/{uuid}:verify
    { "override_reason": "Confirmed routine re-authorization — PMO contact: john@fedramp.gov" }

  Accreditation: status → active (manual override with audit record)
  new_requests: unblocked
```
