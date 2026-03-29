---
title: "DCM Flow GUI Specification"
type: docs
weight: 8
---

> **📋 Draft**
>
> This specification defines the DCM Flow GUI — the visual interface for platform engineers to compose, test, simulate, and manage DCM's policy-driven orchestration. All views, data contracts, API endpoints, and component structure are specified. Feedback and contributions welcome via [GitHub Issues](https://github.com/dcm-project/issues).

**Version:** 0.1.0-draft
**Status:** Draft — Ready for implementation feedback
**Document Type:** Technical Specification
**Related Documents:** [Foundational Abstractions](../data-model/00-foundations.md) | [Control Plane Components](../data-model/25-control-plane-components.md) | [OPA Integration Specification](dcm-opa-integration-spec.md) | [Policy Profiles](../data-model/14-policy-profiles.md) | [Policy Contract](../data-model/B-policy-contract.md) | [Consumer API](consumer-api-spec.md) | [Admin API](dcm-admin-api-spec.md)

---

## Abstract

The DCM Flow GUI is the visual interface for platform engineers to compose, test, and manage DCM's data-driven orchestration. Because policies ARE the orchestration in DCM, the Flow GUI is fundamentally a **visual policy composer** — it makes the active policy graph visible and editable without requiring direct YAML or Rego authoring.

The Flow GUI is a **platform engineer tool**, not a consumer tool. It operates with platform admin or policy author role permissions. Consumers interact with DCM through the Consumer API and Web UI, not through the Flow GUI.

---

## 1. Architecture and Component Structure

### 1.1 Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Browser (SPA)                            │
│   Flow GUI Application — React single-page application          │
│   Authentication: Bearer token (same session as Consumer API)   │
└──────────────────────────────┬──────────────────────────────────┘
                               │ HTTPS REST
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Flow GUI Service                               │
│   Purpose: aggregate data for Flow GUI views                     │
│   Deployed alongside DCM control plane                           │
│   Authentication: validates Bearer token; requires policy_author │
│                   or platform_admin role                         │
│                                                                  │
│   Reads from:                                                    │
│     Policy Engine  — live graph, firing frequency                │
│     GitOps stores  — policy artifacts, PR status                 │
│     Observability  — event volumes, error rates                  │
│     OPA sidecar    — test harness, shadow results                │
│   Writes via:                                                    │
│     Git API        — create PRs for policy changes               │
│     Admin API      — shadow mode promotion, profile changes      │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Authentication and Authorization

The Flow GUI uses the same session token as the Consumer API. Required roles:

| Role | Access |
|------|--------|
| `platform_admin` | Full read/write — all views, all authoring, profile management |
| `policy_author` | Read all views; author policies in assigned domains; cannot manage profiles or promote shadow policies |
| `platform_observer` | Read-only — all views; no authoring; no simulation write |

### 1.3 Base URL

```
https://{dcm-instance}/flow/api/v1/
```

Distinct from the Consumer API base URL to make routing and access control clear.

---

## 2. The Execution Graph View

### 2.1 What It Shows

The primary view shows the live execution graph: which policies are active, which payload types they match, how they compose with each other, and their firing frequency. This is the "live map" of DCM's orchestration state.

```
[request.initiated] ──→ [IntentCapturePolicy] ──→ [request.intent_captured]
                                                          │
                                          ┌───────────────┼───────────────┐
                                          ▼               ▼               ▼
                                  [LayerAssembly]   [CostCheck]   [AuthzCheck]
                                  (system/blue)     (tenant/yellow)(system/blue)
                                          │
                                          ▼
                               [request.layers_assembled]
                                          │
                              ┌───────────┼───────────┐
                              ▼           ▼            ▼
                      [GateKeeper:      [Transform:   [GovMatrix:
                       vm-size-limits]  inject-mon.]  phi-boundary]
                              └───────────┼───────────┘
                                          ▼
                               [request.policies_evaluated]
```

**Visual conventions:**
- **Node color by domain:** system=blue, platform=green, tenant=yellow, resource_type=purple
- **Node shape by policy type:** GateKeeper=shield, Transformation=gear, Recovery=arrow, Governance Matrix=lock, Orchestration Flow=rectangle
- **Edge thickness:** proportional to firing frequency (last 1h)
- **Edge color:** green=allow path, red=deny path, amber=conditional
- **Node badge:** shadow mode indicator (S), deprecated indicator (D)

