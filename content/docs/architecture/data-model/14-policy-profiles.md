# DCM Data Model — Policy Organization: Groups, Profiles, and Policy Providers


> **Universal Group Model:** Policy Groups (`group_class: policy_collection`) and Policy Profiles (`group_class: policy_profile`) are expressions of the [Universal Group Model](15-universal-groups.md). The structures defined in this document remain authoritative for policy-specific behavior; the universal model adds composability, cross-type membership, and the ability to include policy groups within composite groups.

**Document Status:** ✅ Complete  
**Related Documents:** [Scoring Model](29-scoring-model.md) | [Context and Purpose](00-context-and-purpose.md) | [Data Layers and Assembly](03-layering-and-versioning.md) | [Entity Relationships](09-entity-relationships.md) | [Storage Providers](11-storage-providers.md)

> **Foundation Document Reference**
>
> This document is a detailed reference for a specific domain of the DCM architecture.
> The three foundational abstractions — Data, Provider, and Policy — are defined in
> [00-foundations.md](00-foundations.md). All concepts in this document map to one or
> more of those three abstractions.
> See also: [Provider Contract](A-provider-contract.md) | [Policy Contract](B-policy-contract.md)
>
> **This document maps to: DATA + POLICY**
>
> Data: Policy Group and Profile artifacts. Policy: concern types and composition



---

> **Standards and Compliance Reference:** See [Standards and Compliance Catalog](40-standards-catalog.md) for the complete mapping of compliance frameworks (HIPAA, PCI DSS, FedRAMP, NIST SP 800-53, GDPR, DoD IL4) to DCM profiles and system requirements.

## 1. Purpose

DCM's Policy Engine is powerful — but power without usability is a barrier to adoption. This document defines the **policy organization model**: the structures that make DCM easy to configure correctly for any use case, from a home lab evaluation to a sovereign financial services deployment.

Three concepts work together:

- **Policy Groups** — cohesive collections of policies addressing a single identifiable concern (a technology, a compliance standard, a sovereignty requirement, a business process)
- **Policy Profiles** — complete DCM configurations for a specific use case, composed of Policy Groups
- **Policy Providers** — external authoritative sources that supply policies directly into DCM, extending the provider model to its fifth type

The relationship is compositional:

```
Policy Profile     — complete use-case configuration
  │  composed of
  ▼
Policy Groups      — single-concern policy collections
  │  composed of
  ▼
Policies           — individual Transformation / Validation / GateKeeper rules
  │  optionally sourced from
  ▼
Policy Providers   — external authoritative policy sources
```

---

## 1a. Design Priority Order in Policy Profiles

Profiles implement the DCM design priority order (see [Foundational Abstractions](00-foundations.md)):

1. **Security:** Profile defaults implement security correctly. Lower profiles have less strict enforcement — not absent security.
2. **Ease of use:** Profile defaults minimize configuration burden. `standard` profile should work for most deployments without customization.
3. **Extensibility:** Profiles compose with compliance domain overlays. Organizations add compliance requirements additively without rewriting base configuration.
4. **Fit for purpose:** Every profile must support the complete DCM lifecycle.

**The `minimal` profile is not "security optional"** — it is the security model with minimal operational overhead. All security properties are present; thresholds and automation levels are relaxed.

---

## 1b. Policy Authorship — Federated Contribution Model

Policies in DCM are not exclusively authored by platform admins. The DCM federated contribution model enables all actor types to author policies within their permitted domain scope:

- **Platform admins** — all domains, all policy types
- **Consumers / Tenant admins** — tenant domain policies (GateKeeper, Transformation, Recovery, Lifecycle, Orchestration Flow, Governance Matrix rules scoped to their Tenant)
- **Service Providers** — provider-domain GateKeeper and Validation policies for their resource types
- **Peer DCM instances** — policy templates contributed through verified federation relationships

This is not a special case — it is the standard GitOps PR model applied to all contributor types. Consumer-authored policies go through the same lifecycle (developing → proposed → active) with appropriate review requirements per the active profile. See [Federated Contribution Model](28-federated-contribution-model.md) for the complete specification.

---

## 2. Policy Groups
## 1a. Two-Dimensional Profile Model


### 1a.0 Profile — One Posture, Multiple Compliance Domains

**A DCM deployment runs exactly one Deployment Posture and zero or more Compliance Domain Groups simultaneously.** This is the complete profile model. No new concept is needed.

```
Active DCM Governance = one Deployment Posture + [zero or more Compliance Domains]

Examples:
  prod + hipaa                         ← healthcare production
  prod + hipaa + gdpr                  ← EU healthcare production  
  sovereign + fedramp-high + dod-il5   ← classified federal
  standard                             ← general enterprise, no compliance overlay
  dev + hipaa                          ← healthcare development (hipaa policies active,
                                          but operational cost reduced by dev posture)
```

**Deployment Postures are mutually exclusive** — you cannot be both `prod` and `dev`. One posture governs the operational characteristics of the entire DCM deployment.

**Compliance domains are additive** — HIPAA + FSI is valid and common. Each compliance domain group adds its own set of policies and constraints on top of the posture. They do not conflict with each other at the domain level (they govern different aspects of data handling); they may produce policy conflicts at the field level, which are resolved through the standard policy conflict resolution process.

**The dev posture and compliance domains** — applying `dev` posture to a HIPAA-scoped deployment does not remove HIPAA obligations. It relaxes the *operational cost* of meeting them: less redundancy, shorter retention windows where permitted, advisory enforcement where HIPAA allows flexibility. The HIPAA compliance domain group remains active and its mandatory controls remain enforced.

**Modules vs Profiles** — DCM uses both concepts with distinct meanings:
- A **Profile** is a governance configuration: it declares how DCM behaves and what operational and compliance requirements apply.
- A **Module** is a capability extension: it adds new functions to DCM (e.g., a HIPAA record validator, a custom resource type). Modules are not profiles and do not configure DCM behavior — they extend what DCM can do.


### 1a.1 The Gap in the Original Model

The original six profiles (minimal → sovereign) are organized around **deployment posture** — how strict, how redundant, how governed. But organizations need compliance governance that is orthogonal to posture. A healthcare organization needs HIPAA controls regardless of whether they deploy at `standard` or `sovereign` posture. A payment processor needs PCI-DSS regardless of their redundancy profile.

The new model makes compliance a first-class dimension that composes with posture:

```
Complete Profile = Deployment Posture Group + Compliance Domain Group(s)
```

### 1a.2 Dimension 1 — Deployment Posture Groups

Posture groups govern how the DCM infrastructure itself behaves — redundancy, enforcement strictness, audit retention, tenancy model, cross-tenant defaults. These are the vertical axis from least to most governed.

| Group Handle | Posture | Key Behaviors |
|-------------|---------|--------------|
| `system/group/posture-minimal` | Minimal | Advisory only; single instance; no redundancy |
| `system/group/posture-dev` | Development | Warn-not-block; basic logging; ephemeral defaults |
| `system/group/posture-standard` | Standard | Full enforcement; 3-replica; explicit cross-tenant |
| `system/group/posture-prod` | Production | Full enforcement + SLA; geo-replicated; cost governance |
| `system/group/posture-hardened` | Enterprise Hardened | 5-replica; 7-year audit; hard tenancy; dual approval |
| `system/group/posture-sovereign` | Sovereign | Air-gap; deny_all cross-tenant; 10-year audit; signed bundles |

### 1a.3 Dimension 2 — Compliance Domain Groups

Compliance domain groups govern what data handling, audit, and control requirements apply to resources managed by DCM. Multiple compliance domains can apply simultaneously.

| Group Handle | Domain | Key Controls |
|-------------|--------|-------------|
| `system/group/compliance-fsi` | Financial Services | Basel III, SOX, Dodd-Frank financial controls |
| `system/group/compliance-pci-dss` | Payment Card | PCI-DSS v4 — payment card industry |
| `system/group/compliance-hipaa` | Healthcare | HIPAA/HITECH PHI handling and audit |
| `system/group/compliance-fedramp-moderate` | US Federal Moderate | FedRAMP Moderate — NIST 800-53 Moderate baseline |
| `system/group/compliance-fedramp-high` | US Federal High | FedRAMP High — NIST 800-53 High baseline |
| `system/group/compliance-dod-il2` | DoD IL2 | Public/unclassified defense data |
| `system/group/compliance-dod-il4` | DoD IL4 | Controlled Unclassified Information (CUI) |
| `system/group/compliance-dod-il5` | DoD IL5 | National Security Systems non-classified |
| `system/group/compliance-dod-il6` | DoD IL6 | Classified — maximum sovereign posture |
| `system/group/compliance-government` | Government General | General government/public sector controls |
| `system/group/compliance-gdpr` | EU Data Protection | GDPR data residency and rights |
| `system/group/compliance-iso27001` | ISO 27001 | Information security management |
| `system/group/compliance-nist-800-53` | NIST 800-53 | NIST security control framework |
| `system/group/compliance-soc2` | SOC 2 | Service organization controls |
| `system/group/compliance-nerc-cip` | Critical Infrastructure | Energy/utilities NERC CIP |
| `system/group/compliance-sovereign` | Sovereign/Classified | Sovereign deployment, air-gap, classified |

