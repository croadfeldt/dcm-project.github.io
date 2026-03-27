---
title: "DCM Flow GUI Specification"
type: docs
weight: 6
---

> **⚠️ Work in Progress**
>
> This specification defines the DCM Flow GUI — the visual interface for managing policies, orchestration flows, and the request lifecycle pipeline. Published to share design direction and invite feedback.

**Version:** 0.1.0-draft
**Status:** Design — Not yet implemented
**Document Type:** Technical Specification
**Related Documents:** [Control Plane Components](../data-model/25-control-plane-components.md) | [OPA Integration Specification](dcm-opa-integration-spec.md) | [Policy Profiles](../data-model/14-policy-profiles.md)

---

## Abstract

The DCM Flow GUI is the visual interface for platform engineers and integrators to compose, test, and manage DCM's data-driven orchestration flows. Because policies ARE the orchestration in DCM, the Flow GUI is fundamentally a **visual policy composer** — it makes the active policy graph visible and editable without requiring direct YAML or Rego authoring.

---

## 1. Core Views

### 1.1 Execution Graph View

The primary view shows the live execution graph: which policies are currently active, which payload types they match, and the sequence in which they fire for a given request type.

```
[request.initiated] ──→ [IntentCapturePolicy] ──→ [request.intent_captured]
                                                          │
                                          ┌───────────────┼───────────────┐
                                          ▼               ▼               ▼
                                    [LayerAssembly]  [CostCheck]   [AuthzCheck]
                                    (system domain)  (tenant domain)(system domain)
                                          │
                                          ▼
                                 [request.layers_assembled]
                                          │
                              ┌───────────┼───────────┐
                              ▼           ▼           ▼
                        [GateKeeper1] [Transform1] [Validate1]
                              └───────────┼───────────┘
                                          ▼
                                 [request.policies_evaluated]
```

**Interactive features:**
- Click any node to see the policy definition, trigger conditions, and current status
- Hover to see firing frequency (how often this policy fires per hour)
- Colour-coded by domain (system=blue, platform=green, tenant=yellow, provider=orange)
- Filter by payload type, domain, policy type, or resource type

### 1.2 Policy Canvas (Static Flow Builder)

For organizations that want to define fixed sequential workflows, the Policy Canvas provides a drag-and-drop interface:

- Drag policy types from the palette onto the canvas
- Connect them with dependency arrows
- Set conditions on each step (fires when X AND Y)
- Set failure behavior (halt, skip, escalate)
- Export as a Policy Group with `concern_type: orchestration_flow` and `ordered: true`

The canvas produces valid DCM YAML that can be committed to the GitOps policy store.

### 1.3 Payload Type Browser

Shows the complete payload type vocabulary. For each type:
- Which policies currently match it
- Sample payload structure
- Which downstream types it can produce
- Historical volume (how many events of this type per day)

### 1.4 Shadow Mode Dashboard

Shows active shadow policies and their evaluation results:
- Policy name and handle
- Shadow vs active comparison: "This policy would have rejected 3 requests in the last 24h"
- One-click promotion to active (if within review period)
- Side-by-side diff of shadow output vs actual outcome

---

## 2. Policy Authoring Interface

The Flow GUI includes a policy authoring interface for creating and editing policies without leaving the browser:

### 2.1 Visual Condition Builder

For simple conditions (field comparisons, role checks, quota checks), a visual condition builder generates valid Rego without requiring Rego knowledge:

```
Trigger: [request.initiated ▼]

Conditions:
  [resource_type ▼] [equals ▼] [Compute.VirtualMachine]    [+ AND]
  [actor.roles ▼] [does not contain ▼] [platform_admin]     [+ AND]
  [payload.fields.cpu_count.value ▼] [greater than ▼] [32]

Action: [Reject ▼]
Rejection message: "CPU count exceeds maximum for this resource type"
```

### 2.2 Rego Editor

For complex policies requiring full Rego expressiveness, the GUI includes an embedded Rego editor with:
- DCM input schema autocomplete
- DCM built-in function reference
- Real-time syntax validation
- Test case runner (against the test harness)

### 2.3 Test Case Management

Each policy can have associated test cases managed in the GUI:
- Create test cases from recent real requests ("save this request as a test case")
- Run test suite before committing a policy change
- View shadow mode results as test case comparisons

---

## 3. Flow Simulation

Platform engineers can simulate a request through the active policy graph without actually submitting it:

```
Simulate: resource_type=Compute.VirtualMachine, tenant=payments, cpu_count=64
  │
  ▼ Execution trace:
  IntentCapturePolicy: PASS
  VmSizeLimits (GateKeeper): REJECT — cpu_count 64 exceeds maximum 32
  ← Request would be rejected at this step
```

Simulation mode is read-only — it uses the current active policies and a synthetic payload. No audit records are written.

---

## 4. Profile and Module Management

### 4.1 Active Profile View

Shows the current active governance composition:
- Active deployment posture (with description of what it enforces)
- Active compliance domains (with summary of key requirements each adds)
- Active recovery posture profile
- Policy count per active profile group

### 4.2 Profile Activation

Change the deployment posture or add/remove compliance domains through the GUI. Produces a profile change request (through the standard request pipeline with appropriate approvals).

---

## 5. Notification Flow View

An extension of the Execution Graph View specific to the Notification Model:
- Shows active notification subscriptions per event type
- Visualizes the relationship graph traversal for a specific entity
- Shows which Notification Providers are active and their delivery health

---

## 6. Integration with OPA

The Flow GUI connects to the OPA integration for:
- Live policy evaluation display (showing OPA decisions in real time)
- Policy testing via the OPA test harness
- Shadow mode result display from OPA shadow evaluations
- Bundle upload and validation

---

*Document maintained by the DCM Project. For questions or contributions see [GitHub](https://github.com/dcm-project).*