### 2.2 API — Fetch Execution Graph

```
GET /flow/api/v1/graph

Query parameters:
  payload_type=<type>      filter to policies matching this payload type
  resource_type=<fqn>      filter to policies applicable to this resource type
  domain=<domain>          filter by policy domain
  policy_type=<type>       filter by policy type
  tenant_uuid=<uuid>       include tenant-domain policies for this Tenant

Response 200:
{
  "graph": {
    "nodes": [
      {
        "node_id": "<uuid>",                 # policy_uuid
        "label": "vm-size-limits",
        "policy_type": "gatekeeper",
        "domain": "tenant",
        "tenant_uuid": "<uuid>",
        "handle": "tenant/payments/gatekeeper/vm-size-limits",
        "version": "1.2.0",
        "status": "active",
        "shadow_mode": false,
        "match_payload_types": ["request.layers_assembled"],
        "match_conditions_summary": "cpu_count > 32 OR memory_gb > 256",
        "firing_frequency": {
          "last_1h": 3,
          "last_24h": 47,
          "last_7d": 312
        },
        "deny_rate_24h": 0.06             # 6% of evaluations resulted in deny
      }
    ],
    "edges": [
      {
        "from_payload_type": "request.layers_assembled",
        "to_node_id": "<policy_uuid>",
        "edge_type": "policy_fires_on",
        "volume_24h": 47
      },
      {
        "from_node_id": "<policy_uuid>",
        "to_payload_type": "request.policies_evaluated",
        "edge_type": "produces",
        "condition": "on_allow"
      }
    ]
  },
  "payload_types": [
    {
      "payload_type": "request.layers_assembled",
      "volume_24h": 789,
      "active_policy_count": 4
    }
  ],
  "last_updated": "<ISO 8601>"
}
```

### 2.3 API — Get Policy Node Detail

```
GET /flow/api/v1/graph/nodes/{policy_uuid}

Response 200:
{
  "policy_uuid": "<uuid>",
  "handle": "tenant/payments/gatekeeper/vm-size-limits",
  "version": "1.2.0",
  "policy_type": "gatekeeper",
  "domain": "tenant",
  "concern_type": "security",
  "enforcement": "soft",
  "status": "active",

  "match_conditions": {
    "payload_type": "request.layers_assembled",
    "conditions": [
      { "field": "payload.fields.cpu_count.value", "operator": "gt", "value": 32 }
    ]
  },

  "output_schema": {
    "decision": "deny",
    "reason_template": "cpu_count {value} exceeds maximum 32"
  },

  "firing_history": [
    { "timestamp": "<ISO 8601>", "result": "deny", "request_uuid": "<uuid>" },
    { "timestamp": "<ISO 8601>", "result": "allow", "request_uuid": "<uuid>" }
  ],

  "git_path": "policy-store/tenant/payments/gatekeeper/vm-size-limits/v1.2.0.yaml",
  "pr_url": null,             # null if no pending PR; URL if change in review

  "compliance_basis": null,
  "review_required_before": null,

  "test_suite": {
    "test_count": 3,
    "last_run": "<ISO 8601>",
    "result": "pass"
  }
}
```

---

## 3. Policy Canvas — Static Flow Builder

### 3.1 Interaction Model

The Policy Canvas is a drag-and-drop interface for building named Orchestration Flow Policies (Level 1 orchestration — named workflow artifacts). The output is a valid DCM Orchestration Flow Policy YAML committed via a Git PR.

**Key constraint:** The canvas never writes directly to the Policy Store. All saves generate a Git PR. The PR goes through the standard review process. Shadow mode activates automatically when the PR is created — the proposed workflow evaluates against real traffic in shadow mode until merged.

### 3.2 Canvas Operations

| Operation | Description | Backend action |
|-----------|-------------|----------------|
| Drag payload type node | Add a workflow step | Canvas state update (local) |
| Connect nodes | Declare step sequence | Canvas state update (local) |
| Set step conditions | Add conditions to a step | Canvas state update (local) |
| Set failure behavior | halt / skip / escalate | Canvas state update (local) |
| Preview YAML | Show generated policy YAML | `GET /flow/api/v1/canvas/preview` |
| Save as PR | Create Git PR with policy YAML | `POST /flow/api/v1/canvas/save` |
| Load existing | Load an existing flow policy | `GET /flow/api/v1/policies/{policy_uuid}/canvas` |