### 1a.4 Compliance Domain Group Contents

#### `system/group/compliance-hipaa`

HIPAA/HITECH controls for Protected Health Information (PHI):
- PHI field classification enforcement (fields containing PHI must be tagged `phi: true`)
- PHI access control (only roles with `phi_authorized: true` may access PHI-tagged fields)
- Audit retention: P6Y minimum (HIPAA requires 6 years from creation or last use)
- Encryption at rest: AES-256 required for all PHI storage
- Transmission security: TLS 1.3 minimum for PHI in transit
- Breach notification workflow: sovereignty_violation_record triggers HIPAA breach assessment
- Business Associate Agreement (BAA) tracking: providers handling PHI must declare `baa_in_place: true` in sovereignty_declaration
- Right to Access: consumer data export capability required for PHI entities
- Minimum Necessary standard: data_request_spec on Mode 4 providers limited to minimum PHI fields

#### `system/group/compliance-government`

General government and public sector controls:
- Data classification mandatory on all resources (classification_level field required)
- Cross-boundary controls: data cannot cross classification levels without explicit policy
- Audit retention: P10Y minimum
- Air-gap capability required for Sensitive compartments
- Actor authentication must declare clearance level in external_identity claims
- All provider sovereignty_declarations must declare government_access_risk

#### `system/group/compliance-fedramp-moderate`

FedRAMP Moderate authorization controls:
- NIST 800-53 Rev 5 Moderate baseline implemented as policy group
- FedRAMP-authorized provider preference injected as placement constraint
- Continuous monitoring: drift detection mandatory; P24H maximum drift resolution window
- Incident response: webhook required for security events (audit.chain_break, drift.escalated)
- POA&M tracking: `poam_status` field in status_metadata on all policy artifacts
- Boundary protection: explicit ingress/egress control documentation

#### `system/group/compliance-dod-il4`

DoD Impact Level 4 — Controlled Unclassified Information:
- Inherits compliance-fedramp-moderate
- CUI handling markers on all data fields containing controlled information
- Sovereign posture within US jurisdiction boundary
- Provider sovereignty_declaration must exclude foreign sub-processors
- CMMC Level 2 cyber hygiene controls

#### `system/group/compliance-sovereign`

Sovereign and classified deployment controls:
- All data must remain within declared sovereignty boundary
- Air-gap capability: provider air_gap_capable: true required
- Signed bundle import only — no live registry connectivity
- deny_all cross-tenant cross-boundary data flows
- Hardware security module (HSM) required for key management
- Audit records: 10-year retention; cryptographic signing required

### 1a.5 Profile Composition Model

The six built-in profiles become explicit posture+compliance compositions:

```yaml
system/profile/minimal:
  policy_groups: [system/group/posture-minimal]

system/profile/dev:
  extends: system/profile/minimal
  policy_groups: [system/group/posture-dev]

system/profile/standard:
  extends: system/profile/dev
  policy_groups: [system/group/posture-standard]

system/profile/prod:
  extends: system/profile/standard
  policy_groups: [system/group/posture-prod]

system/profile/fsi:
  extends: system/profile/prod
  policy_groups:
    - system/group/posture-hardened
    - system/group/compliance-fsi
    - system/group/compliance-pci-dss
    - system/group/compliance-iso27001

system/profile/sovereign:
  extends: system/profile/fsi
  policy_groups:
    - system/group/posture-sovereign
    - system/group/compliance-sovereign
```

### 1a.6 DCM Built-In Extended Profiles

In addition to the six core profiles, DCM ships extended profiles for common compliance domains:

```yaml
system/profile/hipaa-prod:
  extends: system/profile/prod
  policy_groups:
    - system/group/compliance-hipaa
    - system/group/compliance-iso27001
  description: "Production infrastructure with HIPAA/HITECH compliance"

system/profile/hipaa-sovereign:
  extends: system/profile/sovereign
  policy_groups:
    - system/group/compliance-hipaa
  description: "Sovereign deployment with HIPAA/HITECH compliance — highest healthcare posture"

system/profile/fedramp-moderate:
  extends: system/profile/prod
  policy_groups:
    - system/group/compliance-fedramp-moderate
    - system/group/compliance-nist-800-53
  description: "FedRAMP Moderate authorized deployment"

system/profile/fedramp-high:
  extends: system/profile/sovereign
  policy_groups:
    - system/group/compliance-fedramp-high
    - system/group/compliance-nist-800-53
  description: "FedRAMP High authorized deployment"

system/profile/government:
  extends: system/profile/prod
  policy_groups:
    - system/group/compliance-government
    - system/group/compliance-nist-800-53
  description: "General government and public sector deployment"

system/profile/dod-il4:
  extends: system/profile/sovereign
  policy_groups:
    - system/group/compliance-dod-il4
    - system/group/compliance-fedramp-high
    - system/group/compliance-nist-800-53
  description: "DoD Impact Level 4 — Controlled Unclassified Information"

system/profile/dod-il5:
  extends: system/profile/dod-il4
  policy_groups:
    - system/group/compliance-dod-il5
  description: "DoD Impact Level 5 — National Security Systems non-classified"

system/profile/dod-il6:
  extends: system/profile/dod-il5
  policy_groups:
    - system/group/compliance-dod-il6
    - system/group/compliance-sovereign
  description: "DoD Impact Level 6 — Classified"
```

### 1a.7 Organization Custom Profiles — Composition Examples

```yaml
# Healthcare with federal cloud authorization
org/profile/hipaa-fedramp:
  extends: system/profile/fedramp-moderate
  policy_groups:
    - system/group/compliance-hipaa
  description: "Healthcare workloads on FedRAMP Moderate platform"

# Multi-compliance financial + healthcare
org/profile/fsi-hipaa:
  extends: system/profile/fsi
  policy_groups:
    - system/group/compliance-hipaa
  description: "FSI-grade deployment for organizations managing both financial and health data"

# Tenant-level compliance override — platform is standard; this Tenant is PCI-scoped
# (declared in tenant_config — not profile)
tenant_compliance_overlay:
  active_profile: system/profile/standard    # platform posture
  compliance_groups:
    - system/group/compliance-pci-dss        # this Tenant handles payment cards
    - system/group/compliance-hipaa          # this Tenant also handles PHI
  # Other Tenants on same platform have standard posture, no compliance overlay
```

### 1a.8 Compliance at Tenant Level

Compliance domain groups may apply at Tenant level — different Tenants on the same DCM deployment can have different compliance domains:

```yaml
tenant_config:
  active_profile: system/profile/prod        # posture from platform
  compliance_groups:
    - system/group/compliance-hipaa          # this Tenant handles PHI
    - system/group/compliance-pci-dss        # this Tenant processes payments
```

This is the critical capability: **one DCM deployment, multiple compliance postures per Tenant**. A hospital system can run a single DCM with: clinical Tenants (HIPAA), billing Tenants (HIPAA + PCI-DSS), and administrative Tenants (standard) — all on the same platform profile.

### 1a.9 System Policies — Profile Composition

| Policy | Rule |
|--------|------|
| `PROF-001` | Profiles compose a Deployment Posture Group with zero or more Compliance Domain Groups. Posture groups govern DCM infrastructure behavior. Compliance domain groups govern data handling, audit, and control requirements. |
| `PROF-002` | Compliance Domain Groups may be applied at platform level (all Tenants) or Tenant level (specific Tenants). Tenant-level compliance groups are additive — they do not replace platform-level groups. |
| `PROF-003` | DCM ships built-in Compliance Domain Groups for: FSI, PCI-DSS, HIPAA/HITECH, FedRAMP Moderate, FedRAMP High, DoD IL2-IL6, Government, GDPR, ISO 27001, NIST 800-53, SOC2, NERC-CIP, and Sovereign/Classified. Organizations extend these groups or compose them into custom profiles. |
| `PROF-004` | The `implementation_posture` concern_type Policy Groups (provenance model, auth simplicity, deployment complexity) are independent of compliance domain — organizations select their implementation posture separately from their compliance requirements. |

