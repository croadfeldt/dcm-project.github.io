---
title: "DCM Taxonomy"
type: docs
weight: 5
---

> **Purpose:** This document defines the authoritative vocabulary for all DCM architecture, documentation, and implementation work. It ensures precision and clarity by giving every term a distinct, contextual definition and identifying ambiguous terms to avoid.
>
> When contributing to DCM — code, documentation, Jira tickets, design discussions — use these terms consistently. Vocabulary proposals are submitted via PR following standard registry governance.

---

## Part 1 — Core Vocabulary

### Foundational Architecture Terms

**Artifact**
Any versioned, GitOps-managed object in DCM — layers, policies, resource type specifications, provider registrations, group definitions, entity declarations. Every artifact carries universal artifact metadata (uuid, handle, version, status, owned_by). Artifacts are immutable once published; changes produce a new version.

**Assembly Process**
The nine-step process by which DCM transforms a consumer's Intent State into a provider-ready Requested State. Steps: Intent Capture → Layer Resolution → Layer Merge → Request Layer Application → Pre-Placement Policies → Placement Engine Loop → Post-Placement Policies → Requested State Storage → Provider Dispatch. The assembly process is the core operational function of the DCM Control Plane.

**Control Plane**
The central nervous system of DCM. Maintains the Unified API and Data Model, enforces multi-tenancy, executes the assembly process, manages artifact lifecycle, and coordinates Service Providers. Does not directly manage physical infrastructure — manages the data that represents and governs infrastructure.

**DCM (Data Center Management)**
A framework designed to provide a "hyperscaler-like cloud experience" for on-premises infrastructure. Centralizes and automates the management, observation, and lifecycle of IT/IS services within an enterprise data center. Technology-agnostic — defines roles, responsibilities, interactions, and expected capabilities rather than prescribing specific tools.

**DCM Instance**
A running deployment of the DCM Control Plane and its associated stores. Manages a defined set of resources, providers, and tenants. Multiple DCM instances may be federated. See: Hub DCM, Regional DCM, Sovereign DCM.

**Deployment Posture**
How a DCM instance's infrastructure behaves — redundancy, enforcement strictness, audit retention, tenancy model, cross-tenant defaults. Expressed as a Deployment Posture Group (posture-minimal through posture-sovereign). One of the two dimensions of a Profile.

**Domain (Policy and Layer)**
The organizational and architectural home of a Policy or Layer. Determines authority scope and override precedence. Ordered highest to lowest: system > platform > tenant > service > provider > request. Lower-domain artifacts cannot override higher-domain artifacts.

**Drift**
The difference between what DCM believes exists (Realized State) and what actually exists (Discovered State). May be authorized (change made through DCM) or unsanctioned (change made outside DCM). The Drift Detection component continuously compares these states and triggers remediation per policy.

**Entity**
A specific, realized instance of a resource type — a particular VM, a specific VLAN, a named DNS record. Entities have UUIDs preserved across their entire lifecycle including provider migrations. Entities pass through Intent, Requested, Realized, and Discovered states.