### 3.3 API — Preview Canvas as YAML

```
POST /flow/api/v1/canvas/preview

Request body:
{
  "handle": "org/orchestration/vm-provisioning-flow",
  "concern_type": "orchestration_flow",
  "ordered": true,
  "steps": [
    {
      "step": 1,
      "payload_type": "request.initiated",
      "policy_handle": "system/orchestration/capture-intent",
      "on_fail": "halt"
    },
    {
      "step": 2,
      "payload_type": "request.intent_captured",
      "policy_handle": "system/orchestration/assemble-layers",
      "on_fail": "halt"
    },
    {
      "step": 3,
      "payload_type": "request.layers_assembled",
      "policy_handle": "system/orchestration/run-placement",
      "on_fail": "halt",
      "condition": "not payload.placement_complete"
    }
  ],
  "applicable_resource_types": ["Compute.VirtualMachine"]
}

Response 200:
{
  "yaml": "# Generated by DCM Flow GUI\n# Handle: org/orchestration/vm-provisioning-flow\n...",
  "rego": "package dcm.orchestration.vm_provisioning_flow\n...",
  "validation": {
    "valid": true,
    "warnings": ["Step 3 condition references 'payload.placement_complete' which is not in the standard payload vocabulary"]
  }
}
```

### 3.4 API — Save Canvas as Git PR

```
POST /flow/api/v1/canvas/save

Request body:
{
  "canvas_definition": { ... },  # same as preview request
  "commit_message": "Add VM provisioning orchestration flow",
  "pr_title": "feat(orchestration): VM provisioning named workflow",
  "pr_description": "Defines explicit sequence for VM provisioning requests",
  "target_branch": "main",
  "shadow_mode": true            # proposed status — shadow evaluates before merge
}

Response 201 Created:
{
  "pr_uuid": "<uuid>",
  "pr_url": "https://git.corp.example.com/dcm-policies/pulls/142",
  "pr_status": "open",
  "shadow_mode_activated": true,
  "policy_handle": "org/orchestration/vm-provisioning-flow",
  "policy_status": "proposed"   # active in shadow mode; not yet enforced
}
```

### 3.5 API — Load Existing Flow Policy into Canvas

```
GET /flow/api/v1/policies/{policy_uuid}/canvas

Response 200:
{
  "canvas_definition": {
    "handle": "...",
    "ordered": true,
    "steps": [...]
  },
  "yaml": "...",
  "policy_uuid": "<uuid>",
  "version": "1.2.0",
  "git_path": "..."
}
```

---

## 4. Policy Authoring Interface

### 4.1 Visual Condition Builder

For simple policies (field comparisons, role checks, quota checks), a visual condition builder generates valid Rego without requiring Rego knowledge.

**Supported condition types:**

| Field type | Operators | Example |
|-----------|-----------|---------|
| Numeric field | equals, not_equals, gt, gte, lt, lte, in_range | `cpu_count > 32` |
| String field | equals, not_equals, in_list, matches_regex | `os_family in [rhel, ubuntu-lts]` |
| List field | contains, does_not_contain | `actor.roles contains platform_admin` |
| Boolean field | is_true, is_false | `payload.fields.production_workload = true` |
| Existence | exists, does_not_exist | `payload.fields.cost_center exists` |

### 4.2 API — Generate Policy from Visual Conditions

```
POST /flow/api/v1/policies/generate

Request body:
{
  "policy_type": "gatekeeper",
  "handle": "tenant/payments/gatekeeper/vm-size-limits",
  "concern_type": "security",
  "domain": "tenant",
  "tenant_uuid": "<uuid>",
  "enforcement": "soft",
  "match": {
    "payload_type": "request.layers_assembled",
    "resource_type": "Compute.VirtualMachine",
    "conditions": [
      { "field": "payload.fields.cpu_count.value", "operator": "gt", "value": 32 }
    ],
    "condition_logic": "any"
  },
  "output": {
    "decision": "deny",
    "reason_template": "cpu_count {payload.fields.cpu_count.value} exceeds maximum 32 for this Tenant"
  },
  "audit_on": ["DENY"],
  "notification_on": ["DENY"]
}

Response 200:
{
  "yaml": "# DCM GateKeeper Policy\n...",
  "rego": "package dcm.gatekeeper.vm_size_limits\n\ndeny contains reason if {\n    input.payload.type == \"request.layers_assembled\"\n    input.payload.fields.cpu_count.value > 32\n    reason := sprintf(\"cpu_count %d exceeds maximum 32\", [input.payload.fields.cpu_count.value])\n}\n",
  "validation": {
    "valid": true,
    "warnings": []
  }
}
```