---


### 2.1 Definition

A **Policy Group** is a versioned, cohesive collection of policies that together address a **single identifiable concern**. The group is the unit of reuse — activate a group to enable a concern, not individual policies.

```yaml
policy_group:
  artifact_metadata:
    uuid: <uuid>
    handle: "system/group/pci-dss"
    version: "1.2.0"
    status: active
    owned_by:
      display_name: "DCM Project Team"
      notification_endpoint: <endpoint>

  name: "PCI-DSS v4"
  description: >
    Policy group implementing PCI-DSS v4 controls relevant to
    DCM-managed infrastructure. Enforces encryption standards,
    network segmentation, access control, and audit requirements
    for resources in PCI scope.

  concern_type: compliance
  concern_tags: [pci-dss, financial, encryption, network-segmentation]
  extends: null   # or another group handle — inherits all parent policies

  # Source — locally authored or from a Policy Provider
  source:
    type: <local | policy_provider>
    provider_uuid: <uuid — if policy_provider>
    provider_group_reference: <provider's identifier for this group>
    on_provider_update: <proposed | active>
    # proposed: provider updates require local review before activation
    # active:   provider updates activate immediately (trusted providers only)

  # Constituent policies
  policies:
    - policy_uuid: <uuid>
      handle: "system/gatekeeper/pci-encryption-aes256"
      description: "Enforce AES-256 on all PCI-scoped storage"
      placement_phase: pre
    - policy_uuid: <uuid>
      handle: "system/validation/pci-network-segmentation"
      description: "Validate network segment isolation for PCI resources"
      placement_phase: pre
    - policy_uuid: <uuid>
      handle: "system/transformation/pci-classification-inject"
      description: "Auto-inject PCI classification on scoped resources"
      placement_phase: pre
    - policy_uuid: <uuid>
      handle: "system/gatekeeper/pci-audit-retention"
      description: "Enforce 10-year audit retention for PCI evidence"
      placement_phase: pre

  # Activation scope — surgical application within a profile
  activation_scope:
    resource_types: []          # empty = all resource types
    tenant_tags: [pci-scope]    # only Tenants tagged pci-scope
    regions: []                 # empty = all regions

  # Conflict declarations
  conflicts_with:
    - group_handle: "system/group/dev-defaults"
      reason: "PCI requires blocking enforcement; dev-defaults uses warn-only"
      resolution: this_group_wins
```

### 2.2 Concern Types

| Type | Description | Examples |
|------|-------------|---------|
| `technology` | Policies specific to a technology or provider | kubevirt, openstack, kubernetes, vmware |
| `compliance` | Regulatory or standards compliance | pci-dss, iso-27001, nist-800-53, fedramp |
| `sovereignty` | Data residency, jurisdictional, air-gap | gdpr-eu, air-gap, data-residency-uk |
| `business` | Business process, cost, lifecycle governance | cost-governance, ephemeral-resources, chargeback |
| `operational` | Operational posture, defaults, SLAs | dev-defaults, hard-tenancy, sla-enforcement |
| `security` | Security controls and posture | data-classification, zero-trust, encryption-baseline |
| `implementation_posture` | Implementation complexity vs capability trade-offs | provenance-full-inline, provenance-deduplicated, single-instance-deployment, advisory-policies-only |

### 2.3 Group Inheritance

A Policy Group may extend another group — inheriting all its policies and overriding or adding to them:

```yaml
policy_group:
  handle: "org/group/pci-dss-extended"
  extends: "system/group/pci-dss"
  # Inherits all system/group/pci-dss policies
  # Additional policies added below are on top of the parent
  policies:
    - policy_uuid: <uuid>
      handle: "org/gatekeeper/our-pci-additional-control"
```

### 2.4 DCM Built-In Policy Groups

DCM ships the following policy groups as part of its standard distribution:

| Handle | Concern | Description |
|--------|---------|-------------|
| `system/group/core-minimal` | operational | Absolute minimum — UUID requirements, basic well-formedness |
| `system/group/dev-defaults` | operational | Warn-not-block, 90-day TTL defaults, single-auth cross-tenant |
| `system/group/ephemeral-resources` | business | TTL enforcement, auto-expiry, short-lived resource defaults |
| `system/group/audit-basic` | operational | Basic audit logging, 90-day retention |
| `system/group/audit-compliance` | compliance | Compliance-grade audit, configurable retention |
| `system/group/data-classification` | security | Data classification tagging and handling rules |
| `system/group/cost-governance` | business | Budget enforcement, cost attribution, TTL governance |
| `system/group/sla-enforcement` | operational | SLA tracking, availability commitments |
| `system/group/hard-tenancy` | operational | Full tenant isolation, deny_all cross-tenant default |
| `system/group/explicit-cross-tenant` | operational | Explicit cross-tenant authorization requirement (XTA-001 through XTA-005) |
| `system/group/zero-trust` | security | Zero-trust network and identity enforcement |
| `system/group/encryption-baseline` | security | AES-256 minimum, TLS 1.3, key rotation |
| `system/group/pci-dss` | compliance | PCI-DSS v4 controls |
| `system/group/gdpr-eu` | sovereignty | GDPR data residency and handling |
| `system/group/nist-800-53` | compliance | NIST 800-53 control implementation |
| `system/group/iso-27001` | compliance | ISO 27001 controls |
| `system/group/fedramp-moderate` | compliance | FedRAMP Moderate baseline |
| `system/group/air-gap` | sovereignty | Air-gapped deployment constraints |
| `system/group/fsi-audit` | compliance | Financial services audit retention (7-year minimum) |
| `system/group/lifecycle-ttl-enforcement` | operational | Lifecycle time constraint enforcement (LTC-001 through LTC-004) |
| `system/group/kubevirt` | technology | KubeVirt provider-specific policies |
| `system/group/openstack` | technology | OpenStack provider-specific policies |
| `system/group/vmware` | technology | VMware provider-specific policies |
| `system/group/provenance-full-inline` | implementation_posture | Model A — all provenance inline on entity records; simplest; highest storage cost |
| `system/group/provenance-deduplicated` | implementation_posture | Model B — content-addressed deduplication; recommended; 95-99% storage reduction; lossless |
| `system/group/provenance-tiered-archive` | implementation_posture | Model C — hot/warm/cold tiers; balances cost and access speed |
| `system/group/provenance-deduplicated-tiered` | implementation_posture | Model B+C — maximum efficiency for very large-scale deployments |

---

## 3. Policy Profiles

### 3.1 Definition

A **Policy Profile** is a named, versioned, curated composition of Policy Groups that together configure DCM for a specific use case. Activating a profile is the primary configuration mechanism — most deployments should activate a profile and then add organization-specific groups on top rather than configuring policies individually.

```yaml
policy_profile:
  artifact_metadata:
    uuid: <uuid>
    handle: "system/profile/fsi"
    version: "1.0.0"
    status: active
    owned_by:
      display_name: "DCM Project Team"

  name: "FSI Production"
  description: >
    Policy profile for Financial Services production deployments.
    Enforces hard tenancy, regulatory-grade audit retention,
    full sovereignty controls, and explicit cross-tenant authorization.

  target_use_case: fsi_production
  extends: "system/profile/prod"   # inherits all prod groups + overrides

  enforcement_summary:
    tenancy: hard_tenancy_required
    audit_retention_years: 7
    sovereignty: full
    cross_tenant_default: explicit_only
    policy_enforcement: blocking
    immutable_fields: [sovereignty_zone, classification_level, audit_retention]
    policy_version_pinning: permitted_with_elevation

  policy_groups:
    - group_handle: "system/group/fsi-audit"
    - group_handle: "system/group/pci-dss"
    - group_handle: "system/group/gdpr-eu"
    - group_handle: "system/group/hard-tenancy"
    - group_handle: "system/group/explicit-cross-tenant"
    - group_handle: "system/group/encryption-baseline"
```

### 3.2 DCM Built-In Profiles

DCM ships six profiles covering the spectrum from minimal to sovereign:

#### `system/profile/minimal` — Home Lab / Evaluation

```yaml
handle: "system/profile/minimal"
name: "Minimal"
extends: null
description: >
  Minimal configuration for home lab, local testing, and evaluation.
  Most controls advisory only. Single Tenant auto-created on first use.
  No audit requirements. No sovereignty enforcement.

enforcement_summary:
  tenancy: optional
  audit_retention: none
  sovereignty: none
  cross_tenant_default: allow_all
  policy_enforcement: advisory     # policies warn but do not block
  time_constraints: optional

auto_tenant:
  enabled: true
  default_tenant_handle: "default"
  # TEN-001 satisfied silently — no explicit Tenant declaration required

policy_groups:
  - group_handle: "system/group/core-minimal"
```

