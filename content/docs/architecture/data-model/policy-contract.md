---
title: "DCM — Unified Policy Contract"
type: docs
weight: -8
---

> **⚠️ Active Development Notice**
>
> The DCM data model and architecture documentation are actively being developed.
>
> Contributions, feedback, and discussion are welcome via [GitHub](https://github.com/dcm-project).

**Document Status:** 🔄 In Progress
**Document Type:** Architecture Foundation
**Related Documents:** [Foundational Abstractions](00-foundations.md) | [Provider Contract](A-provider-contract.md) | [Policy Profiles](14-policy-profiles.md) | [Governance Matrix](27-governance-matrix.md) | [OPA Integration](../specifications/dcm-opa-integration-spec.md)

---

## 1. The Unified Policy Contract

Every Policy in DCM — regardless of type — implements a single base contract. What varies between policy types is the **output schema**: what the Policy produces when its match conditions are satisfied.

```
┌─────────────────────────────────────────────────────────┐
│                 BASE POLICY CONTRACT                     │
│                                                          │
│  Match Conditions · Enforcement Level · Domain          │
│  Lifecycle · Audit · Shadow Mode                         │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │              OUTPUT SCHEMA                       │   │
│  │                                                  │   │
│  │  What this policy type produces when it fires.   │   │
│  │  Seven typed output schemas.                     │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**Adding a new policy type** = define a new output schema. The base contract, evaluation algorithm, lifecycle, and audit obligations are inherited.

---

## 2. Base Contract — Match Conditions

All policies declare when they fire using one or both of two match condition models:

**Model A — Payload type + field conditions** (for pipeline policies: GateKeeper, Validation, Transformation, Recovery, Orchestration Flow):

```yaml
match:
  payload_type: request.initiated | request.layers_assembled | ...   # from closed vocabulary
  conditions:
    - field: <field_path>                # dot-notation path into the payload
      operator: equals | in | minimum | maximum | contains | matches
      value: <value>
    - field: <field_path>
      operator: not_equals
      value: <value>
  condition_logic: all | any             # default: all
```

**Model B — Four-axis boundary conditions** (for boundary policies: Governance Matrix Rules):

```yaml
match:
  subject:
    type: <subject_type>
    identity: { ... }
    tenant: { ... }
  data:
    classification: <level>
    resource_type: <fqn>
    field_paths: { mode: allowlist | blocklist, paths: [...] }
    capability: <capability>
  target:
    type: <target_type>
    sovereignty_zone: { match: <zone_id> }
    accreditation_held: { includes: [...] }
    trust_posture: <posture>
  context:
    profile: { deployment_posture: <posture> }
    zero_trust_posture: { minimum: <level> }
    federated: true | false
```

Policies may declare match conditions using either model. Orchestration Flow policies and Lifecycle Policies may also use relationship event conditions (see Section 9).

---

## 3. Base Contract — Enforcement Level

```yaml
enforcement: hard | soft

# hard: cannot be relaxed by any downstream rule at any domain level
#        A hard DENY cannot be overridden by any Tenant, entity, or operator override
#        Reserved for: sovereign/classified data boundaries, regulatory hard requirements

# soft: establishes a default that downstream rules can tighten
#        A soft ALLOW can be restricted to DENY by a more-specific rule
#        A soft DENY cannot be relaxed to ALLOW by a downstream rule
```

Most policies are soft. Hard enforcement is reserved for absolute security constraints.

---

## 4. Base Contract — Domain Precedence

Policies operate within a domain hierarchy. More-specific domains win within the same concern type:

```
system (most trusted — DCM built-in)
  └── platform (platform admin declared)
        └── tenant (Tenant admin declared)
              └── resource_type (per resource type spec)
                    └── entity (per specific entity — most specific)
```

Within the same domain level, DENY wins over ALLOW. More-specific domain wins over less-specific.

---

## 5. Base Contract — Artifact Structure

All policies are first-class DCM Data artifacts. They share the standard artifact metadata and lifecycle:

```yaml
policy_artifact:
  # Standard DCM artifact metadata (all artifacts carry this)
  artifact_metadata:
    uuid: <uuid>
    handle: "<domain>/<concern>/<name>"
    version: "1.0.0"
    status: developing | proposed | active | deprecated | retired
    owned_by: { display_name: "<team>", email: "<email>" }
    created_by: { display_name: "<actor>" }
    created_via: pr | api | migration | system

  # Policy classification
  policy_type: <type>                    # gatekeeper | validation | transformation |
                                         # recovery | orchestration_flow |
                                         # governance_matrix_rule | lifecycle
  concern_type: <concern>                # security | compliance | operational |
                                         # recovery_posture | zero_trust_posture |
                                         # data_authorization_boundary | orchestration_flow

  domain: system | platform | tenant | resource_type | entity

  # Match conditions (Model A or B — see Section 2)
  match: { ... }

  # Enforcement
  enforcement: hard | soft

  # Output schema (varies by policy_type — see Sections 8-14)
  output: { ... }

  # Audit
  audit_on: [ALLOW, DENY, STRIP_FIELD]   # which decisions produce audit records
  notification_on: [DENY]               # which decisions trigger notifications
  notification_urgency: low | medium | high | critical

  # Compliance reference
  compliance_basis: "<regulatory citation>"
  review_required_before: "<ISO 8601 date>"
```

---

## 6. Base Contract — Lifecycle

All policies follow the five-status lifecycle:

| Status | Behavior |
|--------|---------|
| `developing` | Dev mode only. Not applied in any environment. |
| `proposed` | Shadow mode: executes against real traffic; output captured but never applied. Used for safe validation. |
| `active` | Applied to all matching requests. |
| `deprecated` | Still active; replacement available; warning on evaluation. |
| `retired` | Terminal; cannot be used. |

**Shadow mode (proposed status):** The policy evaluates against real traffic. Its output is captured in the Validation Store. Platform admins review shadow results before promoting to active. This is the primary mechanism for safe policy change management.

---

## 7. Base Contract — Evaluation and Audit

**Evaluation order:** Within a domain level, policies are evaluated in declared priority order. Across domain levels, more-specific domains evaluate after (and can override) less-specific domains.

**Parallel evaluation:** Policies with no data dependencies on each other evaluate concurrently. The Policy Engine tracks dependency declarations.

**Audit:** Every policy evaluation produces an audit record regardless of outcome. The record includes: policy_uuid, policy_version, match_result, output, enforcement_level, actor, timestamp. No evaluation is silent.

---

## 8. Output Schema — GateKeeper

**Fires on:** Request payload at assembly time.
**Produces:** An allow or deny decision for the request.

```yaml
gatekeeper_output:
  decision: allow | deny
  reason: "<human-readable — required for deny>"
  field_locks:                           # optional: lock specific fields as immutable
    - field: <field_path>
      lock_type: immutable | constrained
      constraint_schema: <JSON Schema>   # if constrained
  warnings: ["<optional advisory messages>"]
```

**Policy Engine behavior:**
- `allow` → request proceeds; field_locks applied to payload
- `deny` → request blocked; `reason` included in consumer error response
- Any active GateKeeper producing `deny` → request blocked (all must allow)

---

## 9. Output Schema — Validation

**Fires on:** Request payload; validates correctness of field values.
**Produces:** Pass or fail with field-level detail.

```yaml
validation_output:
  result: pass | fail
  field_results:
    - field: <field_path>
      result: valid | invalid
      message: "<validation failure description>"
      suggested_value: <value>           # optional
  advisory: ["<non-blocking notes>"]
```

**Policy Engine behavior:**
- `pass` → request proceeds
- `fail` → request blocked; `field_results` included in consumer error response

---

## 10. Output Schema — Transformation

**Fires on:** Request payload; enriches, modifies, or injects field values.
**Produces:** A set of field mutations to apply to the payload.

```yaml
transformation_output:
  mutations:
    - field: <field_path>
      operation: set | append | delete | lock
      value: <new_value>                 # for set/append
      reason: "<why this mutation was made>"
      source_type: enrichment | injection | normalization | correction
```

**Policy Engine behavior:** All mutations from all active Transformation policies are collected and applied to the payload. Each mutation is recorded in field-level provenance with the policy_uuid as source.

---

## 11. Output Schema — Recovery

**Fires on:** A failure or ambiguity trigger condition (DISPATCH_TIMEOUT, PARTIAL_REALIZATION, CANCELLATION_FAILED, etc.).
**Produces:** A recovery action and parameters.

```yaml
recovery_output:
  action: DRIFT_RECONCILE | DISCARD_AND_REQUEUE | DISCARD_NO_REQUEUE |
          ACCEPT_LATE_REALIZATION | COMPENSATE_AND_FAIL |
          NOTIFY_AND_WAIT | ESCALATE | RETRY
  action_parameters:
    requeue_delay: PT0S                  # for DISCARD_AND_REQUEUE
    max_attempts: 3                      # for RETRY
    backoff: exponential                 # for RETRY
    deadline: PT4H                       # for NOTIFY_AND_WAIT
    on_deadline_exceeded: ESCALATE       # for NOTIFY_AND_WAIT
  notify_before_action: true
  notification_urgency: high
```

**Policy Engine behavior:** The first matching Recovery policy's action is executed. Recovery policies follow the same domain precedence — resource_type override wins over tenant override wins over profile default.

---

## 12. Output Schema — Orchestration Flow

**The two-level orchestration model:**

Orchestration in DCM operates at two levels that compose through the same Policy Engine:

- **Level 1 — Named Workflow Artifacts:** Orchestration Flow Policies with `ordered: true` declare an explicit, visible, auditable sequence of steps. Each step references a payload type from the closed vocabulary. This is what operators see and reason about. Adding a step = adding to a workflow Policy.
- **Level 2 — Dynamic Policies:** GateKeeper, Transformation, Recovery, and Governance Matrix Policies fire when their conditions match, within or alongside workflow steps, without being declared in the workflow. Adding conditional behavior = writing a dynamic policy.

The Request Orchestrator (event bus) routes all payload type events through the Policy Engine. Both named workflow steps and dynamic policies evaluate against the same events. The workflow provides the skeleton; dynamic policies fill in conditional behavior.

**Fires on:** Pipeline payload type events.
**Produces:** A flow directive governing step ordering.

```yaml
orchestration_flow_output:
  ordered: true | false
  steps:
    - step: 1
      policy_handle: "<policy to execute at this step>"
      condition: "<additional condition for this step>"
      on_fail: halt | skip | escalate
  parallel_groups:                       # steps that may execute in parallel
    - [step_1_id, step_2_id]
```

**Step vocabulary** — steps reference payload types from the closed vocabulary, mapping to control plane operations:

| Payload type | Maps to |
|-------------|---------|
| `request.initiated` | Start of request pipeline |
| `request.layers_assembled` | Layer assembly complete |
| `request.policies_evaluated` | All policies evaluated |
| `request.placement_complete` | Provider selected |
| `request.dispatched` | Sent to provider |
| `discovery.cycle_complete` | Discovery cycle done |
| `drift.detected` | Drift found |
| `recovery.timeout_fired` | Dispatch timeout |
| `provider_update.received` | Provider update notification |

Custom steps extend this vocabulary by publishing new payload types.

**Policy Engine behavior:** When `ordered: true`, steps execute in declared sequence. When `ordered: false`, the Policy Engine executes steps in parallel where no data dependencies exist. Orchestration Flow policies compose with standard GateKeeper and Transformation policies — both types evaluate in the same pipeline.

---

## 13. Output Schema — Governance Matrix Rule

**Fires on:** Any cross-boundary interaction (DCM → Provider, DCM → Peer DCM, Provider → DCM).
**Produces:** A boundary control decision with optional field permissions.

```yaml
governance_matrix_output:
  decision: ALLOW | DENY | ALLOW_WITH_CONDITIONS | STRIP_FIELD | REDACT | AUDIT_ONLY
  conditions:                            # for ALLOW_WITH_CONDITIONS
    - field: <axis_field>
      operator: <operator>
      value: <value>
  field_permissions:
    mode: allowlist | blocklist | passthrough
    paths: ["<field_path>", ...]
    on_blocked_field: STRIP_FIELD | DENY_REQUEST | REDACT
  audit_on: [ALLOW, DENY, STRIP_FIELD]
  notification_on: [DENY]
  notification_urgency: critical
```

**Policy Engine behavior:** Hard DENY evaluated first — any hard DENY is terminal. Soft decisions evaluated by domain precedence; DENY wins over ALLOW at the same level. Field permissions applied after decision determined. Audit record always written.

---

## 14. Output Schema — Lifecycle Policy

**Fires on:** Relationship events (related entity state changes, relationship creation/release).
**Produces:** A lifecycle action to apply to related entities.

```yaml
lifecycle_policy_output:
  on_related_destroy: cascade | protect | detach | notify
  on_related_suspend: cascade | ignore | notify
  on_last_relationship_released: destroy | retain | notify
  propagation_depth: 1 | 2 | N          # how many relationship hops to propagate
  action_delay: PT0S                     # grace period before executing action
```

**Policy Engine behavior:** When a relationship event occurs, all matching Lifecycle policies on both related entities are evaluated. The most restrictive action wins (save beats destroy). Conflicts between policies at the same domain level produce a CONFLICT_ERROR at policy ingestion time.

---

## 15. Policy Composition

Policies compose naturally through the domain precedence model:

```
System policy (GateKeeper: cpu_count max 64)
  └── Platform policy (GateKeeper: prod VMs require manager approval)
        └── Tenant policy (GateKeeper: payments team max cpu_count 32)
              └── Resource-type policy (Transformation: inject monitoring)
```

For a single request, all active matching policies at all domain levels evaluate. GateKeepers at all levels must allow (any deny blocks). Transformations from all levels are collected and applied. Recovery policies use the most-specific matching policy.

**Policy Groups** are Data artifacts that group related policies by concern_type. Profiles activate Policy Groups. This is how "apply the HIPAA profile" works — it activates the HIPAA compliance domain's Policy Group, which contains all the GateKeeper, Validation, Transformation, and Governance Matrix policies required for HIPAA compliance.

---

## 16. Related Policies

| Policy | Rule |
|--------|------|
| `POL-001` | All DCM policy types implement the unified base contract. The output schema is the only thing that varies. |
| `POL-002` | Every policy evaluation produces an audit record. No evaluation is silent. |
| `POL-003` | Hard enforcement policies cannot be relaxed by any downstream rule at any domain level. |
| `POL-004` | Policies in `proposed` status execute in shadow mode — output is captured and never applied. Shadow mode is the primary mechanism for safe policy change management. |
| `POL-005` | The Policy Engine is the sole evaluator of all policies. No component bypasses the Policy Engine to enforce rules directly. |
| `POL-006` | Adding a new policy type requires defining a new output schema. The base contract, evaluation algorithm, lifecycle, and audit obligations are inherited. |
| `POL-007` | Policies ARE the orchestration. Pipeline steps are Policies firing on payload type events. Static flows are Orchestration Flow Policies with `ordered: true`. |

---

*Document maintained by the DCM Project. For questions or contributions see [GitHub](https://github.com/dcm-project).*
