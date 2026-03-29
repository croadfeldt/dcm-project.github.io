---
title: "DCM Admin API Specification"
type: docs
weight: 1
---

> **📋 Draft**
>
> This specification has been promoted from Work in Progress to Draft status. Complete Admin API covering all platform admin operations with request/response examples. It is ready for implementation feedback but has not yet been formally reviewed for final release.
>
> This specification defines the DCM Admin API — the platform administration interface. Published to share design direction and invite feedback. Do not build production integrations against this specification until it reaches draft status.

**Version:** 0.1.0-draft
**Status:** Draft — Ready for implementation feedback
**Document Type:** Technical Specification
**Related Documents:** [Foundational Abstractions](../data-model/00-foundations.md) | [Consumer API Specification](consumer-api-spec.md) | [DCM Operator Interface Specification](dcm-operator-interface-spec.md) | [Control Plane Components](../data-model/25-control-plane-components.md) | [Accreditation and Authorization Matrix](../data-model/26-accreditation-and-authorization-matrix.md)

---

## Abstract

The Admin API is the platform administration interface for DCM. It is served through the same Ingress API as the Consumer API and Provider API but is restricted to actors with `platform_admin` or `tenant_admin` roles. It covers operations that consumers cannot perform — Tenant lifecycle management, provider registration review, accreditation approval, quota administration, discovery management, orphan resolution, recovery decision escalation, and bootstrap operations.

---

## 1. Authentication and Authorization

All Admin API endpoints require Bearer token authentication (same as Consumer API). Role requirements are declared per endpoint:

| Role | Scope |
|------|-------|
| `platform_admin` | All Admin API operations across all Tenants |
| `tenant_admin` | Tenant-scoped Admin API operations for their own Tenant only |

Base URL: `/api/v1/admin/`

Step-up MFA is required for destructive operations (Tenant decommission, accreditation revocation, bootstrap credential rotation) regardless of session MFA status.

---

## 2. Tenant Management

### 2.1 List Tenants

```
GET /api/v1/admin/tenants
Role: platform_admin

Query params: status=<active|suspended|decommissioned>, page, page_size

Response 200:
{
  "tenants": [
    {
      "tenant_uuid": "<uuid>",
      "handle": "payments-team",
      "display_name": "Payments Platform",
      "status": "active",
      "deployment_posture": "prod",
      "compliance_domains": ["hipaa"],
      "recovery_profile": "notify-and-wait",
      "entity_count": 142,
      "created_at": "<ISO 8601>"
    }
  ],
  "total": 12
}
```

### 2.2 Create Tenant

```
POST /api/v1/admin/tenants
Role: platform_admin

{
  "handle": "new-team",
  "display_name": "New Team",
  "deployment_posture": "standard",
  "compliance_domains": [],
  "recovery_profile_override": null,
  "initial_admin_actor_uuid": "<uuid>"
}

Response 201 Created:
{
  "tenant_uuid": "<uuid>",
  "status": "active"
}
```

### 2.3 Suspend / Reinstate Tenant

```
POST /api/v1/admin/tenants/{tenant_uuid}/suspend
POST /api/v1/admin/tenants/{tenant_uuid}/reinstate
Role: platform_admin

{
  "reason": "<human-readable reason>",
  "notify_tenant_admin": true
}
```

### 2.4 Decommission Tenant

```
DELETE /api/v1/admin/tenants/{tenant_uuid}
Role: platform_admin
Requires: step-up MFA

{
  "reason": "<required>",
  "force": false,          # true: decommission even if active entities remain
  "notify_tenant_admin": true
}

Response 409 Conflict (if active entities and force=false):
{
  "error": "tenant_has_active_entities",
  "active_entity_count": 47,
  "resolution": "Decommission all entities first, or use force=true"
}
```

---

## 3. Provider Management

### 3.1 List Registered Providers

```
GET /api/v1/admin/providers
Role: platform_admin

Query params: type=<service|policy|storage|notification|information>, status=<active|suspended>

Response 200:
{
  "providers": [
    {
      "provider_uuid": "<uuid>",
      "handle": "eu-west-prod-1",
      "provider_type": "service",
      "status": "active",
      "health": "healthy",
      "accreditation_count": 2,
      "max_data_classification": "phi"
    }
  ]
}
```