#### `system/profile/dev` — Development Environments

```yaml
handle: "system/profile/dev"
name: "Development"
extends: "system/profile/minimal"
description: >
  Development environment profile. Tenancy recommended but not blocking.
  Basic logging. Ephemeral resource defaults. Warn-not-block enforcement.

enforcement_summary:
  tenancy: recommended
  audit_retention: basic
  sovereignty: none
  cross_tenant_default: operational_only
  policy_enforcement: warn_only
  default_ttl: P90D              # dev resources default to 90-day TTL

policy_groups:
  - group_handle: "system/group/dev-defaults"
  - group_handle: "system/group/ephemeral-resources"
  - group_handle: "system/group/audit-basic"
```

#### `system/profile/standard` — General Enterprise Production

```yaml
handle: "system/profile/standard"
name: "Standard"
extends: "system/profile/dev"
description: >
  General enterprise production profile. Full policy enforcement.
  Tenancy required. Explicit cross-tenant authorization. Basic
  data classification. Compliance-grade audit.

enforcement_summary:
  tenancy: required
  audit_retention: compliance_grade
  sovereignty: configurable
  cross_tenant_default: explicit_only
  policy_enforcement: blocking

policy_groups:
  - group_handle: "system/group/data-classification"
  - group_handle: "system/group/audit-compliance"
  - group_handle: "system/group/explicit-cross-tenant"
  - group_handle: "system/group/encryption-baseline"
```

#### `system/profile/prod` — Production with SLA Requirements

```yaml
handle: "system/profile/prod"
name: "Production"
extends: "system/profile/standard"
description: >
  Production profile with SLA enforcement, cost governance, and
  full lifecycle constraint enforcement.

enforcement_summary:
  tenancy: required
  audit_retention: compliance_grade
  sovereignty: configurable
  cross_tenant_default: explicit_only
  policy_enforcement: blocking

policy_groups:
  - group_handle: "system/group/cost-governance"
  - group_handle: "system/group/sla-enforcement"
  - group_handle: "system/group/lifecycle-ttl-enforcement"
```

#### `system/profile/fsi` — Financial Services Production

```yaml
handle: "system/profile/fsi"
name: "FSI Production"
extends: "system/profile/prod"
description: >
  Financial services production. Hard tenancy. 7-year audit retention.
  Full sovereignty enforcement. PCI-DSS and GDPR compliance.

enforcement_summary:
  tenancy: hard_tenancy_required
  audit_retention_years: 7
  sovereignty: full
  cross_tenant_default: explicit_only
  policy_enforcement: blocking

policy_groups:
  - group_handle: "system/group/fsi-audit"
  - group_handle: "system/group/pci-dss"
  - group_handle: "system/group/gdpr-eu"
  - group_handle: "system/group/hard-tenancy"
```

#### `system/profile/sovereign` — Air-Gapped / Sovereign Deployments

```yaml
handle: "system/profile/sovereign"
name: "Sovereign"
extends: "system/profile/fsi"
description: >
  Maximum control profile for air-gapped, sovereign, and highest-security
  deployments. Complete tenant isolation. Zero external dependencies.
  Maximum audit and sovereignty enforcement.

enforcement_summary:
  tenancy: hard_tenancy_required
  audit_retention_years: 10
  sovereignty: maximum
  cross_tenant_default: deny_all
  policy_enforcement: blocking
  immutable_ceiling_on_all_sovereignty_fields: true

policy_groups:
  - group_handle: "system/group/air-gap"
  - group_handle: "system/group/zero-trust"
```

### 3.3 Profile Inheritance Chain

```
system/profile/sovereign
  extends: system/profile/fsi
    extends: system/profile/prod
      extends: system/profile/standard
        extends: system/profile/dev
          extends: system/profile/minimal
            extends: null (base)
```

Each level adds groups without replacing parent groups. An organization extending a DCM profile only needs to declare what differs:

```yaml
# Organization custom profile
org/profile/my-prod:
  extends: system/profile/prod
  policy_groups:
    - group_handle: "org/group/our-naming-conventions"
    - group_handle: "org/group/our-cost-centers"
    - group_handle: "system/group/iso-27001"    # add a DCM compliance group
```

### 3.4 Profile Activation

Profiles activate at three levels — more specific takes precedence:

```yaml
# DCM installation default
installation_config:
  default_profile: "system/profile/minimal"

# Platform-level (applies to all Tenants)
platform_config:
  active_profile: "system/profile/prod"
  minimum_tenant_profile: "system/profile/dev"   # Tenants cannot go below this
  maximum_tenant_profile: null                    # null = no ceiling

# Tenant-level override
tenant_config:
  active_profile: "system/profile/fsi"           # must be >= minimum_tenant_profile
```

**A Tenant cannot activate a profile less restrictive than the platform minimum.** A sovereign deployment can set `minimum_tenant_profile: system/profile/sovereign` — no Tenant can drop below that level.

### 3.5 Profile Conflict Resolution

When a profile is activated, DCM runs conflict detection across all constituent group policies — same ingestion conflict detection that layers use. Conflicts must be resolved before a profile is marked `active`.

Conflict resolution order:
1. **Explicit `conflicts_with` declarations** on groups — use declared resolution rule
2. **Priority schema** — higher numeric priority wins
3. **Domain authority** — `system` beats `platform` beats `tenant`
4. **Unresolved** — profile activation fails with detailed conflict report

### 3.6 Profile Shadow Validation

When a profile is in `proposed` status, all its constituent policies run in shadow mode — the same proposed policy shadow execution model. The Validation Dashboard shows the aggregate impact across all policies in the profile before activation. This enables safe preview of what a profile upgrade would do to an existing deployment.

---

## 4. Policy Providers

### 4.1 Policy Provider (one of eleven DCM provider types)

A **Policy Provider** is a fifth DCM provider type — an external authoritative source that supplies policies directly into DCM or evaluates and enriches DCM data through an external logic engine.

| Type | Purpose | DCM Owns Result? |
|------|---------|-----------------|
| **Service Provider** | Realizes resources | Yes |
| **Information Provider** | Serves authoritative external data | No |
| **Meta Provider** | Composes multiple providers | Yes |
| **Storage Provider** | Persists DCM state | Yes |
| **Policy Provider** | Supplies policies from external authoritative sources, or evaluates and enriches data via external logic | Policies and enrichment data become DCM-owned on import |

**Why Policy Providers?** Organizations should not need to manually translate regulatory controls, security benchmarks, or vendor-specific policies into DCM format. A Policy Provider is the authoritative source — DCM subscribes to it and receives updates automatically. For Mode 4, the external system is the authoritative logic engine — DCM queries it and acts on the result.

### 4.2 The Four Policy Provider Delivery Modes

| Mode | Name | How it works | Logic lives in |
|------|------|-------------|---------------|
| **Mode 1** | DCM Native Push/Pull | Provider delivers DCM-format policy artifacts | DCM Policy Engine |
| **Mode 2** | OPA/Rego Bundle | Provider delivers OPA Rego bundles | DCM Policy Engine (OPA) |
| **Mode 3** | External Schema | Provider delivers external-format policies requiring naturalization | DCM Policy Engine (post-translation) |
| **Mode 4** | Black Box Query-Enrichment | DCM sends a query, provider evaluates and/or enriches, returns structured result | External provider — logic is opaque to DCM |

Modes 1-3 are **policy delivery** modes — the provider sends rules, DCM stores and executes them. Mode 4 is fundamentally different: the policy logic lives in the external system. DCM sends data, receives a result, and acts on it.

### 4.3 Policy Provider Contract — Modes 1-3

Policy Providers in Modes 1-3 follow the same base contract as all providers: registration, health check, trust, and provenance emission.

```yaml
policy_provider_registration:
  artifact_metadata:
    uuid: <uuid>
    handle: "providers/policy/grc-platform-001"
    version: "1.0.0"
    status: active
    owned_by:
      display_name: "Security Team"
      notification_endpoint: <endpoint>

  name: "Enterprise GRC Platform"
  description: "Publishes compliance controls from GRC platform to DCM"

  delivery:
    mode: <push | pull | webhook>
    pull_schedule: "0 2 * * *"    # cron — if mode: pull
    endpoint: <provider API endpoint>

  policy_format: <dcm_native | opa_rego | external_schema>

  managed_domains:
    concern_types: [compliance, sovereignty]
    concern_tags: [pci-dss, gdpr, iso-27001]

  trust_level: <trusted | verified | untrusted>
  max_policy_authority: gatekeeper

  on_update: proposed
  on_provider_failure:
    action: <deprecate | retain | alert>
    sunset_days: 30
```

