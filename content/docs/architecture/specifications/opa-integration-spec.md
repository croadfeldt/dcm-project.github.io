---
title: "DCM OPA Integration Specification"
type: docs
weight: 5
---

> **⚠️ Work in Progress**
>
> This specification defines the OPA integration contract for DCM Policy Providers. It is published to share design direction and invite feedback. Do not build production integrations against this specification until it reaches draft status.

**Version:** 0.1.0-draft
**Status:** Design — Not yet implemented
**Document Type:** Technical Specification
**Related Documents:** [Policy Profiles](../data-model/14-policy-profiles.md) | [Control Plane Components](../data-model/25-control-plane-components.md) | [DCM Operator Interface Specification](dcm-operator-interface-spec.md)

---

## Abstract

This specification defines how Open Policy Agent (OPA) integrates with the DCM Policy Engine as the reference implementation for Mode 3 Policy Providers. It defines the DCM payload schema as an OPA input document, the expected decision schema as OPA output, the built-in functions DCM provides to Rego policies, and the test harness contract for validating policies before activation.

OPA is not required to implement DCM — any Mode 3 Policy Provider can implement DCM's policy contract. However, OPA with Rego is the recommended reference implementation, and this specification enables implementors and integrators to build standards-compliant DCM policy engines.

---

## 1. Introduction

### 1.1 The Policy Engine Contract

DCM's Policy Engine evaluates policies at multiple points in the request lifecycle. The engine receives a payload, evaluates all active matching policies, and accumulates mutations. The OPA integration maps this contract to Rego evaluation.

DCM policy types:
- **GateKeeper** — approve or reject; output is a decision (allow/deny + reason)
- **Validation** — verify correctness; output is a validation result (pass/fail + details)
- **Transformation** — enrich or modify; output is a set of field mutations
- **Recovery** — respond to failure/ambiguity; output is a recovery action
- **Orchestration Flow** — coordinate pipeline steps; output is a flow directive

All five types share the same OPA input schema. The output schema differs per type.

### 1.2 Mode 3 Policy Provider

A Mode 3 Policy Provider executes OPA Rego bundles. DCM dispatches the policy input document to the OPA instance and receives the decision document. The OPA instance may be:
- Embedded within DCM (the reference implementation)
- A sidecar OPA instance (co-located with DCM)
- A remote OPA instance (requires network call; latency considerations apply)

---

## 2. Input Schema — DCM Payload as OPA Document

Every OPA policy evaluation receives the following input document:

```rego
# input document structure
input := {
  # The current payload being evaluated
  "payload": {
    "type": "request.initiated",         # payload type from the vocabulary
    "entity_uuid": "...",
    "resource_type": "Compute.VirtualMachine",
    "version": "2.1.0",
    "fields": {
      "cpu_count": {
        "value": 4,
        "provenance": { "origin": {...}, "modifications": [...] }
      }
      # ... all assembled fields with provenance
    }
  },

  # The requesting actor context
  "actor": {
    "uuid": "...",
    "type": "human",                     # human | service_account | system
    "tenant_uuid": "...",
    "roles": ["developer"],
    "groups": ["payments-team", "eu-west-users"],
    "mfa_verified": true,
    "auth_level": "oidc_mfa"
  },

  # The active deployment governance
  "deployment": {
    "posture": "prod",
    "compliance_domains": ["hipaa", "gdpr"],
    "recovery_posture": "notify-and-wait",
    "profile_uuid": "..."
  },

  # Entity context (null for new requests)
  "entity": {
    "uuid": "...",
    "lifecycle_state": "OPERATIONAL",
    "ownership_model": "whole_allocation",
    "owned_by_tenant_uuid": "...",
    "relationship_count": 3,
    "drift_status": "clean"
  },

  # Provider context (null before placement)
  "provider": {
    "uuid": "...",
    "sovereignty_declaration": {...},
    "trust_score": 94,
    "capacity_confidence": "high"
  },

  # DCM built-in data (resolved by DCM before OPA evaluation)
  "dcm": {
    "tenant": {
      "uuid": "...",
      "display_name": "Payments Platform",
      "active_entity_count": { "Compute.VirtualMachine": 47 },
      "compliance_overlays": ["hipaa"]
    },
    "cost_estimate": {
      "per_hour": 0.32,
      "confidence": "high"
    }
  }
}
```

---

## 3. Output Schema — OPA Decision Documents

### 3.1 GateKeeper Output

```rego
package dcm.gatekeeper.vm_size_limits

import future.keywords

# Main decision
allow if {
  input.payload.fields.cpu_count.value <= max_cpu
}

deny contains reason if {
  input.payload.fields.cpu_count.value > max_cpu
  reason := sprintf("cpu_count %d exceeds maximum %d for tenant %s",
    [input.payload.fields.cpu_count.value, max_cpu, input.actor.tenant_uuid])
}

# DCM reads the deny set; empty = allow
max_cpu := 32
```