### 4.3 Rego Editor

For complex policies requiring full Rego expressiveness, the GUI includes an embedded Rego editor with:

- **Input schema autocomplete:** all valid `input.*` paths from the DCM input document schema
- **DCM built-in reference:** sidebar showing available built-in functions and constants
- **Real-time syntax validation:** calls OPA `/v1/compile` to validate without evaluation
- **Test case runner:** executes the policy against saved test cases

### 4.4 API — Validate Rego

```
POST /flow/api/v1/policies/validate-rego

Request body:
{
  "rego": "package dcm.gatekeeper.example\n\ndeny contains reason if {\n    input.payload.fields.cpu_count.value > 32\n    reason := \"too many CPUs\"\n}\n",
  "policy_type": "gatekeeper"
}

Response 200:
{
  "valid": true,
  "warnings": [],
  "errors": [],
  "output_schema_match": true,   # output matches declared policy_type schema
  "input_paths_used": [
    "input.payload.fields.cpu_count.value"
  ],
  "input_paths_unknown": []      # paths that don't exist in the input document schema
}

Response 200 (with errors):
{
  "valid": false,
  "errors": [
    { "line": 4, "column": 5, "message": "undefined variable: reason_text" }
  ]
}
```

### 4.5 Test Case Management

```
# List test cases for a policy
GET /flow/api/v1/policies/{policy_uuid}/tests

Response 200:
{
  "test_cases": [
    {
      "test_uuid": "<uuid>",
      "name": "Reject oversized VM",
      "input_payload": { "payload": { "type": "request.layers_assembled", "fields": { "cpu_count": { "value": 64 } } } },
      "expected_output": { "deny": ["cpu_count 64 exceeds maximum 32"] },
      "last_result": "pass",
      "last_run": "<ISO 8601>"
    }
  ]
}

# Create test case from a real recent request
POST /flow/api/v1/policies/{policy_uuid}/tests/from-request
{
  "request_uuid": "<uuid>",      # saves that request's payload as a test case
  "expected_output": { "deny": [] },
  "test_name": "Normal VM request — should allow"
}

# Run all test cases
POST /flow/api/v1/policies/{policy_uuid}/tests/run

Response 200:
{
  "run_uuid": "<uuid>",
  "result": "pass",             # pass | fail | error
  "test_results": [
    {
      "test_uuid": "<uuid>",
      "name": "Reject oversized VM",
      "result": "pass",
      "actual_output": { "deny": ["cpu_count 64 exceeds maximum 32"] },
      "expected_output": { "deny": ["cpu_count 64 exceeds maximum 32"] }
    }
  ],
  "duration_ms": 42
}
```

---

## 5. Flow Simulation

### 5.1 Simulation Model

Platform engineers simulate a synthetic request through the active policy engine without creating real state. The simulation runs against the live Policy Engine with a caller-constructed payload. No audit records are written. No Requested State is created.

### 5.2 API — Simulate Request