### 4.4 Policy Naturalization (Mode 3)

When a Policy Provider delivers policies in an external format, DCM applies **Policy Naturalization** — translating external policy schemas into DCM policy format.

```
External Policy Format (OSCAL, XACML, CIS JSON, STIG XCCDF)
  │
  ▼  Policy Naturalization (translator component)
  │
  ▼
DCM Policy Format (standard DCM policy artifact)
  │
  ▼  Trust validation + conflict detection
  │
  ▼
DCM Policy Engine
```

```yaml
naturalization:
  source_schema: oscal           # oscal | xccdf | cis-json | xacml | custom
  translator_uuid: <uuid>
  validation_on_import: strict   # strict | lenient
```

### 4.5 Policy Provider and Policy Groups

A Modes 1-3 Policy Provider can deliver at three levels of granularity:

- **Individual policies** — administrator manually assigns to groups
- **Complete Policy Groups** — provider supplies group definitions alongside policies
- **Complete Policy Profiles** — provider supplies a full deployment profile for one-step activation

```yaml
policy_group:
  handle: "org/group/grc-pci-dss"
  source:
    type: policy_provider
    provider_uuid: <uuid>
    provider_group_reference: "pci-dss-v4-full"
    on_provider_update: proposed
    last_synced: <ISO 8601>
    provider_version: "4.0.1"
```

### 4.6 Trust Levels and Policy Authority

| Trust Level | Max Policy Authority | Requires | Use Case |
|-------------|---------------------|----------|---------|
| `trusted` | GateKeeper | Manual elevation + dual approval | Regulatory body, certified compliance package |
| `verified` | Validation | Registration + health check | Security vendor, GRC platform |
| `untrusted` | Advisory (logged but not executed) | Registration only | Evaluation, new providers |

Trust elevation requires explicit authorization from both a platform admin and a security owner.

### 4.7 Policy Provider Health and Lifecycle

- **Healthy** — policies current, delivery working normally
- **Degraded** — delivery delayed or partial — warnings emitted
- **Unhealthy** — policies move toward `deprecated` per `on_provider_failure` declaration
- **Deregistered** — policies deprecated with configured sunset

---

### 4.8 Mode 4 — Black Box Query-Enrichment

#### 4.8.1 Concept

A **Mode 4 Policy Provider** is an external system that DCM queries during the assembly process to evaluate request data, return a decision, enrich the payload with additional fields, or do both simultaneously.

**The key distinction from Modes 1-3:** The policy logic lives in the external system and is opaque to DCM. DCM does not receive or store the rules — it sends a query and receives a structured result. The external system is the authoritative evaluator and enricher.

**Mode 4 providers can:**
- **Evaluate** — return a pass/fail, score, or recommendation based on the query
- **Enrich** — inject additional fields into the payload (risk scores, compliance citations, cost predictions, organizational context, case references)
- **Do both** — evaluate and enrich in a single atomic query-response cycle

**Examples:**
- AI/ML risk scoring engine — returns risk score AND injects mitigation recommendations
- Compliance oracle — returns pass/fail AND injects compliance citations
- FinOps cost predictor — returns predicted cost AND injects cost allocation metadata
- Sovereignty verification service — returns jurisdiction compliance AND injects residency certificates
- Fraud detection system — returns anomaly score AND injects case reference number
- Identity enrichment service — returns authorization AND injects organizational context (business unit, cost center, project codes)
- Privileged access management system — returns allow/deny AND injects access justification record

#### 4.8.2 Governance Concerns

Mode 4 introduces governance concerns that Modes 1-3 do not:

**Data sovereignty on outbound data:** DCM is sending request payload data — potentially sensitive — to an external system. Before any data is sent, DCM must verify the provider is authorized to receive the data classifications present in the query. A sovereign deployment must prevent any data from leaving its boundary without explicit authorization.

**Result integrity:** The black box returns a result that DCM acts on. The logic is opaque — DCM cannot inspect it. The provenance chain must record the full query-response cycle: what was sent, what was returned, what action was taken, and the provider's audit token for cross-system correlation.

**Enrichment governance:** Fields injected by a Mode 4 provider carry the same provenance obligations as fields injected by a Transformation Policy. The override control model applies — a GateKeeper can refuse black box enrichment on sovereignty-sensitive fields. Enrichment output may itself carry classification implications and must be governed accordingly.

**Failure behavior:** The black box is external and can be unavailable, slow, or malformed. Failure behavior must be explicitly declared — the default is `gatekeep` (unknown is not safe).

**Non-determinism:** A Mode 4 provider may return different results for the same input at different times (e.g., a risk model updated overnight). Result caching must be declared — and cached results carry a validity period.

#### 4.8.3 Registration — Mode 4 Specific Fields

```yaml
policy_provider_registration:
  artifact_metadata:
    uuid: <uuid>
    handle: "providers/policy/risk-scoring-engine"
    version: "1.0.0"
    status: active
    owned_by:
      display_name: "Security Engineering Team"
      notification_endpoint: <endpoint>

  name: "Enterprise Risk Scoring Engine"
  description: >
    ML-based risk scoring and enrichment for infrastructure requests.
    Returns risk score and injects mitigation recommendations.

  delivery:
    mode: black_box_query           # Mode 4
    endpoint: <query API endpoint>
    query_protocol: <rest | grpc | graphql>
    timeout_seconds: 30
    on_timeout: gatekeep            # gatekeep | allow | escalate
    on_error: gatekeep
    on_unavailable: gatekeep

  # What data this provider is authorized to receive
  data_request_spec:
    fields_requested:
      - field: resource_type
        classification_ceiling: unclassified
      - field: placement.selected_provider_uuid
        classification_ceiling: internal
      - field: requester.tenant_uuid
        classification_ceiling: internal
      - field: lifecycle_constraints.ttl
        classification_ceiling: unclassified
    # Fields NOT declared here are NEVER sent — DCM enforces data minimization
    # classification_ceiling: maximum classification level this provider may receive

  # Where the provider operates — sovereignty gating
  operational_sovereignty:
    jurisdiction: eu-west
    certifications: [ISO-27001, GDPR-compliant, SOC2-Type2]
    # DCM checks these against Tenant sovereignty requirements
    # before authorizing any query

  # Result and enrichment capabilities
  result_capabilities:
    result_type: <pass_fail | score | recommendation | enrichment | multi_factor>
    # pass_fail:    decision only
    # score:        numeric score with optional threshold
    # recommendation: structured recommendation
    # enrichment:   data injection only — no decision
    # multi_factor: decision + enrichment combined

    # Decision component schema (if applicable)
    decision_schema:
      outcome_field: outcome        # field name in response
      score_field: score            # field name for numeric score
      confidence_field: confidence
      citations_field: citations
      expires_at_field: expires_at
      audit_token_field: audit_token

    # Enrichment component schema (if applicable)
    enrichment_schema:
      fields_injected:
        - field: risk_score
          type: float
          classification: internal
        - field: risk_citations
          type: array
          classification: internal
        - field: recommended_mitigations
          type: array
          classification: internal

  # Result caching
  result_caching:
    enabled: true
    ttl_seconds: 300
    cache_key_fields: [resource_type, requester.tenant_uuid]

  trust_level: verified
  max_policy_authority: transformation   # enrichment = transformation authority
  # A Mode 4 provider that only evaluates can have validation or gatekeeper authority
  # A Mode 4 provider that enriches requires at minimum transformation authority
```

#### 4.8.4 Data Sovereignty Governance — Pre-Query Evaluation

Before DCM sends any data to a Mode 4 provider, the Policy Engine evaluates:

```
Query to Mode 4 provider proposed
  │
  ▼
Data classification check (BBQ-001)
  │  What classification levels are in the query payload fields?
  │  Is each field's classification ≤ provider's declared ceiling?
  │  → Any field exceeds ceiling: strip field or reject query
  │
  ▼
Sovereignty check (BBQ-003)
  │  Does the provider's operational_sovereignty.jurisdiction
  │  satisfy the requesting Tenant's sovereignty requirements?
  │  → Incompatible: block query, apply on_sovereign_mismatch behavior
  │
  ▼
Data minimization (BBQ-002)
  │  Strip all fields not in provider's data_request_spec
  │  Apply field-level filtering per cross_tenant_authorization if applicable
  │
  ▼
Authorized → send minimized query
Unauthorized → apply on_unavailable behavior (typically gatekeep)
```