### 3.2 Review Provider Registration

New provider registrations in `proposed` status require platform admin review:

```
GET /api/v1/admin/providers/pending
Role: platform_admin

POST /api/v1/admin/providers/{provider_uuid}/approve
POST /api/v1/admin/providers/{provider_uuid}/reject
{
  "reason": "<required for reject>"
}
```

### 3.3 Suspend Provider

```
POST /api/v1/admin/providers/{provider_uuid}/suspend
Role: platform_admin

{
  "reason": "<human-readable reason>",
  "affect_existing_entities": "notify_only | block_new_requests | migrate"
}
```

---

## 4. Accreditation Management

### 4.1 List Accreditations

```
GET /api/v1/admin/accreditations
Role: platform_admin

Query params: subject_type, framework, status=<active|proposed|expiring|expired>

Response 200:
{
  "accreditations": [
    {
      "accreditation_uuid": "<uuid>",
      "subject_uuid": "<uuid>",
      "subject_type": "service_provider",
      "framework": "hipaa",
      "accreditation_type": "baa",
      "status": "active",
      "valid_until": "<ISO 8601>",
      "days_until_expiry": 89
    }
  ]
}
```

### 4.2 Approve Accreditation

```
POST /api/v1/admin/accreditations/{accreditation_uuid}/approve
Role: platform_admin
Requires: step-up MFA

{
  "review_notes": "<required — document basis for approval>",
  "certificate_verified": true
}
```

### 4.3 Revoke Accreditation

```
DELETE /api/v1/admin/accreditations/{accreditation_uuid}
Role: platform_admin
Requires: step-up MFA

{
  "revocation_reason": "<required>",
  "affected_entity_action": "notify_only | block_new_requests | migrate_entities"
}
```

---

## 5. Discovery Management

### 5.1 Trigger Discovery

```
POST /api/v1/admin/discovery/trigger
Role: platform_admin | tenant_admin

{
  "scope": "entity | resource_type | provider | tenant",
  "entity_uuid": "<uuid>",
  "resource_type": "Compute.VirtualMachine",
  "provider_uuid": "<uuid>",
  "tenant_uuid": "<uuid>",
  "reason": "incident investigation",
  "priority": "high | standard | background"
}

Response 202 Accepted:
{
  "discovery_job_uuid": "<uuid>",
  "status": "queued",
  "priority": "high",
  "estimated_start": "<ISO 8601>"
}
```

### 5.2 Discovery Job Status

```
GET /api/v1/admin/discovery/jobs/{discovery_job_uuid}

Response 200:
{
  "discovery_job_uuid": "<uuid>",
  "status": "running | completed | failed",
  "entities_discovered": 47,
  "new_entities_found": 2,
  "started_at": "<ISO 8601>",
  "completed_at": "<ISO 8601|null>",
  "orphan_candidates_found": 1
}
```

---

## 6. Orphan Management

### 6.1 List Orphan Candidates

```
GET /api/v1/admin/orphans
Role: platform_admin

Query params: provider_uuid, status=<under_review|confirmed|resolved>

Response 200:
{
  "orphan_candidates": [
    {
      "orphan_candidate_uuid": "<uuid>",
      "provider_uuid": "<uuid>",
      "provider_entity_id": "vm-0a1b2c3d",
      "suspected_request_uuid": "<uuid>",
      "resource_type": "Compute.VirtualMachine",
      "discovered_at": "<ISO 8601>",
      "status": "under_review"
    }
  ]
}
```

### 6.2 Resolve Orphan Candidate

```
POST /api/v1/admin/orphans/{orphan_candidate_uuid}/resolve
Role: platform_admin

{
  "resolution": "manual_decommission | adopt_into_dcm | mark_false_positive",
  "reason": "<required>",
  "target_tenant_uuid": "<uuid>"    # required if resolution=adopt_into_dcm
}
```

---

## 7. Recovery Decision Management

Platform admins can resolve pending recovery decisions for any entity:

```
GET /api/v1/admin/recovery-decisions/pending
Role: platform_admin

Response 200:
{
  "pending_decisions": [
    {
      "recovery_decision_uuid": "<uuid>",
      "entity_uuid": "<uuid>",
      "trigger": "DISPATCH_TIMEOUT",
      "entity_state": "TIMEOUT_PENDING",
      "deadline": "<ISO 8601>",
      "tenant_uuid": "<uuid>"
    }
  ]
}

POST /api/v1/admin/recovery-decisions/{recovery_decision_uuid}
Role: platform_admin

{
  "action": "DRIFT_RECONCILE | DISCARD_AND_REQUEUE | DISCARD_NO_REQUEUE",
  "reason": "<required>"
}
```

---

## 8. Quota Management

### 8.1 View Tenant Quotas

```
GET /api/v1/admin/tenants/{tenant_uuid}/quotas
Role: platform_admin | tenant_admin

Response 200:
{
  "quotas": [
    {
      "resource_type": "Compute.VirtualMachine",
      "limit": 100,
      "current_usage": 47,
      "policy_uuid": "<uuid>"
    }
  ]
}
```

### 8.2 Update Quota

```
PUT /api/v1/admin/tenants/{tenant_uuid}/quotas/{resource_type}
Role: platform_admin

{
  "new_limit": 150,
  "reason": "Q2 capacity increase approved by FinOps"
}
```

---

## 9. Search Index Management

```
POST /api/v1/admin/search-index/rebuild
Role: platform_admin

{
  "scope": "full | tenant | resource_type",
  "tenant_uuid": "<uuid>",
  "reason": "Recovery after index corruption"
}

Response 202 Accepted:
{
  "rebuild_job_uuid": "<uuid>",
  "estimated_duration": "PT2H",
  "degraded_during_rebuild": true
}

GET /api/v1/admin/search-index/status

Response 200:
{
  "status": "healthy | degraded | rebuilding | unavailable",
  "staleness_seconds": 42,
  "last_full_rebuild": "<ISO 8601>",
  "entity_count": 8421
}
```

---

## 10. Bootstrap Operations

### 10.1 Rotate Bootstrap Admin Credential

```
POST /api/v1/admin/bootstrap/rotate-credential
Role: platform_admin
Requires: step-up MFA (hardware_token_mfa for fsi/sovereign)

{
  "new_credential_ref": "<credential provider reference>",
  "reason": "Initial bootstrap credential rotation"
}
```

### 10.2 Deployment Health

```
GET /api/v1/admin/health

Response 200:
{
  "overall": "healthy | degraded | critical",
  "components": [
    { "component": "request_orchestrator", "status": "healthy" },
    { "component": "policy_engine", "status": "healthy" },
    { "component": "placement_engine", "status": "healthy" },
    { "component": "lifecycle_constraint_enforcer", "status": "healthy" },
    { "component": "discovery_scheduler", "status": "healthy" },
    { "component": "notification_router", "status": "healthy" },
    { "component": "cost_analysis", "status": "healthy" },
    { "component": "search_index", "status": "degraded", "staleness_seconds": 180 },
    { "component": "intent_store", "status": "healthy" },
    { "component": "requested_store", "status": "healthy" },
    { "component": "realized_store", "status": "healthy" }
  ],
  "active_profile": {
    "deployment_posture": "prod",
    "compliance_domains": ["hipaa"],
    "recovery_posture": "notify-and-wait",
    "zero_trust_posture": "full"
  }
}
```

---

## 11. Error Model

Same as Consumer API. Additional admin-specific codes:

| HTTP Status | Error Code | Meaning |
|-------------|-----------|---------|
| 403 | `insufficient_role` | Operation requires platform_admin; actor is tenant_admin |
| 403 | `cross_tenant_denied` | tenant_admin attempting operation outside their Tenant |
| 409 | `tenant_has_active_entities` | Tenant decommission blocked; active entities remain |
| 409 | `provider_has_active_entities` | Provider decommission blocked; entities hosted there |

---

*Document maintained by the DCM Project. For questions or contributions see [GitHub](https://github.com/dcm-project).*