**Four States**
The four representations of a resource in DCM: **Intent State** (consumer's original declaration, stored in Git), **Requested State** (fully assembled, policy-processed payload, stored in Git), **Realized State** (what the provider actually provisioned, stored in Event Stream), **Discovered State** (what active interrogation finds currently exists, stored in Discovered Store).

**Handle**
The human-readable, stable identifier for an artifact within DCM. Complements the UUID (machine-meaningful). Format: `{domain}/{concern-or-type}/{name}`. Stable across versions — the handle does not change when a new version is published.

**Intent State**
The consumer's original resource declaration as submitted, stored verbatim in the Intent Store (GitOps) before any assembly processing. Used as the source for rehydration.

**Layer**
A declarative, immutable, versioned unit of data that contributes field values to an assembled request payload. Layers are passive — they declare values but do not execute logic. Layers answer "what values should these fields have?" See also: Policy.

**Layer Chain**
The ordered set of layers applied during the assembly process for a specific request. Immutable once assembled. The layer chain is the deduplication key in the deduplicated provenance model.

**Lifecycle Constraint Enforcer**
The DCM control plane component that enforces time-based constraints — TTLs, valid_from/valid_until on memberships, max_execution_time on Process Resources.

**Placement Engine**
The DCM control plane component that selects the Service Provider for a request based on constraints, capacity, sovereignty, and policy. Operates within a reserve-query loop during Step 6 of the assembly process. Uses a deterministic seven-step tie-breaking hierarchy.

**Policy**
An executable rule that evaluates the assembled payload and takes action. Policies answer "given this data, is it valid? what should change? should this proceed?" Three types: GateKeeper (approve or reject), Validation (verify correctness), Transformation (modify or enrich). *Policies are logic; Layers are data — they serve different purposes and must not be confused.*

**Profile**
A named composition of a Deployment Posture Group and one or more Compliance Domain Groups. Defines the full governance posture for a DCM deployment. DCM ships six core profiles (minimal through sovereign) and eight extended profiles (hipaa-prod, fedramp-moderate, dod-il4, etc.).

**Provenance**
The full audit trail of where a field value came from and what changed it. Recorded per-field in the assembled payload. Three configurable models: full_inline (all provenance on entity record), deduplicated (content-addressed, layer chain as dedup key), tiered archive (hot/warm/cold tiers).

**Rehydration**
Replaying an entity's Intent State through the assembly process — potentially to a different provider, in a different context. The entity's UUID is always preserved. Provider-side identifiers change and are recorded in rehydration_history.

**Requested State**
The fully assembled, policy-processed payload stored in the Requested Store (GitOps). Authoritative record of what was actually requested and how assembly enriched it. Includes: assembled payload, assembly provenance, placement decisions, and dependency resolution.

**Realized State**
The actual provisioned state of a resource as reported by the Service Provider. Stored in the Realized Store (Event Stream). Includes provider-side identifiers and actual provisioned field values.

**Resource Type Specification**
The formal definition of a resource type — its fields, constraints, dependencies, lifecycle rules, editable fields, and allowed service providers. Versioned artifacts stored in the Resource Type Registry. The contract between consumers and the assembly process.

**Sovereignty Zone**
A declared geographic, legal, or organizational boundary within which data must remain. Enforced at the placement engine level. Cannot be overridden by consumer requests. Mandatory check before DCM-to-DCM tunnel establishment.

**Tenant**
The primary ownership and authorization boundary for resources in DCM. All resources are owned by exactly one Tenant. Provides multi-tenancy isolation. See also: tenant_boundary (group class).

**Unified Data Model**
The standardized data format used throughout DCM for all resource declarations, provider payloads, and state records. Service Providers implement Naturalization (DCM → native) and Denaturalization (native → DCM) for translation.

---

### Provider Types

**Service Provider**
A DCM component that realizes resources — provisions, configures, and manages physical or virtual infrastructure on behalf of DCM consumers. Responsibilities: naturalization, realization, denaturalization, capacity reporting (reserve_query), and sovereignty declaration maintenance. *This is the DCM taxonomy term for what general software architecture calls a "producer."*

**Information Provider**
A DCM component that supplies authoritative external data to enrich entity records. Examples: CMDB, IPAM, HR system, asset management. DCM computes confidence scores for all values they supply. *Not to be confused with Service Providers — Information Providers supply data; they do not provision infrastructure.*

**Meta Provider**
A Service Provider that composes multiple sub-providers to deliver a higher-order service. Declares composition_visibility: opaque, transparent, or selective.

**Policy Provider**
A DCM component that supplies external policy logic. Four modes: Mode 1 (read-only query), Mode 2 (stateless evaluation), Mode 3 (execute external code), Mode 4 (black-box query with sovereignty checks). Trust elevation requires formal approval workflow.

**Storage Provider**
A DCM component that persists DCM state. Sub-types: GitOps Store, Event Stream Store, Search Index, Audit Store, Validation Store, Discovered Store.

**Message Bus Provider**
A DCM component bridging internal and external event streams. Used for curated observability events, webhook delivery, and federation message passing.

**Credential Provider**
A DCM component that resolves secrets from external stores. Credentials never stored in Git or audit records.

**Auth Provider**
A DCM component that authenticates identities and resolves permissions. Supports OIDC, LDAP/AD, FreeIPA, GitHub/GitLab OAuth, mTLS, static API key, local users.

**DCM Provider**
A DCM component that wraps another DCM instance's API for cross-DCM resource sharing. Always mTLS. Sovereignty checks mandatory. Local DCM policies govern all resources from DCM Provider tunnels.

---

### Federation Topology

**Hub DCM**
The central/global DCM instance. Authoritative registry origin, governance authority, and federation routing hub. Applies placement engine logic to route requests to Regional or Sovereign DCMs. *Replaces "Shore" (defense IT terminology).*

**Regional DCM**
A distributed regional DCM instance managing resources within its region. Caches layers and catalog items from Hub DCM. Treated as a DCM Provider instance by the Hub DCM's placement engine. *Replaces "Ship" (defense IT terminology).*

**Sovereign DCM**
An air-gapped or compliance-isolated DCM instance. No live external connectivity. Updates via signed bundles during connectivity windows. Required for classified, sovereign, or highly regulated deployments. *Replaces "Enclave" (defense IT terminology).*

**Federation Depth**
Number of hops from deepest DCM instance to Hub DCM. Profile-governed maximum: 5 (minimal/dev), 3 (standard/prod), 2 (fsi/sovereign).

**Federation Trust Score**
0-100 score on a DCM-to-DCM tunnel. Computed from: identity verification, sovereignty compatibility, certifications currency, audit integrity, uptime, compliance. Used in: cross_dcm_confidence = source_confidence × (tunnel_trust_score / 100).

---

### Data Model Terms

**Compliance Domain Group**
A Policy Group governing which regulatory frameworks apply to DCM-managed resources. One of the two dimensions of a Profile. 16 built-in groups: FSI, PCI-DSS, HIPAA, FedRAMP Moderate, FedRAMP High, DoD IL2-IL6, Government, GDPR, ISO 27001, NIST 800-53, SOC2, NERC-CIP, Sovereign.

**Confidence Descriptor**
The primary data model for Information Provider field value confidence. Four stored fields: authority_level, corroboration, source_trust, last_updated_at. Confidence score (0-100) and band (very_high through very_low) are derived at query time — never stored as primary data.

**Core Layers**
Data layers applicable across any resource type — organizational, infrastructure, and contextual data not specific to any one service.

**Denaturalization**
Converting provider-native result data back into the DCM Unified Data Model. Inverse of Naturalization.

**Naturalization**
Converting a DCM Unified Data Model payload into provider-native format. Inverse of Denaturalization.

**native_passthrough**
A sanctioned field for provider-specific data genuinely untranslatable to the Unified Data Model. Always audit-logged. Opaque mode blocked in fsi/sovereign profiles.

**Policy Group**
A cohesive collection of related policies addressing a single concern. Managed as DCMGroup with group_class: policy_collection.

**Service Layer**
A data layer contributed by a Service Provider containing service-specific configuration defaults. Independently versioned from its Service Provider.

---

### Operational Terms

**Cost Analysis Information Provider**
The specialized Information Provider that supplies cost estimation, placement cost signals, cost actuals, and budget alerts to DCM. DCM does not perform cost calculations — it provides input data and consumes signals from this provider. Integrates with external cost management platforms (e.g., Red Hat Cost Management). Falls back to static declared costs from provider registration when unavailable.

**Orchestrator**
The DCM control plane component that sequences and executes ordered workflows. Conducts the request lifecycle pipeline and executes named workflow artifacts. Relies heavily on policies (workflow steps invoke Policy Engine) and data (workflow steps read/write entity state). Workflows are first-class DCM artifacts included in Profiles.

**Workflow (DCM)**
A versioned, GitOps-managed DCM artifact defining a named sequence of operations. Can be triggered manually, on a schedule, by events, or by policy output. Included in Profiles to automatically activate functionality when the profile is applied. The request lifecycle pipeline is itself a system-domain built-in workflow.

**Brownfield**
Existing infrastructure provisioned outside of DCM, brought under management via the Ingestion Model.

**DCM Group (DCMGroup)**
The universal grouping construct. All grouping uses DCMGroup with a declared group_class. Eight classes: tenant_boundary, resource_grouping, policy_collection, policy_profile, layer_grouping, provider_grouping, composite, federation.

**Discovered State**
Result of active infrastructure interrogation. Ephemeral operational data in the Discovered Store. Used by Drift Detection to compare against Realized State. NOT the source of truth. Never stored in the Audit Store.

**Editable Field**
A field on a realized entity modifiable via targeted delta update without reprovisioning. Independent of override_preference (which governs assembly time).

**Fulfillment**
The complete process from consumer submission through Service Provider realization. A resource is Fulfilled when its Realized State matches its Requested State.

**Implementation Posture**
A Policy Group concern_type for implementation complexity vs capability trade-offs. Governs provenance model selection, auth simplicity, deployment complexity.

**Ingestion Model**
The three-step process (INGEST → ENRICH → PROMOTE) for bringing brownfield resources under DCM management.

**Rehydration Lease**
An exclusive time-bounded lock per entity during rehydration. Prevents concurrent rehydrations. Priority ordering: security/compliance emergency > manual admin > automated sovereignty migration > provider decommission > manual consumer.

**Reserve Query**
Placement engine mechanism asking candidate Service Providers "can you fulfill this resource request right now?" Providers respond with capacity availability and sovereignty compatibility.

**Shadow Mode**
The operational state of a proposed Policy or Policy Provider. Evaluates real requests; captures outputs in Validation Store; does not apply outputs to requests.

**Step-Up MFA**
Additional MFA challenge at sensitive operations within an already-authenticated session. Protects against session hijacking for high-stakes operations.

**Targeted Delta**
Update mechanism for editable fields. Applies only changed fields to Realized State. Does not re-run the layer assembly chain.

**Validation Store**
Storage Provider sub-type for shadow evaluation records. Separate from Audit Store — queryable, modifiable, P90D default retention.

---

## Part 2 — Anti-Vocabulary

Terms to avoid and what to use instead.

| Avoid | Reason | Use Instead |
|-------|--------|-------------|
| **Data Center** | A building — architecturally irrelevant | **Region**, **Zone**, **Availability Zone** |
| **Realize / Realization** | Means too many things | **Provision** (a VM), **Install** (software), **Fulfill** (a request) |
| **Tangible / Intangible** | Weasel words — no architectural meaning | Specific terms: physical resource, virtual resource, logical construct |
| **Widgets** | Vague — what things exactly? | The specific resource type: VirtualMachine, VLAN, DNSRecord |
| **Producer** | Generic term not in DCM vocabulary | **Service Provider** — carries the full DCM contract model |
| **Shore / Ship / Enclave** | Defense IT terminology — not universally understood | **Hub DCM**, **Regional DCM**, **Sovereign DCM** |
| **User** (generic) | Means different things at different layers | **Developer** / **Application Owner** (Application domain); **Platform Engineer** / **SRE** (platform) |
| **"catalog item"** used to mean "resource type specification" | These are distinct: resource type specification = vendor-neutral contract in registry; catalog item = provider's specific offering implementing that contract | **Provider Catalog Item** or **Resource Type Specification** — be specific |
| **"resource type"** used to mean a specific provider offering | Resource type is the classification; the offering is the catalog item | **Provider Catalog Item** |
| **Service** (unqualified) | Overloaded — means different things at each layer | **Catalog Item** (Application), **Resource Type** (Control Plane), **Service Provider** (provider) |
| **Config / Configuration** | Could mean Layer, Resource Type Spec, Policy, or settings | Specify: **Layer**, **Resource Type Specification**, **Policy**, **Platform configuration** |
| **Manage** | Means everything and nothing | **Provision**, **configure**, **monitor**, **decommission**, **migrate**, **govern** |
| **Enrich** (unqualified) | Could mean layer assembly, policy transformation, or information push | **Layer assembly**, **Policy transformation**, **Information Provider enrichment** |

---

## Part 3 — Roles and Personas

| Role | Domain | Meaning |
|------|--------|---------|
| **Developer / Application Owner** | Application | Human consumer of cloud services via DCM |
| **Platform Engineer** | Control Plane | Operates and maintains the DCM platform |
| **Infrastructure Operations** | Data Center / Resource | Manages physical infrastructure and service providers |
| **Policy Owner** | Governance | Authors, reviews, and activates DCM policies |
| **Risk and Compliance Manager** | Governance | Reviews audit records, compliance reports, and policy effectiveness |
| **Data Protection Officer** | Governance | Responsible for GDPR, HIPAA, and data protection compliance |
| **Platform Admin** | Platform | Highest-privilege DCM operator |
| **SRE** | Platform | Manages DCM operational health and incident response |
| **Tenant Admin** | Tenant | Manages resources and users within a Tenant boundary |
| **Service Provider Team** | Provider | Builds and maintains Service Provider integrations |

---

## Part 4 — Capability Domain Prefixes

Capability IDs used in the DCM Capabilities Matrix for Jira and implementation tracking.

| Prefix | Domain |
|--------|--------|
| IAM | Identity and Access Management |
| CAT | Service Catalog |
| REQ | Request Lifecycle Management |
| PRV | Provider Contract and Realization |
| LCM | Resource Lifecycle Management |
| DRF | Drift Detection and Remediation |
| POL | Policy Management |
| LAY | Data Layer Management |
| INF | Information and Data Integration |
| ING | Ingestion and Brownfield Management |
| AUD | Audit and Compliance |
| OBS | Observability and Operations |
| STO | Storage and State Management |
| FED | DCM Federation and Multi-Instance |
| GOV | Platform Governance and Administration |

---

*Document maintained by the DCM Project. Vocabulary proposals submitted via PR. For questions or contributions see [GitHub](https://github.com/dcm-project).*