#### 4.8.5 Assembly Process Integration

Mode 4 providers participate in any assembly phase — most usefully inside the placement loop where provider-specific data is available:

```yaml
policy:
  placement_phase: loop         # pre | loop | post | both
  evaluation_type: black_box_query
  black_box_provider_uuid: <uuid>

  # What to send — must be subset of provider's data_request_spec
  query_fields: [resource_type, placement.selected_provider_uuid, requester.tenant_uuid]

  # How to act on the decision component
  on_decision:
    pass: continue
    fail: <reject_candidate | gatekeep>
    score_below_threshold:
      threshold: 0.7
      action: reject_candidate   # try next provider candidate
    score_above_threshold:
      threshold: 0.9
      action: continue

  # How to act on the enrichment component
  on_enrichment:
    inject_fields: true          # inject returned fields into payload
    override_existing: false     # do not overwrite fields already set
    # Each injected field carries source_type: black_box_provider + audit_token
```

#### 4.8.6 Result Schema and Provenance

**Full result structure:**

```yaml
black_box_result:
  # Decision component (optional)
  decision:
    outcome: <pass | fail | score>
    score: 0.83
    confidence: <high | medium | low>
    citations:
      - "Provider certification ISO-27001 current as of 2026-01-15"
      - "No open security incidents in region eu-west-1a"
    expires_at: <ISO 8601>
    audit_token: "BB-2026-03-26-00847-A"  # provider's internal reference

  # Enrichment component (optional)
  enrichment:
    fields_to_inject:
      - field: risk_score
        value: 0.83
        provenance_note: "Returned by risk scoring engine v2.3"
      - field: risk_citations
        value: ["ISO-27001:A.12.1", "No active incidents"]
        provenance_note: "Risk scoring engine evidence"
      - field: recommended_mitigations
        value: ["Enable MFA", "Restrict egress to known endpoints"]
        provenance_note: "Risk scoring engine recommendations"
```

**Provenance on injected enrichment fields:**

Each field injected by a Mode 4 provider carries standard field-level provenance:

```yaml
risk_score:
  value: 0.83
  metadata:
    override: allow              # standard override control applies
    basis_for_value: "ML risk scoring engine evaluation"
  provenance:
    origin:
      source_type: black_box_provider
      source_uuid: <provider uuid>
      timestamp: <ISO 8601>
      audit_token: "BB-2026-03-26-00847-A"
      query_uuid: <uuid of this specific query-response cycle>
```

#### 4.8.7 Audit Record

Every Mode 4 query-response cycle produces a `black_box_evaluation_record` in the Audit Store regardless of outcome:

```yaml
black_box_evaluation_record:
  record_uuid: <uuid>
  policy_uuid: <uuid>
  request_uuid: <uuid>
  provider_uuid: <uuid>
  evaluated_at: <ISO 8601>
  placement_phase: loop

  query_sent:
    fields_included: [resource_type, placement.selected_provider_uuid]
    # Field NAMES only — not raw values. Values stored in provider's system.
    # Full correlation via audit_token.
    data_minimization_applied: true
    sovereignty_check: passed
    classification_ceiling_honored: true

  result_received:
    result_type: multi_factor
    decision:
      outcome: pass
      score: 0.83
      confidence: high
      expires_at: <ISO 8601>
      audit_token: "BB-2026-03-26-00847-A"
    enrichment:
      fields_injected: [risk_score, risk_citations, recommended_mitigations]
      override_existing_applied: false

  action_taken: continue_with_enrichment
  cached_result: false
  cache_stored: true
  cache_expires_at: <ISO 8601>
```

The `audit_token` is the **cross-system audit bridge** — DCM's record references the provider's internal record. Auditors can correlate DCM's audit trail with the black box provider's own logs for full end-to-end traceability.

#### 4.8.8 Failure and Fallback Behavior

| Condition | Default Behavior | Rationale |
|-----------|-----------------|-----------|
| `on_timeout` | `gatekeep` | Unknown is not safe |
| `on_error` | `gatekeep` | Malformed response is not safe |
| `on_unavailable` | `gatekeep` | External unavailability cannot bypass governance |
| `on_sovereign_mismatch` | `gatekeep` | Sovereignty cannot be bypassed |
| `on_classification_exceeded` | strip field or `gatekeep` | Data cannot be sent to unauthorized recipient |

All failure behaviors are configurable. `allow` is available for non-critical enrichment where the enrichment is additive and the request can proceed safely without it. Organizations must explicitly declare `allow` — it is never the default.

#### 4.8.9 System Policies

| Policy | Rule |
|--------|------|
| `BBQ-001` | Before sending any data to a Mode 4 provider, the Policy Engine must verify the provider is authorized to receive the data classification levels present in the query |
| `BBQ-002` | Data sent to a Mode 4 provider must be minimized to only the fields declared in the provider's `data_request_spec` |
| `BBQ-003` | A Mode 4 provider's `operational_sovereignty` must be compatible with the requesting Tenant's sovereignty requirements before any query is dispatched |
| `BBQ-004` | All Mode 4 query-response cycles must produce a `black_box_evaluation_record` in the Audit Store |
| `BBQ-005` | Mode 4 provider failure behavior (`on_timeout`, `on_error`, `on_unavailable`) must be explicitly declared — default is `gatekeep` |
| `BBQ-006` | Cached Mode 4 results must include the original query timestamp and validity period in provenance |
| `BBQ-007` | Fields injected into the payload by a Mode 4 provider enrichment must carry standard field-level provenance: `source_type: black_box_provider`, `source_uuid`, and `audit_token` |
| `BBQ-008` | The override control model applies to fields injected by Mode 4 enrichment — a GateKeeper policy may restrict or refuse black box enrichment on specific fields |
| `BBQ-009` | A Mode 4 provider that performs enrichment requires at minimum `transformation` trust level authority |

---

## 5. Lifecycle Time Constraints

### 5.1 Concept

Lifecycle time constraints declare **when a resource should cease to exist or trigger a lifecycle action**. They are a first-class field on any resource entity — not metadata, not a tag, but a governed field that follows the standard data model precedence and override control.

### 5.2 Constraint Types

| Type | Format | Description |
|------|--------|-------------|
| `ttl` | ISO 8601 duration (e.g., `P14D`) | Relative — expires N time after the reference point |
| `expires_at` | ISO 8601 timestamp | Absolute — expires at a specific calendar date/time |

When both are declared, the **earliest expiry wins** (LTC-004).

### 5.3 Data Model

```yaml
lifecycle_constraints:
  ttl:
    duration: P14D                       # ISO 8601 duration — 14 days
    reference_point: realization_timestamp  # created_at | realization_timestamp | last_modified
    on_expiry: <destroy | suspend | notify | review>
    metadata:
      override: allow                    # standard override control applies
      basis_for_value: "Consumer declared ephemeral — 14-day lab resource"

  expires_at:
    timestamp: "2026-06-30T23:59:59Z"
    on_expiry: notify
    metadata:
      override: immutable
      locked_by_policy_uuid: <uuid>
      basis_for_value: "Project deadline — resource must not persist beyond Q2"

  # Enforcement behavior
  enforcement:
    warn_before_expiry: P1D              # warn 1 day before expiry
    warn_notification_endpoint: <from owned_by artifact metadata>
    grace_period: PT1H                  # 1 hour grace after expiry before action
    on_grace_period_expiry: <execute | escalate>
```

### 5.4 Precedence

Lifecycle time constraints follow the standard data model precedence chain:

```
Base Layer default (lowest — e.g., "no TTL by default")
  ↓
Core Layer (e.g., "all dev environment resources: TTL 90 days")
  ↓
Service Layer (e.g., "ephemeral compute: TTL 7 days")
  ↓
Request Layer (consumer declared TTL)
  ↓
Transformation Policy (enrich TTL from business context)
  ↓
GateKeeper Policy (highest — may lock TTL as immutable)
```

A consumer can declare `ttl: P14D` in their request. A GateKeeper policy can override this to `P7D` and lock it immutable if organizational policy mandates shorter maximum lifetimes. A Core Layer can set default TTLs for resource classes. The provenance chain records every modification.

### 5.5 Expiry Enforcement

The **Lifecycle Constraint Enforcer** is a DCM control plane component that:
- Monitors all realized entities against their declared lifecycle constraints
- Fires the configured `on_expiry` action when a constraint is reached
- Records the enforcement action in provenance and the Audit Store
- Emits expiry warnings `warn_before_expiry` duration before the deadline

