---
title: "Demo Script"
type: docs
---

# Summit Demo Script — DCM Example Implementation #1

Three demonstration scenarios for Red Hat Summit 2026.
Each shows a different DCM architectural capability.

---

## Demo 1: Intelligent Placement (March 1 MVP target)

**Persona:** CTO  
**Story:** Application team requests a VM. DCM automatically enforces zone placement policy
using OPA/Rego. The consumer specifies a tier; DCM ensures zones match.

**What it shows:** Policy-driven pipeline, OPA Rego enforcement, automated placement scoring.

### Setup
```bash
# Ensure VM provider and policy engine are running
oc get pods -n dcm-summit-demo | grep -E 'provider-vm|policy-engine|placement'

# Confirm tier-region policy is active (not shadow)
curl -H "Authorization: Bearer $TOKEN" $DCM_URL/api/v1/admin/policies | jq '.items[] | select(.name=="tier-region-policy")'
```

### Demo Flow

**Step 1 — Browse catalog in RHDH**
- Open RHDH URL in browser
- Login as `alice / demo-password`
- Navigate to: DCM Service Catalog
- Show: "Standard Virtual Machine" catalog item with cost estimate

**Step 2 — Submit valid request (t1 tier, us-east-1 zones)**
```bash
curl -X POST $DCM_URL/api/v1/requests \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "catalog_item_uuid": "00000000-0000-0000-0003-000000000001",
    "fields": {
      "name": "demo-vm-01",
      "cpu": 8,
      "ram_gb": 16,
      "environment": "prod",
      "tier": "t1"
    }
  }'
# → Returns: {"operation_uuid": "...", "done": false}
```

**Step 3 — Watch the pipeline**
```bash
# Poll operation status (or show in RHDH)
curl -H "Authorization: Bearer $ALICE_TOKEN" $DCM_URL/api/v1/operations/$OP_UUID
# Progresses: INITIATED → ASSEMBLING → POLICY_EVALUATION → PLACEMENT → DISPATCHED → OPERATIONAL
```

**Step 4 — Show the policy enforcing (submit invalid tier)**
```bash
# t2 tier requests us-west-* zones — sending t1 request to t2 zone should fail
curl -X POST $DCM_URL/api/v1/requests \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -d '{
    "catalog_item_uuid": "00000000-0000-0000-0003-000000000001",
    "fields": {
      "name": "demo-vm-bad",
      "cpu": 4,
      "ram_gb": 8,
      "environment": "dev",
      "tier": "t1",
      "network_zone": "us-west-1"
    }
  }'
# → Denied: tier-region-policy returns DENY
# Show: audit record with denial reason
```

**Talking points:**
- The policy (tier-region.rego) is a Git artifact — versioned, testable, auditable
- Shadow mode lets new policies run against real traffic before enforcing
- The consumer specified only `tier`; the zones are enforced automatically
- Every decision is in the audit trail with the exact policy UUID and reason

---

## Demo 2: Datacenter Rehydration (April 1 target)

**Persona:** CIO  
**Story:** Simulate a DC loss scenario. Trigger rehydration of all resources from declared state.

**What it shows:** Four states model (Intent/Requested/Realized/Discovered), rehydration trigger,
Meta Provider orchestrating multiple child providers.

### Setup
```bash
# Ensure webapp meta provider is running
oc get pods -n dcm-summit-demo | grep webapp-meta

# Pre-provision a "webapp" to demonstrate rehydrating
curl -X POST $DCM_URL/api/v1/requests \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -d '{
    "catalog_item_uuid": "00000000-0000-0000-0003-000000000003",
    "fields": {"app_name": "payments-app", "environment": "prod", "tier": "t1"}
  }'
# Wait for OPERATIONAL, then simulate "loss"
```

### Demo Flow

**Step 1 — Show existing realized state**
```bash
curl -H "Authorization: Bearer $ALICE_TOKEN" $DCM_URL/api/v1/resources | jq '.items[] | {name: .fields.name, state: .lifecycle_state}'
```

**Step 2 — Simulate DC loss (decommission resources)**
```bash
# Mark resources as FAILED (simulate discovery reporting loss)
curl -X POST $DCM_URL/api/v1/resources/$ENTITY_UUID:mark-failed \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"reason": "simulated_dc_loss"}'
```

**Step 3 — Trigger rehydration from Intent State**
```bash
curl -X POST $DCM_URL/api/v1/resources/$ENTITY_UUID:rehydrate \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"mode": "intent", "reason": "dc_loss_recovery"}'
# → DCM replays original Intent through current policies
# → Meta Provider re-provisions: Network Port → VM → OCP Cluster (in sequence)
```

**Talking points:**
- Intent State is immutable and stored in DCM's database (append-only, never modified) — survives the DC loss
- Rehydration replays the original intent through *current* policies (not old ones)
- The Meta Provider handles the sequencing automatically
- Full audit trail shows before/after states

---

## Demo 3: Application as a Service (April 1 target)

**Persona:** Application Owner  
**Story:** Developer requests a full web application environment. One catalog item → three providers coordinated automatically.

### Demo Flow

```bash
# Single request → Meta Provider orchestrates VM + Network + OCP Cluster
curl -X POST $DCM_URL/api/v1/requests \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -d '{
    "catalog_item_uuid": "00000000-0000-0000-0003-000000000003",
    "fields": {
      "app_name": "summit-demo-app",
      "environment": "dev",
      "tier": "demo",
      "vm_size": "medium",
      "ocp_worker_count": 3
    }
  }'
```

Watch in RHDH as the Meta Provider:
1. Allocates network port (network-provider)
2. Provisions app server VM (vm-provider) — depends on step 1
3. Provisions OCP cluster (ocp-cluster-provider) — depends on step 1

**Talking points:**
- Consumer specified 4 fields; DCM assembled ~40 fields from layers + policies
- Rollback: if OCP cluster fails, VM and network port are automatically decommissioned
- The Meta Provider is itself a standard DCM provider — composability is architectural
