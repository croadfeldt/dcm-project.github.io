---
title: "DCM Data Model — Federated Contribution Model"
type: docs
weight: 28
---

> **⚠️ Active Development Notice**
>
> The DCM data model and architecture documentation are actively being developed. Concepts, structures, and specifications documented here represent work in progress and are subject to change as design decisions are finalized.
>
> Contributions, feedback, and discussion are welcome via [GitHub](https://github.com/dcm-project).

**Document Status:** 🔄 In Progress
**Document Type:** Architecture Reference — Read This First for Multi-User Data Governance
**Related Documents:** [Foundational Abstractions](00-foundations.md) | [Layering and Versioning](03-layering-and-versioning.md) | [Policy Profiles](14-policy-profiles.md) | [Registry Governance](20-registry-governance.md) | [DCM Federation](22-dcm-federation.md) | [Governance Matrix](27-governance-matrix.md) | [Consumer API](../specifications/consumer-api-spec.md)

> **This document maps to: DATA + POLICY + PROVIDER**
>
> The federated contribution model governs how Data artifacts are created and managed across all contributor types. It extends the Data abstraction with explicit contributor identity, applies Policies to govern contribution permissions and review requirements, and uses the Provider abstraction for cross-instance federation of contributions.

---

## 1. Purpose and Principle

DCM is a multi-user, multi-contributor system. Platform admins are not the only actors who create data. Consumers define their own service configurations, resource groups, and policy overlays. Service Providers publish their own resource type specs and catalog items. Peer DCM instances contribute registry entries across federation boundaries. Organizations extend DCM with their own artifact types.

**The federated contribution model** is the governing framework for how all of these actors create, review, activate, and lifecycle-manage DCM data artifacts. It extends the Data abstraction with one additional universal property:

> **Every DCM data artifact has a contributor** — an actor or system that authored it — and that contributor's role determines what review is required before the artifact becomes active.

This is not a special model for special cases. It is the same GitOps PR workflow, the same lifecycle (developing → proposed → active → deprecated → retired), and the same domain precedence (system → platform → tenant → resource_type → entity) — applied consistently across all contributor types.

**The core principle:** DCM defaults to a federated model for data creation, import, usage, and lifecycle. Every authorized actor can contribute within the bounds their role permits. The Governance Matrix governs the boundaries. The GitOps PR flow provides the review mechanism. Profile-bound auto-approval policies determine what needs human review and what does not.

---

## 2. Contributor Types and Permissions

### 2.1 The Four Contributor Types

| Contributor | Examples | Default domain scope |
|-------------|---------|---------------------|
| **Platform Admin** | DCM operators, SRE team | system, platform — all artifact types |
| **Consumer / Tenant** | Application teams, developers, Tenant admins | tenant — scoped to their Tenant |
| **Service Provider** | Infrastructure teams, automation platforms | provider — resource types they offer |
| **Peer DCM** | Federated DCM instances, Hub DCM, community registry | federated — governed by federation trust posture |

### 2.2 What Each Contributor Can Contribute

**Platform Admin:** All artifact types at all domain levels. No restrictions within the DCM deployment.

**Consumer / Tenant:**
- Tenant-domain policies (GateKeeper, Transformation, Recovery, Lifecycle, Orchestration Flow)
- Resource groups and group memberships within their Tenant
- Notification subscriptions for their Tenant
- Webhook registrations for their Tenant
- Custom catalog item definitions (within their Tenant's resource type scope)
- Tenant-scoped data layers (Request Layer — directly attached to their requests)
- Cross-tenant authorization records (requires counterpart Tenant acceptance)

**Service Provider:**
- Resource Type Specifications for resource types they offer (Organization or Verified Community tier)
- Provider Catalog Items for their registered resource types
- Service Layers for their offered resource types
- Provider-specific GateKeeper and Validation policies (provider domain)
- Cost metadata updates
- Sovereignty declaration updates

**Peer DCM:**
- Registry entries (Resource Type Specs, provider type definitions) contributed through federation channels
- Policy bundles contributed through verified federation relationships
- Layer contributions through Hub DCM governance
- Accreditation vouching for providers registered with the contributing DCM

### 2.3 What Each Contributor Cannot Contribute

| Contributor | Cannot contribute |
|-------------|-----------------|
| Consumer | System or platform domain policies; core layers; resource type specs (unless granted elevated role); provider catalog items for other providers |
| Service Provider | Policies outside their resource type domain; core layers; other providers' catalog items; tenant-domain policies for specific Tenants |
| Peer DCM | Artifacts above the federation trust level granted; system-domain policies without committee approval; sovereignty zones for jurisdictions not in their declared scope |

---

## 3. Contribution Artifact Types

Every DCM data artifact type has a declared set of contributor permissions. The following table specifies who can contribute each type and at what domain level:

| Artifact Type | Platform Admin | Consumer/Tenant | Service Provider | Peer DCM |
|--------------|---------------|-----------------|-----------------|---------|
| Resource Type Specification | All tiers | ❌ | Org + Community tiers | Community tier (via federation) |
| Provider Catalog Item | All | ❌ | Their resource types only | ❌ |
| Core Layer | ✅ | ❌ | ❌ | ❌ |
| Service Layer | ✅ | ❌ | Their resource types only | ❌ |
| Request Layer | ✅ | Their requests only | ❌ | ❌ |
| GateKeeper Policy | All domains | Tenant domain only | Provider domain only | Via federation governance |
| Transformation Policy | All domains | Tenant domain only | Provider domain only | Via federation governance |
| Recovery Policy | All domains | Tenant domain only | Provider domain only | Via federation governance |
| Orchestration Flow Policy | All domains | Tenant domain only | ❌ | ❌ |
| Governance Matrix Rule | All domains | Tenant domain only | ❌ | ❌ |
| Lifecycle Policy | All domains | Tenant domain (on their entities) | ❌ | ❌ |
| Accreditation | All | ❌ | Their own accreditations | Vouching for their providers |
| Sovereignty Zone | ✅ | ❌ | ❌ | ❌ |
| DCMGroup / Resource Group | All | Tenant domain only | ❌ | ❌ |
| Notification Subscription | All | Their Tenant only | ❌ | ❌ |
| Webhook Registration | All | Their Tenant only | ❌ | ❌ |

---

## 4. The Contribution Flow

All contributions — regardless of contributor type — flow through the same GitOps PR model. What varies is:
- **The target store** (which GitOps repository receives the PR)
- **The review requirement** (auto-approval vs human review vs dual approval)
- **The shadow mode behavior** (policies enter shadow mode automatically; other artifacts enter proposed status)

### 4.1 The Universal Contribution Pipeline

```
Contributor authors a data artifact
  │
  │ Via one of three contribution surfaces:
  ├── Flow GUI Canvas / Policy Authoring Interface
  ├── Direct API (POST /api/v1/contribute/{artifact_type})
  └── Git PR directly to the target repository
  │
  ▼ Artifact submitted → status: developing (local only)
  │
  ▼ Contributor submits for review → status: proposed
  │   For policies: shadow mode activates automatically
  │   For other artifacts: staged in proposed state
  │
  ▼ Governance Matrix evaluates the contribution:
  │   Is this contributor permitted to contribute this artifact type?
  │   Is the artifact in the correct domain for this contributor?
  │   Does the artifact pass structural validation?
  │   DENY → rejected with reason; no further processing
  │
  ▼ Review flow (per profile + artifact type):
  │   auto:          artifact activates immediately
  │   human_review:  one platform admin or designated reviewer approves
  │   dual_approval: two independent reviewers approve
  │   committee:     declared DCMGroup reaches quorum
  │
  ▼ On approval → status: active
  │   For policies: shadow mode results reviewed; full enforcement begins
  │   For resource type specs: available in registry
  │   For catalog items: visible in service catalog (per RBAC)
  │
  ▼ Lifecycle managed by contributor (deprecate, retire)
      Subject to platform admin override at any time
```

### 4.2 Review Requirements by Contributor and Artifact Type

Review requirements are profile-governed. The table below shows defaults:

| Artifact Type | Platform Admin | Consumer/Tenant | Service Provider |
|--------------|---------------|-----------------|-----------------|
| Tenant-domain policy | auto | human_review (standard+) | human_review |
| Resource Type Spec (Org tier) | auto | ❌ | human_review |
| Resource Type Spec (Community tier) | human_review | ❌ | dual_approval |
| Provider Catalog Item | auto | ❌ | human_review |
| Service Layer | auto | ❌ | human_review |
| Governance Matrix Rule (tenant) | auto | dual_approval | ❌ |
| Governance Matrix Rule (platform) | human_review | ❌ | ❌ |
| Accreditation | human_review | ❌ | human_review |

**Profile overrides:**
- `dev`: most contributions auto-approved; shadow mode optional
- `standard`: consumer policies require human_review; provider specs require human_review
- `prod`: consumer governance matrix rules require dual_approval; provider specs require dual_approval
- `fsi`: all contributions require dual_approval; community registry entries require committee
- `sovereign`: all contributions require committee approval

---

## 5. Consumer Contribution Model

### 5.1 Consumer as Policy Author

Consumers are not passive requesters. Tenant admins and designated Tenant members with `policy_author` role can define and maintain their own Tenant-domain policies directly.

**What this enables:**
- A Payments team defining their own cost ceiling GateKeeper: "Reject any VM request over $500/month"
- An Operations team defining their own expiry Transformation: "All dev VMs get a 30-day TTL injected"
- A Security team defining their own governance matrix rule: "Our Tenant never sends confidential data to unaccredited providers"

**The scope constraint is enforced by DCM, not by convention.** When a consumer submits a policy with `domain: tenant`, DCM validates that the contributing actor belongs to that Tenant. Attempts to submit platform or system domain policies are rejected by the Governance Matrix at contribution time.

### 5.2 Consumer Contribution API

```
POST /api/v1/contribute/policy

Authorization: Bearer <token>
X-DCM-Tenant: <tenant-uuid>

{
  "policy_type": "gatekeeper",
  "handle": "tenant/payments/gatekeeper/cost-ceiling",
  "domain": "tenant",
  "concern_type": "operational",
  "enforcement": "soft",
  "match": {
    "payload_type": "request.policies_evaluated",
    "conditions": [
      { "field": "payload.cost_estimate.per_month", "operator": "gt", "value": 500 }
    ]
  },
  "output": {
    "decision": "deny",
    "reason": "Estimated monthly cost exceeds Tenant budget ceiling of $500"
  },
  "shadow_mode": true,           # start in shadow mode (proposed status)
  "commit_message": "Add monthly cost ceiling GateKeeper for Payments Tenant"
}

Response 202 Accepted:
{
  "contribution_uuid": "<uuid>",
  "artifact_type": "policy",
  "policy_handle": "tenant/payments/gatekeeper/cost-ceiling",
  "status": "proposed",
  "shadow_mode": true,
  "review_required": true,
  "review_type": "human_review",
  "reviewer_group": "platform-admins",
  "pr_url": "https://git.corp.example.com/dcm-policies/pulls/145",
  "shadow_results_url": "/flow/api/v1/shadow/<policy_uuid>"
}
```

### 5.3 Consumer Resource Group and Service Definitions

Consumers can define their own resource groups and service compositions within their Tenant:

```
POST /api/v1/contribute/resource-group

{
  "handle": "tenant/payments/groups/prod-vms",
  "display_name": "Production VMs — Payments",
  "group_class": "resource_grouping",
  "description": "All production VMs owned by the Payments team",
  "membership_policy": {
    "auto_include": {
      "resource_type": "Compute.VirtualMachine",
      "tags": { "team": "payments", "env": "production" }
    }
  }
}
```

---

## 6. Service Provider Contribution Model

### 6.1 Provider as Resource Type Publisher

Service Providers are not just execution targets — they are first-class contributors of the resource type definitions that consumers request. A provider registering a new virtual machine offering publishes the Resource Type Specification, the Catalog Item, and the Service Layer that consumers use to interact with it.

**What this enables:**
- A storage team publishing a new `Storage.DistributedVolume` resource type with its full schema, constraints, and cost model
- A networking team publishing provider-specific VLAN configurations as a Catalog Item with their own Service Layer injecting provider-specific defaults
- A platform team publishing an updated `Compute.VirtualMachine` spec with new fields and deprecating old ones

**Provider contributions flow through the same registry governance as all other registry entries** — submitted as PRs to the organization registry, reviewed per profile requirements, activated when approved.

### 6.2 Provider Contribution API

```
POST /api/v1/provider/contribute/resource-type-spec

Authorization: mTLS + provider credential

{
  "resource_type_fqn": "Storage.DistributedVolume",
  "tier": "organization",
  "version": "1.0.0",
  "schema": {
    "fields": [
      { "field_name": "capacity_gb", "type": "integer", "required": true },
      { "field_name": "replication_factor", "type": "integer",
        "default": 3, "constraint": { "min": 1, "max": 5 } },
      { "field_name": "encryption_at_rest", "type": "boolean", "default": true }
    ]
  },
  "portability_class": "provider_specific",
  "commit_message": "Publish DistributedVolume resource type v1.0.0"
}

Response 202 Accepted:
{
  "contribution_uuid": "<uuid>",
  "resource_type_fqn": "Storage.DistributedVolume",
  "status": "proposed",
  "review_required": true,
  "review_type": "human_review",
  "pr_url": "https://git.corp.example.com/dcm-registry/pulls/89"
}
```

### 6.3 Provider Service Layer Contribution

Providers contribute Service Layers that DCM applies during request assembly for their resource types:

```
POST /api/v1/provider/contribute/service-layer

{
  "resource_type_fqn": "Compute.VirtualMachine",
  "layer_handle": "providers/eu-west-prod-1/layers/vm-defaults",
  "layer_domain": "service",
  "provider_uuid": "<uuid>",
  "version": "2.0.0",
  "fields": {
    "hypervisor": { "value": "KVM", "metadata": { "override": "immutable" } },
    "network_segment": { "value": "prod-segment-01" },
    "backup_enabled": { "value": true }
  }
}
```

---

## 7. Federation Contribution Model

### 7.1 Peer DCM as Contributor

A federated peer DCM is a contributor to the receiving DCM's artifact stores, subject to the federation trust posture. This enables:

- **Hub DCM contributing policy templates** to Regional DCMs — standard compliance policies distributed from a central Hub
- **Community DCM registry contributions** — a community-maintained DCM instance publishing Verified Community resource type specs to subscribing organizations
- **Provider contributions across DCM boundaries** — a provider registered with DCM-A contributing its resource type specs to DCM-B through a verified federation relationship

### 7.2 Federation Contribution Trust Model

Federation contributions inherit the federation trust posture of the contributing peer:

| Peer trust posture | Contribution review requirement | Artifact types permitted |
|-------------------|--------------------------------|------------------------|
| `verified` | human_review (standard+); auto (dev) | Registry entries, policy templates, service layers |
| `vouched` | human_review always | Registry entries, service layers only |
| `provisional` | Committee approval | Registry entries only (no policies) |

**Hard rule:** A peer DCM cannot contribute artifacts at a higher domain level than its trust posture permits. A `vouched` peer cannot contribute system-domain policies. This is enforced by the Governance Matrix at the federation contribution boundary.

### 7.3 Federation Contribution Flow

```
Peer DCM publishes a contribution bundle:
  Content: resource type specs, policy templates, or layers
  Transport: federation tunnel (mTLS, signed, scoped credential)
  Metadata: contributing_dcm_uuid, trust_posture, artifact_list

Receiving DCM evaluates:
  1. Governance Matrix: is this peer permitted to contribute this artifact type?
  2. Signature verification: bundle signed by peer's private key?
  3. Structural validation: artifacts conform to DCM schemas?
  4. Domain scope check: artifacts within peer's permitted domain?

On validation pass:
  Artifacts enter proposed status in receiving DCM's policy/registry store
  Review flow per receiving DCM's profile + peer trust posture

On approval:
  Artifacts become active in receiving DCM
  Source attribution: contributed_by.dcm_uuid, contributed_by.trust_posture
```

### 7.4 Hub DCM Policy Distribution

In a Hub-Spoke federation, the Hub DCM is the authoritative source for platform-wide policy templates. Regional DCMs subscribe to the Hub's policy distribution feed:

```yaml
hub_policy_distribution:
  hub_dcm_uuid: <uuid>
  distribution_type: push          # Hub pushes on policy change
  auto_approve_from_hub: true      # prod profile: false; dev: true
  policy_handles_subscribed:
    - "system/compliance/hipaa/*"
    - "system/governance/drift-remediation"
  # Regional DCM always reviews before activating
  # Hub cannot force-activate policies on Regional DCMs
```

---

## 8. Artifact Lifecycle Across Contributors

### 8.1 Contributor Ownership and Transfer

Every artifact is owned by its contributor at creation. Ownership can be transferred:
- Consumer-authored policies transfer to a new Tenant admin when the original actor departs
- Provider-contributed catalog items remain owned by the provider registration
- Federation-contributed artifacts are owned by the contributing peer DCM

Ownership transfer requires the receiving owner's explicit acceptance (same model as entity ownership transfer in the Consumer API).

### 8.2 Platform Admin Override

Platform admins can override any contributor's artifact lifecycle at any time:
- Suspend an active consumer-authored policy that is causing harm
- Retire a provider-contributed resource type spec that is no longer safe
- Reject a proposed federation contribution without providing a public reason (security discretion)

Override actions are always audited with the overriding admin's actor UUID and reason.

### 8.3 Deprecation and Sunset

Contributors deprecate their own artifacts. When a Service Provider deprecates a resource type spec:
1. All consumers using that type receive deprecation notifications
2. A sunset period is declared (minimum: P30D for standard profile; P90D for prod/fsi/sovereign)
3. During sunset: new requests using the deprecated spec are warned; existing resources unaffected
4. After sunset: new requests using the deprecated spec are blocked
5. Platform admin must confirm final retirement

### 8.4 Orphaned Artifacts

When a contributor's access is revoked (actor departs, provider deregisters, peer DCM federation ends):
- Active artifacts remain active — orphaned artifacts do not automatically deactivate
- A platform admin is notified: "Artifact tenant/payments/gatekeeper/cost-ceiling has no active owner"
- Platform admin assigns a new owner or explicitly retires the artifact
- Auto-retire-on-orphan is configurable per profile (enabled in sovereign profile; disabled in standard)

---

## 9. The Contribution Store

All contributed artifacts are stored in the GitOps store with contributor attribution. The directory structure reflects the contributor hierarchy:

```
dcm-policy-store/
  system/                     # Platform admin authored; DCM built-in
    compliance/
    governance/
    orchestration/
  platform/                   # Platform admin authored; deployment-specific
    security/
    operations/
  tenant/
    <tenant-handle>/           # Consumer/Tenant authored
      gatekeeper/
      transformation/
      groups/
  provider/
    <provider-handle>/         # Provider authored
      layers/
      policies/
  federated/
    <peer-dcm-uuid>/           # Peer DCM contributed
      registry/
      policy-templates/

dcm-registry/
  core/                       # DCM project maintained
  community/                  # Community contributed (via community DCM)
    <contributor-handle>/
  organization/               # Organization contributed
    <provider-handle>/
```

Every artifact in the store includes a `contributed_by` block in its artifact metadata:

```yaml
artifact_metadata:
  uuid: <uuid>
  handle: "tenant/payments/gatekeeper/cost-ceiling"
  version: "1.0.0"
  status: active
  contributed_by:
    contributor_type: consumer       # platform_admin | consumer | service_provider | peer_dcm
    actor_uuid: <uuid>               # for consumer/platform_admin contributions
    tenant_uuid: <uuid>              # for consumer contributions
    provider_uuid: <uuid>            # for provider contributions
    peer_dcm_uuid: <uuid>            # for federation contributions
    contribution_method: api         # api | flow_gui | git_pr | federation_push
    pr_url: "https://..."            # if submitted via PR
    reviewed_by: [<actor_uuid>]      # actors who approved
    reviewed_at: <ISO 8601>
```

---

## 10. Profile-Governed Contribution Defaults

Each deployment profile has a default contribution policy that governs auto-approval eligibility, required review, and shadow mode defaults:

```yaml
contribution_policy:
  minimal:
    consumer_policy_auto_approve: true
    provider_spec_auto_approve: true
    federation_contribution_auto_approve: true    # dev/homelab: trust all
    shadow_mode_default: false

  dev:
    consumer_policy_auto_approve: true
    provider_spec_auto_approve: true
    federation_contribution_auto_approve: false   # human_review for federation
    shadow_mode_default: true                     # shadow mode on by default

  standard:
    consumer_policy_auto_approve: false           # human_review for all policies
    provider_spec_auto_approve: false
    federation_contribution_auto_approve: false
    shadow_mode_default: true
    shadow_review_period: P7D                     # 7 days of shadow before promotion

  prod:
    consumer_policy_auto_approve: false
    consumer_governance_matrix_requires: dual_approval
    provider_spec_auto_approve: false
    provider_spec_requires: human_review
    federation_contribution_requires: human_review
    shadow_mode_default: true
    shadow_review_period: P14D

  fsi:
    consumer_policy_auto_approve: false
    consumer_policy_requires: dual_approval
    consumer_governance_matrix_requires: dual_approval
    provider_spec_requires: dual_approval
    federation_contribution_requires: dual_approval
    shadow_mode_default: true
    shadow_review_period: P30D
    min_shadow_divergence_review: true            # must review all divergence cases

  sovereign:
    consumer_policy_requires: committee
    provider_spec_requires: committee
    federation_contribution_requires: committee
    shadow_mode_default: true
    shadow_review_period: P30D
    min_shadow_divergence_review: true
    auto_retire_orphaned_artifacts: true          # orphaned artifacts retire automatically
```

---

## 11. Governance Matrix Integration

The Governance Matrix evaluates every contribution at submission time. This is the enforcement point for the contributor permission table in Section 2.3.

**Contribution evaluation:**

```yaml
governance_matrix_rule:
  handle: "system/matrix/consumer-policy-scope"
  enforcement: hard
  match:
    subject.type: consumer
    data.artifact_type: policy
    data.domain: [system, platform]    # consumer attempting non-tenant domain
  decision: DENY
  reason: "Consumers may only contribute tenant-domain policies"

governance_matrix_rule:
  handle: "system/matrix/provider-spec-scope"
  enforcement: hard
  match:
    subject.type: service_provider
    data.artifact_type: resource_type_spec
    data.resource_type_fqn:
      not_in: subject.declared_resource_types   # provider contributing type they don't offer
  decision: DENY
  reason: "Providers may only contribute Resource Type Specs for resource types they offer"
```

---

## 12. System Policies

| Policy | Rule |
|--------|------|
| `FCM-001` | Every DCM data artifact has a contributor. The contributor is recorded in artifact_metadata.contributed_by at creation and is immutable. |
| `FCM-002` | Contributor permissions are enforced by the Governance Matrix at submission time. Domain scope violations are hard DENY — they cannot be overridden by the contributor. |
| `FCM-003` | All contributions flow through the GitOps PR model. No contributor can write directly to the authoritative artifact store without a PR review (unless the active profile grants auto-approval for that contributor type and artifact type combination). |
| `FCM-004` | Policies submitted by any contributor enter proposed (shadow) status by default. Shadow mode results must be available before the active profile's shadow_review_period expires. |
| `FCM-005` | Platform admins may override any contributor's artifact lifecycle at any time. Override actions are audited. |
| `FCM-006` | Orphaned artifacts (contributor access revoked) do not automatically deactivate. A platform admin assigns a new owner or explicitly retires them. Exception: sovereign profile auto-retires orphaned artifacts. |
| `FCM-007` | Federation contributions from peer DCMs are scoped by the peer's federation trust posture. Verified peers: human_review (standard+). Vouched peers: human_review always. Provisional peers: committee approval. |
| `FCM-008` | Contributor-tier scope limits are absolute. A consumer-authored policy in the tenant domain cannot affect the system or platform domain regardless of the policy's declared match conditions. |

---

*Document maintained by the DCM Project. For questions or contributions see [GitHub](https://github.com/dcm-project).*