Expiry enforcement is a DCM concern — not a provider concern. The provider does not need to know about or implement TTL logic.

### 5.6 System Policies

| Policy | Rule |
|--------|------|
| `LTC-001` | Lifecycle time constraints follow standard data model precedence — layers, request, policies |
| `LTC-002` | GateKeeper policies may lock lifecycle constraints as `override: immutable` or `immutable_ceiling: absolute` |
| `LTC-003` | Expiry enforcement is a DCM control plane function — not a provider concern |
| `LTC-004` | When multiple time constraints exist on an entity, the earliest expiry wins |
| `LTC-005` | Expired entities that fail to execute their `on_expiry` action enter `PENDING_EXPIRY_ACTION` state and trigger an escalation |

---

## 6. Cross-Tenancy Authorization Model

### 6.1 Default Stance — Closed

Cross-tenant information sharing is **closed by default**. No cross-tenant relationship of any nature is permitted unless explicitly authorized. This applies to both operational dependencies and informational relationships.

The hard tenancy spectrum:

| Setting | Meaning |
|---------|---------|
| `deny_all` | No cross-tenant relationships of any nature |
| `explicit_only` | All cross-tenant must be explicitly authorized (DEFAULT) |
| `operational_permitted` | Operational cross-tenant permitted; informational requires explicit auth |
| `allow_all` | All cross-tenant permitted — requires justification; not available in sovereign profile |

The default shifts from the Q59 model's `operational_only` to `explicit_only`. Informational sharing is no longer implicitly open — every informational cross-tenant relationship requires an explicit authorization record.

### 6.2 Cross-Tenant Authorization Record

```yaml
cross_tenant_authorization:
  artifact_metadata:
    uuid: <uuid>
    handle: "tenant-a/auth/shared-network-read"
    version: "1.0.0"
    status: active
    owned_by:
      display_name: "Infrastructure Tenant Admin"

  # WHO
  authorized_consumer_tenant_uuid: <uuid — or null for any_authorized_tenant>
  authorized_actor_constraint:
    roles: [service_account, automation]    # null = any actor in the tenant
    specific_uuids: []                      # specific actor UUIDs if needed

  # WHAT
  resource_entity_uuid: <specific entity — or null for type-level>
  resource_type_uuid: <if type-level authorization>
  permitted_fields:
    - field: network_segment
    - field: vlan_id
    # empty list = all fields permitted
  permitted_relationship_natures: [informational, operational]

  # WHEN
  valid_from: <ISO 8601>
  expires_at: <ISO 8601 — null = indefinite>

  # WHERE
  permitted_in_regions: [eu-west, eu-central]   # null = any region
  sovereignty_constraints:
    must_honor_consuming_tenant_sovereignty: true
    must_honor_owning_tenant_sovereignty: true

  # GOVERNANCE
  authorized_by_policy_uuid: <uuid>
  authorization_level: <tenant_global | resource_specific | field_specific>
  # Hierarchy: field_specific > resource_specific > tenant_global
  # More specific = higher precedence
```

### 6.3 Authorization Hierarchy

More specific authorizations take precedence over broader ones:

```
field_specific     ← highest precedence — only these exact fields on this entity
  │
resource_specific  ← this entity — all permitted fields
  │
tenant_global      ← all entities in this Tenant — broadest
```

If a tenant-global policy says "allow informational sharing with Tenant B" but a resource-specific policy says "this resource is not shareable with anyone," the resource-specific policy wins.

### 6.4 System Policies — Cross-Tenancy

| Policy | Rule |
|--------|------|
| `XTA-001` | Cross-tenant information sharing is closed by default — explicit authorization required |
| `XTA-002` | Cross-tenant authorizations must specify who, what, when, and where |
| `XTA-003` | More specific authorizations take precedence: field_specific > resource_specific > tenant_global |
| `XTA-004` | All cross-tenant authorization decisions are policy-driven and DCM-enforced |
| `XTA-005` | Sovereignty constraints declared by either Tenant must be honored by all cross-tenant relationships |

---

## 7. Rehydration Tenancy Controls

### 7.1 Tenancy and Sovereignty Are Always Current

Tenancy controls, sovereignty directives, and cross-tenant authorizations are **always evaluated against current policies during rehydration**. They cannot be pinned to historical versions.

```yaml
rehydration:
  re_evaluate: true/false          # governs placement
  policy_version: current/pinned   # governs resource configuration policies
  # The following are ALWAYS current — cannot be pinned:
  tenancy_controls: always_current
  sovereignty_controls: always_current
  cross_tenant_authorizations: always_current
```

### 7.2 Rehydration Tenancy Conflict

When rehydration produces a tenancy or sovereignty constraint that conflicts with an existing cross-tenant allocation:

```yaml
rehydration_tenancy_conflict_record:
  rehydration_request_uuid: <uuid>
  entity_uuid: <uuid>
  conflict_type: cross_tenant_authorization_conflict
  original_authorization_uuid: <uuid>
  current_policy_violation:
    policy_uuid: <uuid>
    violation: "Consuming Tenant no longer has authorization for this allocation"
  action_taken: paused
  entity_state: PENDING_REVIEW
  notifications_sent:
    - entity_owner
    - owning_tenant_admin
    - consuming_tenant_admin
    - platform_admin
  resolution_options:
    - re_authorize
    - release
    - escalate
  policy_override_available: true
```

### 7.3 System Policies — Rehydration

| Policy | Rule |
|--------|------|
| `RHY-001` | Tenancy, sovereignty, and cross-tenant authorizations always use current policies during rehydration |
| `RHY-002` | Rehydration that conflicts with current tenancy/sovereignty pauses and enters PENDING_REVIEW |
| `RHY-003` | A paused rehydration allocation is not automatically released — requires explicit resolution |
| `RHY-004` | A policy may declare automatic resolution behavior for rehydration tenancy conflicts |

---

## 8. Open Questions

| # | Question | Impact | Status |
|---|----------|--------|--------|
| 1 | Should organizations be able to submit custom profiles and groups back to the DCM project registry? | Community | ✅ Resolved — community submissions via PR-based workflow; Tier 2; documented use case + deployment reference + test results + named maintainer (PROF-005) |
| 2 | Should there be a certified profile program — profiles that have been validated against specific regulatory frameworks? | Compliance | ✅ Resolved — certified profile program with third-party certification metadata; certified profiles promoted to Tier 1; applies to artifact not deployment (PROF-006) |
| 3 | Should Policy Provider trust elevation require a formal approval workflow in DCM UI or is out-of-band approval sufficient? | Security | ✅ Resolved — formal approval workflow; profile-governed approvers (1 standard → 3 sovereign); P7D shadow period; POLICY_PROVIDER_ELEVATED audit (PROF-007) |
| 4 | Should the default TTL for dev profile resources be configurable at the platform level or only at the group level? | Configuration | ✅ Resolved — overridable at platform domain layer; per-resource-type TTL overrides; on_expiry action configurable (PROF-008) |
| 5 | How does Policy Provider delivery interact with air-gapped deployments — pull from internal mirror? | Sovereignty | ✅ Resolved — signed bundle model identical to registry; Mode 4 in sovereign restricted to within-boundary endpoints (PROF-009) |

---

## 9. Related Concepts

- **Policy Engine** — executes the policies organized by groups and profiles
- **Policy Layers** — the assembly process step where policies execute
- **Artifact Metadata** — universal metadata on all policy artifacts
- **Five Artifact Statuses** — developing → proposed → active → deprecated → retired
- **Shadow Execution** — proposed policies and profiles run in shadow mode for validation
- **Override Control** — policies set override control on fields; immutable_ceiling: absolute for non-negotiables
- **Ingestion Model** — policy profile requirements may gate brownfield promotion
- **Four States** — rehydration tenancy controls govern how historical states are replayed


## 8. Policy Profile Gap Resolutions

### 8.1 Community Profile and Group Submissions (Q1)

Organizations may submit custom profiles and policy groups to the DCM community registry following the same PR-based proposal workflow as Resource Types. Community contributions live in Tier 2 (Verified Community).

```yaml
community_profile_submission:
  profile:
    handle: "community/profile/hipaa-openstack"
    extends: system/profile/hipaa-prod
    description: "HIPAA production profile for OpenStack deployments"
    policy_groups:
      - system/group/compliance-hipaa
      - community/group/openstack-security-baseline
    contributed_by: "Healthcare IT Community Group"
    tested_with: [OpenStack 2024.1, DCM 1.0]
  required_for_submission:
    - documented_use_case
    - at_least_one_real_deployment_reference
    - test_results_against_reference_implementation
    - named_maintainer
```

