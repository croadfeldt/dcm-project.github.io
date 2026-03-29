---
title: "DCM Examples"
type: docs
weight: 7
---

**Document Status:** 🔄 In Progress
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
    action_url: /api/v1/requests/req-001/approve
    action_deadline: PT24H

Manager approves:
POST /api/v1/requests/req-001/approve
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
  action_url: /api/v1/admin/ingestion/ing-001/promote

Step 4: Operator approves:
POST /api/v1/admin/ingestion/ing-001/promote
{ "target_tenant_uuid": "payments-tenant-uuid",
  "compliance_overlay": "pci-dss" }

→ Entity moved from __transitional__ to payments-tenant
→ Intent State created from discovered configuration
→ drift detection activated
→ lifecycle_state: OPERATIONAL
```

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
POST /api/v1/resources/ent-001/provider-notifications/notif-001/approve
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
POST /api/v1/admin/registrations/reg-001/approve
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