DCM output contract:
```json
{
  "allow": true,
  "deny": [],
  "warnings": [],
  "policy_uuid": "...",
  "evaluated_at": "..."
}
```

### 3.2 Transformation Output

```rego
package dcm.transformation.inject_monitoring

mutations contains mutation if {
  input.payload.type == "request.layers_assembled"
  not input.payload.fields.monitoring_endpoint
  mutation := {
    "field": "monitoring_endpoint",
    "value": concat(".", ["https://metrics.internal", input.deployment.posture, "example.com"]),
    "source_type": "policy",
    "operation_type": "enrichment",
    "reason": "Standard monitoring endpoint injection"
  }
}
```

DCM output contract:
```json
{
  "mutations": [
    {
      "field": "monitoring_endpoint",
      "value": "https://metrics.internal.prod.example.com",
      "source_type": "policy",
      "operation_type": "enrichment",
      "reason": "Standard monitoring endpoint injection"
    }
  ],
  "policy_uuid": "..."
}
```

### 3.3 Recovery Policy Output

```rego
package dcm.recovery.discard_on_timeout

action := "DISCARD_AND_REQUEUE" if {
  input.payload.type == "recovery.timeout_fired"
  input.entity.lifecycle_state == "TIMEOUT_PENDING"
}
```

DCM output contract:
```json
{
  "action": "DISCARD_AND_REQUEUE",
  "action_parameters": { "requeue_delay": "PT0S" },
  "policy_uuid": "..."
}
```

---

## 4. DCM Built-in Functions for Rego

DCM provides built-in functions callable from Rego policies:

```rego
# Entity relationship graph queries
dcm.entity.relationships(entity_uuid)
  # Returns: array of relationship records for the entity

dcm.entity.has_relationship(entity_uuid, relationship_type)
  # Returns: bool

dcm.entity.stakeholder_count(entity_uuid, min_stake_strength)
  # Returns: int

# Information Provider data
dcm.entity.field_confidence(entity_uuid, field_path)
  # Returns: { band, score, authority_level }

# Sovereignty checks
dcm.sovereignty.compatible(entity_uuid, provider_uuid)
  # Returns: bool

dcm.sovereignty.violates(entity_uuid, data_residency_requirement)
  # Returns: bool

# Cost queries
dcm.cost.estimate(catalog_item_uuid, fields)
  # Returns: { per_hour, currency, confidence }

# Tenant quota queries
dcm.tenant.active_count(tenant_uuid, resource_type)
  # Returns: int

dcm.tenant.has_authorization(granting_tenant_uuid, consuming_tenant_uuid, resource_type)
  # Returns: bool
```

---

## 5. Policy Bundle Structure

OPA policies for DCM are packaged as bundles:

```
dcm-policy-bundle/
├── .manifest
│   {
│     "roots": ["dcm"],
│     "metadata": {
│       "dcm_policy_type": "gatekeeper",
│       "resource_types": ["Compute.VirtualMachine"],
│       "domain": "tenant",
│       "handle": "org/policies/vm-size-limits",
│       "version": "1.0.0"
│     }
│   }
├── dcm/
│   └── gatekeeper/
│       └── vm_size_limits/
│           └── policy.rego
└── tests/
    └── vm_size_limits_test.rego
```

---

## 6. Test Harness

DCM provides a test harness that policy authors use to validate policies against sample payloads before activation:

```
POST /api/v1/admin/policies/test

{
  "policy_bundle": "<base64-encoded bundle>",
  "test_cases": [
    {
      "description": "VM within CPU limit should be allowed",
      "input": {
        "payload": { "type": "request.initiated", "fields": { "cpu_count": { "value": 4 } } },
        "actor": { "roles": ["developer"] },
        "deployment": { "posture": "prod" }
      },
      "expected_output": { "allow": true, "deny": [] }
    }
  ]
}
```

The test harness is also used during shadow mode — DCM runs the policy against real traffic and compares actual output to expected output before the policy activates.

---

## 7. Policy Shadow Mode with OPA

When a policy is in `proposed` status, DCM evaluates it in shadow mode:

1. Policy bundle loaded into a shadow OPA instance
2. Every real request payload is evaluated by both active policies AND shadow policies
3. Shadow outputs recorded in the Validation Store (not applied to requests)
4. Policy authors review shadow results via the Admin API or Flow GUI
5. On approval (no adverse results): policy status → `active`

---

*Document maintained by the DCM Project. For questions or contributions see [GitHub](https://github.com/dcm-project).*