Community profiles carry the same lifecycle as Resource Types — shadow validation before active, deprecation policies, sunset periods. Organizations adopt them directly or extend them further.

### 8.2 Certified Profile Program (Q2)

DCM supports a certified profile program where profiles carry formal third-party certification metadata against compliance frameworks. Certified profiles are promoted to Tier 1 (DCM Core).

```yaml
profile_certification:
  certifications:
    - framework: HIPAA
      certifying_body: "Coalfire Systems"
      certification_date: "2025-11-01"
      expires_at: "2027-11-01"
      certification_scope: "PHI data lifecycle management via DCM"
      certificate_ref:
        credential_provider_uuid: <uuid>
        path: "dcm/registry/certifications/hipaa-prod-2025"
```

**Important:** Profile certification applies to the profile artifact only — it does not certify the deploying organization's compliance posture. A certified profile is evidence that the profile implements the required controls; it is not a compliance certification of any specific deployment.

### 8.3 Policy Provider Trust Elevation Approval (Q3)

Policy Provider trust elevation (increasing the mode level) requires a formal approval workflow. Approval requirements are profile-governed.

```yaml
policy_provider_trust_elevation:
  elevation_request:
    from_mode: 1
    to_mode: 3
    justification: "Need OPA Rego for complex placement constraints"

  approval_requirements:
    standard:
      approvers: [platform_admin]
      min_approvers: 1
    prod:
      approvers: [platform_admin, security_owner]
      min_approvers: 2
    fsi:
      approvers: [platform_admin, security_owner, compliance_officer]
      min_approvers: 2
      verified_required: true
    sovereign:
      approvers: [platform_admin, security_owner, compliance_officer]
      min_approvers: 3
      requires_change_control_ticket: true

  shadow_period_after_elevation: P7D    # elevated mode runs in shadow before active
  audit_record: POLICY_PROVIDER_ELEVATED
```

The P7D shadow period catches unintended consequences before elevated outputs become binding on production requests.

### 8.4 Dev Profile Resource TTL Configurability (Q4)

The default TTL for dev profile resources is declared in the system domain layer and overridable at the platform domain level.

```yaml
layer:
  handle: "platform/dev-profile/resource-ttl-override"
  domain: platform
  fields:
    dev_profile_resource_ttl:
      default_ttl: P30D               # platform override: 30d instead of system default P7D
      max_ttl: P90D                   # consumers cannot declare TTL > 90 days in dev
      on_expiry: notify               # notify (consumers can extend) vs destroy
      per_resource_type_overrides:
        Compute.VirtualMachine: P7D
        Storage.Block: P14D
        DNS.Record: P3D
```

### 8.5 Air-Gapped Policy Provider Delivery (Q5)

Policy Provider delivery in air-gapped deployments uses signed bundles — same model as the registry bundle system.

```yaml
policy_provider_airgap:
  delivery_mode: signed_bundle
  bundle_contents:
    - provider_registration_yaml
    - policy_artifacts_zip
    - mode_specific_package:
        mode_3: opa_rego_bundle       # OPA Rego files + data
        mode_4: endpoint_config       # endpoint declaration (must be within boundary)
  signing_key_ref: <org-signing-key>
  expires_at: <ISO 8601>
```

**Mode 4 sovereign constraint:** In sovereign profiles, Mode 4 Policy Providers may only call endpoints within the sovereignty boundary. External AI service calls are blocked by the BBQ-001 sovereignty check before any Mode 4 query.

### 8.6 System Policies — Policy Profile Gaps

| Policy | Rule |
|--------|------|
| `PROF-005` | Organizations may submit custom profiles and policy groups to the DCM community registry via the same PR-based proposal workflow as Resource Types. Community contributions live in Tier 2. Submissions require documented use case, at least one production deployment reference, test results, and a named maintainer. |
| `PROF-006` | DCM supports a certified profile program where profiles carry formal third-party certification metadata. Certified profiles are promoted to Tier 1. Profile certification applies to the artifact only — it does not certify the deploying organization's compliance posture. |
| `PROF-007` | Policy Provider trust elevation requires a formal approval workflow (standard: 1 platform admin; prod: platform admin + security owner; fsi/sovereign: dual approval + compliance officer). Elevated providers run in shadow mode for P7D before activation. All elevations produce a POLICY_PROVIDER_ELEVATED audit record. |
| `PROF-008` | The default TTL for dev profile resources is declared in the system domain layer and overridable at the platform domain level. Per-resource-type TTL overrides are supported. The on_expiry action is configurable. |
| `PROF-009` | Policy Provider delivery in air-gapped deployments uses signed bundles identical to the registry bundle model. Mode 4 providers in sovereign profiles may only call endpoints within the sovereignty boundary. |



---

## 9. Recovery Posture Policy Groups

### 9.1 recovery_posture as a Concern Type

`recovery_posture` is a Policy Group concern_type that governs how DCM responds to provisioning failures, timeouts, and ambiguous states. It is the fifth concern type alongside security, compliance, operational, and implementation posture.

Recovery posture groups contain Recovery Policies — a formal DCM policy type that maps trigger conditions (DISPATCH_TIMEOUT, PARTIAL_REALIZATION, etc.) to response actions (DRIFT_RECONCILE, DISCARD_AND_REQUEUE, NOTIFY_AND_WAIT, etc.).

See [Operational Models](24-operational-models.md) Section 5 for the complete Recovery Policy model, trigger vocabulary, and action vocabulary.

### 9.2 Four Built-in Recovery Posture Groups

| Group Handle | Posture | Appropriate For |
|-------------|---------|----------------|
| `system/group/recovery-automated-reconciliation` | Let drift detection converge on correct state | Dev, standard environments |
| `system/group/recovery-discard-and-requeue` | Clean up and restart on any ambiguity | Consistency-critical environments |
| `system/group/recovery-notify-and-wait` | Always notify human; never act automatically | FSI, sovereign, regulated environments |
| `system/group/recovery-aggressive-retry` | Retry everything before giving up | High-transient-failure environments |

### 9.3 Profile Binding Defaults

| Profile | Default Recovery Posture |
|---------|------------------------|
| `minimal` | recovery-automated-reconciliation |
| `dev` | recovery-automated-reconciliation |
| `standard` | recovery-automated-reconciliation |
| `prod` | recovery-notify-and-wait |
| `fsi` | recovery-notify-and-wait |
| `sovereign` | recovery-notify-and-wait |

### 9.4 Override Hierarchy

Organizations override recovery posture at Tenant or resource-type level without changing the deployment profile:

```yaml
# Tenant override — all resources in this Tenant use discard-and-requeue
tenant_config:
  recovery_profile_override: recovery-discard-and-requeue

# Resource-type override — VMs get aggressive retry regardless of Tenant/profile
resource_type_recovery_override:
  resource_type: Compute.VirtualMachine
  recovery_profile: recovery-aggressive-retry
```

Resource-type override wins over Tenant override wins over profile default.



---

## 10. Zero Trust Posture Policy Groups

### 10.1 zero_trust_posture as a Concern Type

`zero_trust_posture` is the sixth Policy Group concern type. It governs authentication requirements, credential lifetime, revocation check frequency, and hardware attestation requirements for all DCM interactions.

See [Accreditation and Authorization Matrix](26-accreditation-and-authorization-matrix.md) Section 5 for the complete zero trust model.

### 10.2 Four Zero Trust Posture Levels

| Posture | Boundary | Internal | Hardware | Profile Default |
|---------|---------|----------|----------|----------------|
| `none` | Perimeter model | Trusted | Not required | minimal |
| `boundary` | Zero trust at external boundaries | Service mesh | Not required | dev, standard |
| `full` | Zero trust everywhere | Per-call auth | Not required | prod, fsi |
| `hardware_attested` | Zero trust everywhere | Per-call auth | Required (TPM/HSM) | sovereign |

### 10.3 Credential Lifetime Defaults

| Profile | Max credential lifetime |
|---------|------------------------|
| minimal | PT8H |
| dev | PT4H |
| standard | PT1H |
| prod | PT30M |
| fsi | PT15M |
| sovereign | PT15M + hardware attestation |

### 10.4 Hard Data Boundary Constraints

The sovereign profile enforces a hard constraint via the Data/Capability Authorization Matrix: **data classified as `sovereign` or `classified` never crosses any interaction boundary**. This constraint is declared with `hard_constraint: true` in the federation boundary matrix and cannot be overridden by any policy, profile, or operator action. It is enforced at the matrix level, not the policy level.


---

*Document maintained by the DCM Project. For questions or contributions see [GitHub](https://github.com/dcm-project).*