```
POST /flow/api/v1/simulate

Request body:
{
  "catalog_item_uuid": "<uuid>",     # optional; used to seed field schema
  "resource_type": "Compute.VirtualMachine",
  "tenant_uuid": "<uuid>",
  "synthetic_fields": {
    "cpu_count": 64,
    "memory_gb": 128,
    "os_family": "rhel"
  },
  "synthetic_actor": {
    "roles": ["developer"],
    "group_memberships": ["payments-team"]
  },
  "include_policy_types": ["gatekeeper", "transformation", "governance_matrix"]
}

Response 200:
{
  "simulation_uuid": "<uuid>",
  "result": "rejected",            # allowed | rejected | degraded
  "terminal_reason": "GateKeeper policy rejected at step request.layers_assembled",

  "execution_trace": [
    {
      "step": 1,
      "payload_type": "request.initiated",
      "policies_evaluated": [],
      "result": "pass",
      "duration_ms": 2
    },
    {
      "step": 2,
      "payload_type": "request.intent_captured",
      "policies_evaluated": [],
      "result": "pass",
      "duration_ms": 1
    },
    {
      "step": 3,
      "payload_type": "request.layers_assembled",
      "policies_evaluated": [
        {
          "policy_uuid": "<uuid>",
          "policy_handle": "tenant/payments/gatekeeper/vm-size-limits",
          "policy_type": "gatekeeper",
          "result": "deny",
          "reason": "cpu_count 64 exceeds maximum 32",
          "duration_ms": 8
        },
        {
          "policy_uuid": "<uuid>",
          "policy_handle": "org/transformation/inject-monitoring",
          "policy_type": "transformation",
          "result": "applied",
          "mutations": [
            { "field": "fields.monitoring_endpoint", "operation": "set", "value": "https://metrics..." }
          ],
          "duration_ms": 3
        }
      ],
      "result": "rejected",
      "terminal": true
    }
  ],

  "assembled_payload_snapshot": {
    "fields": {
      "cpu_count": { "value": 64, "provenance": { "origin": { "source_type": "consumer_request" } } },
      "monitoring_endpoint": { "value": "https://metrics...", "provenance": { "origin": { "source_type": "policy" } } }
    }
  },

  "cost_estimate": {
    "total_per_hour": 1.28,
    "currency": "USD",
    "note": "Estimated assuming request would have been allowed"
  }
}
```

### 5.3 Simulation vs Shadow Mode

| | Simulation | Shadow Mode |
|-|-----------|------------|
| Trigger | Manual, synthetic payload | Automatic on real traffic |
| Audit record | Never written | Written to Validation Store |
| Policy status | Evaluates active policies | Evaluates proposed policies |
| Use case | "What if?" exploration | Pre-activation validation |
| Real data | No | Yes |

---

## 6. Shadow Mode Dashboard

### 6.1 What It Shows

Shows all proposed policies currently in shadow mode and their evaluation results against real traffic.

### 6.2 API — List Shadow Policies

```
GET /flow/api/v1/shadow

Response 200:
{
  "shadow_policies": [
    {
      "policy_uuid": "<uuid>",
      "handle": "tenant/payments/gatekeeper/new-cost-check",
      "policy_type": "gatekeeper",
      "status": "proposed",
      "shadow_since": "<ISO 8601>",
      "pr_url": "https://git.corp.example.com/dcm-policies/pulls/143",
      "pr_status": "open",

      "shadow_results_24h": {
        "total_evaluations": 156,
        "would_have_denied": 4,
        "would_have_allowed": 152,
        "divergence_from_active": 4,
        "divergence_rate": 0.026
      }
    }
  ]
}
```

### 6.3 API — Shadow Policy Detail with Divergence Cases

```
GET /flow/api/v1/shadow/{policy_uuid}

Response 200:
{
  "policy_uuid": "<uuid>",
  "shadow_results_24h": {
    "total_evaluations": 156,
    "divergence_cases": [
      {
        "request_uuid": "<uuid>",
        "timestamp": "<ISO 8601>",
        "active_result": "allow",
        "shadow_result": "deny",
        "shadow_reason": "Estimated cost $480/month exceeds budget ceiling $300/month",
        "requester": "Bob Smith",
        "resource_type": "Compute.VirtualMachine"
      }
    ]
  }
}
```

### 6.4 API — Promote Shadow Policy to Active

```
POST /flow/api/v1/shadow/{policy_uuid}/promote
{
  "reason": "Shadow results reviewed — divergence rate acceptable; promoting to active"
}

Response 202 Accepted:
{
  "policy_uuid": "<uuid>",
  "status": "active",
  "pr_action": "approved_and_merged",
  "promoted_at": "<ISO 8601>"
}

Response 403 Forbidden:
{
  "error": "insufficient_role",
  "reason": "Policy promotion requires platform_admin role"
}
```

---

## 7. Profile and Governance Management

### 7.1 Active Profile View

```
GET /flow/api/v1/profile

Response 200:
{
  "deployment_posture": {
    "name": "prod",
    "description": "Production — full zero trust, dual approval for high-trust providers, human review for all registrations",
    "active_policy_groups": 12,
    "hard_constraints": [
      "sovereign/classified data never crosses any boundary",
      "All providers require at least self_declared accreditation"
    ]
  },
  "compliance_domains": [
    {
      "domain": "hipaa",
      "description": "HIPAA/HITECH compliance — PHI classification, BAA requirements, minimum necessary principle",
      "active_policy_groups": 4,
      "key_requirements": ["PHI requires BAA accreditation", "All PHI interactions audited", "No PHI export without regulatory cert"]
    }
  ],
  "recovery_posture": "notify-and-wait",
  "zero_trust_posture": "full",
  "total_active_policies": 47
}
```

### 7.2 Payload Type Browser

```
GET /flow/api/v1/payload-types

Response 200:
{
  "payload_types": [
    {
      "payload_type": "request.layers_assembled",
      "description": "Layer assembly complete — payload enriched with all layer fields",
      "volume_24h": 789,
      "active_policy_count": 4,
      "sample_payload": {
        "type": "request.layers_assembled",
        "fields": {
          "cpu_count": { "value": 4 },
          "memory_gb": { "value": 8 }
        }
      },
      "downstream_payload_types": ["request.policies_evaluated", "recovery.gatekeeper_denied"]
    }
  ]
}
```

---

## 8. Notification Flow View

### 8.1 API — Notification Flow for an Entity

```
GET /flow/api/v1/notifications/flow/{entity_uuid}

Response 200:
{
  "entity_uuid": "<uuid>",
  "entity_display_name": "VLAN-100",
  "relationship_graph_depth": 2,

  "notification_audiences": [
    {
      "actor_uuid": "<uuid>",
      "display_name": "NetworkOps Team",
      "audience_role": "owner",
      "stakeholder_reason": null,
      "notification_providers": ["slack-corp", "pagerduty-prod"]
    },
    {
      "actor_uuid": "<uuid>",
      "display_name": "AppTeam Admin",
      "audience_role": "stakeholder",
      "stakeholder_reason": {
        "via_entity": "VM-A",
        "via_relationship": "attached_to",
        "stake_strength": "required"
      },
      "notification_providers": ["slack-corp"]
    }
  ],

  "active_notification_providers": [
    {
      "provider_uuid": "<uuid>",
      "display_name": "slack-corp",
      "status": "healthy",
      "delivery_success_rate_24h": 0.998
    }
  ]
}
```

---

## 9. Error Model

All Flow GUI API errors follow the standard DCM error format:

```json
{
  "error": "<error_code>",
  "message": "<human-readable description>",
  "request_id": "<uuid>",
  "timestamp": "<ISO 8601>"
}
```

| HTTP Status | Error Code | Meaning |
|-------------|-----------|---------|
| 403 | `insufficient_role` | Operation requires platform_admin or policy_author role |
| 404 | `policy_not_found` | Policy UUID not found in active policy store |
| 409 | `pr_already_open` | A PR already exists for this policy handle |
| 422 | `invalid_canvas` | Canvas definition is invalid (disconnected steps, unknown payload types) |
| 422 | `rego_invalid` | Rego syntax error or output schema mismatch |
| 422 | `simulation_failed` | Simulation could not be executed (missing fields, invalid tenant) |
| 503 | `policy_engine_unavailable` | Policy Engine unreachable — graph data may be stale |
| 503 | `git_unavailable` | GitOps store unreachable — PR creation unavailable |

---

## 10. Conformance Levels

**Level 1 — Read-Only:** Execution Graph View (read), Profile View, Payload Type Browser, Notification Flow View. Suitable for dashboards and observability integrations.

**Level 2 — Standard:** All Level 1 plus Flow Simulation, Shadow Mode Dashboard (view only), Policy Node Detail. Required for platform engineer tooling.

**Level 3 — Full:** All Level 2 plus Policy Canvas (save as PR), Policy Authoring Interface, Test Case Management, Shadow Mode Promotion. Required for full policy lifecycle management.

---

*Document maintained by the DCM Project. For questions or contributions see [GitHub](https://github.com/dcm-project).*
