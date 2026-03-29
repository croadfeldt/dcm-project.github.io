# DCM Taxonomy

The DCM taxonomy defines the precise vocabulary used throughout the architecture. Every term used in the data model, specifications, and implementation should conform to these definitions.

**Purpose:** Eliminate ambiguity. When two people use the same word to mean different things, architecture breaks down. This taxonomy prevents that.

---

## Part 1 — Core Vocabulary

### The Three Foundational Abstractions

| Term | Definition |
|------|-----------|
| **Data** | Any structured artifact in DCM with a type, UUID, lifecycle state, fields, data classification, and provenance. Everything that exists, is stored, and has a lifecycle. Entities, layers, policies, accreditations, audit records, groups, relationships — all Data. |
| **Provider** | Any external component DCM calls or that calls DCM. Implements the unified Provider base contract (registration, health, sovereignty, accreditation, governance matrix enforcement, zero trust). What varies between provider types is the capability extension. |
| **Policy** | A rule artifact that fires when Data matches declared conditions, produces a typed output (decision, mutation, action, or directive), and is enforced at a declared level. Policies govern every transition, transformation, and constraint in DCM. |

### Provider Types (11)

| Term | Definition |
|------|-----------|
| **Service Provider** | Typed Provider. Capability: realize infrastructure resources. Implements naturalization, realization, denaturalization, and discovery. |
| **Information Provider** | Typed Provider. Capability: serve authoritative external data (CMDB, HR, Finance, identity). |
| **Storage Provider** | Typed Provider. Capability: persist DCM state. Sub-types: GitOps, write-once snapshot, event stream, search index, audit. |
| **Meta Provider** | Typed Provider. Capability: compose multiple child providers into a compound service delivered as a single catalog item. |
| **Policy Provider** | Typed Provider. Capability: evaluate policies externally. Modes 1–4; Mode 3–4 for OPA/Rego sidecar and black-box query enrichment. |
| **Credential Provider** | Typed Provider. Capability: issue, rotate, and revoke secrets and credentials. |
| **Auth Provider** | Typed Provider. Capability: authenticate actor identities and resolve role/group memberships. |
| **Notification Provider** | Typed Provider. Capability: deliver notification envelopes to configured channels (Slack, PagerDuty, email, webhook). |
| **Message Bus Provider** | Typed Provider. Capability: async event streaming between DCM and external systems. |
| **Registry Provider** | Typed Provider. Capability: serve the Resource Type Registry (core, community, organization tiers). |
| **Peer DCM** | Typed Provider. Another DCM instance participating in federation. Federation is the Provider abstraction applied across DCM instances. |

### Policy Types (7)

| Term | Definition |
|------|-----------|
| **GateKeeper Policy** | Typed Policy. Declares `enforcement_class: compliance` (boolean deny — halts request) or `operational` (contributes `risk_score_contribution` to request risk score). Compliance-class is the default and fail-safe. See [Scoring Model](data-model/scoring-model/). |
| **Validation Policy** | Typed Policy. Declares `output_class: structural` (boolean pass/fail — halts on fail) or `advisory` (contributes completeness score + warning list without blocking). Structural is the default and fail-safe. See [Scoring Model](data-model/scoring-model/). |
| **Transformation Policy** | Typed Policy. Output: mutations[] — field additions, changes, locks. Fires on request payload. All mutations collected and applied with provenance. |
| **Recovery Policy** | Typed Policy. Output: action + parameters. Fires on failure/timeout trigger conditions. Governs what DCM does when things go wrong. |
| **Orchestration Flow Policy** | Typed Policy. Output: ordered step sequence. Fires on pipeline payload type events. Named workflow artifacts — the explicit, visible pipeline skeleton. |
| **Governance Matrix Rule** | Typed Policy. Output: ALLOW / DENY / ALLOW_WITH_CONDITIONS / STRIP_FIELD / REDACT / AUDIT_ONLY. Fires at every cross-boundary interaction. The single enforcement point for all data/capability boundary decisions. |
| **Lifecycle Policy** | Typed Policy. Output: action on related entity (cascade, protect, detach, notify). Fires on relationship events. |

### Data Model Terms

| Term | Definition |
|------|-----------|
| **Entity** | A Resource Entity, Process Entity, or Composite Entity — the primary managed thing in DCM. Has a UUID that is stable across all four lifecycle states. |
| **Four States** | Intent (consumer declaration), Requested (assembled/policy-validated), Realized (provider-confirmed), Discovered (independently observed). Same entity at four lifecycle stages in four specialized stores. |
| **Data Layer** | A versioned data artifact that contributes fields to request payload assembly. Types: Base, Core, Intermediate, Service, Request. Each has a declared contributor type. |
| **Resource Type Specification** | The schema definition for a resource type. Declares fields, constraints, portability class, dependency graph, and field criticality. |
| **Provider Catalog Item** | A provider-specific instantiation of a Resource Type Specification. What consumers actually request from the service catalog. |
| **Artifact Metadata** | Standard metadata block on every DCM artifact: uuid, handle, version, status, owned_by, created_by, contributed_by. |
| **Provenance** | Field-level lineage metadata embedded in every payload field, recording origin and all modifications. |
| **Data Classification** | Field-level metadata: public / internal / confidential / restricted / phi / pci / sovereign / classified. Phi, sovereign, and classified are immutable once set. |
| **Sovereignty Zone** | A registered DCM artifact declaring a geopolitical/regulatory boundary. Rules reference zones by ID, not raw country codes. |
| **Accreditation** | A formal, versioned, time-bounded attestation that a DCM component satisfies a specific compliance framework. First-class Data artifact with its own lifecycle. |
| **DCMGroup** | Universal grouping artifact with typed group_class: tenant_boundary, resource_grouping, policy_collection, policy_profile, composite, federation. |
| **Drift Record** | A Data artifact produced by the Drift Reconciliation Component recording field-by-field comparison of Realized vs Discovered state with severity classification. |
| **Governance Matrix Rule** | A Data artifact (also a Policy type) — a rule artifact governing cross-boundary interactions using four-axis match conditions. |

### Operational Terms

| Term | Definition |
|------|-----------|
| **Request Orchestrator** | The event bus. Routes lifecycle events to the Policy Engine. Contains no pipeline logic — Policies define all behavior. |
| **Policy Engine** | Evaluates all policy types using the same algorithm. The single policy evaluator — no component bypasses it. |
| **Placement Engine** | Six-step provider selection: sovereignty filter → accreditation filter → capability filter → parallel reserve queries → tie-breaking (policy/priority/affinity/cost/load/hash) → confirm. |
| **Drift Reconciliation** | Control plane component. Compares Discovered State vs Realized State. Produces drift records and events. Never writes to the Realized Store. |
| **Shadow Mode** | A Policy in `proposed` status evaluates against real traffic; output is captured but never applied. The primary mechanism for safe policy change management. |
| **Naturalization** | Service Provider converts a DCM unified payload to provider-native format before execution. |
| **Denaturalization** | Service Provider converts provider-native result back to DCM unified format after execution. |
| **Rehydration** | Replaying a resource's intent state to a new provider or context. Produces a new Requested State from the existing Intent State. |
| **Contributor** | An actor type that authored a Data artifact. Recorded in artifact_metadata.contributed_by. Types: platform_admin, consumer, service_provider, peer_dcm. Determines review requirements. |
| **Two-Level Orchestration** | Level 1: Named Workflow Artifacts (Orchestration Flow Policy, ordered: true) — explicit sequence skeleton. Level 2: Dynamic Policies (GateKeeper, Transformation, Recovery) — fire conditionally on same events without being declared in the workflow. |
| **Reserve Query** | A parallel capacity query sent to all eligible provider candidates. Providers confirm capacity and hold it for PT5M. The Placement Engine selects the winner and releases other holds. |



### Meta Provider Composability Terms

| Term | Definition |
|------|-----------|
| **Composite Entity** | A DCM entity produced by a Meta Provider. Exists across all four states as a single entity aggregating constituent Resource Entities. Has one entity UUID that links it through all states. |
| **Constituent** | A sub-resource within a compound service that a Meta Provider provisions. Declared with a `component_id`, `resource_type`, `depends_on`, and `required_for_delivery` classification. |
| **required_for_delivery** | Constituent delivery classification: `required` (failure halts the compound service and triggers compensation), `partial` (failure produces DEGRADED but not FAILED), `optional` (failure is noted but ignored). |
| **Composite Status** | Top-level outcome of a compound service execution: `REALIZED` (all required constituents succeeded), `DEGRADED` (required succeeded; partial(s) failed; accepted if profile permits), `FAILED` (required constituent(s) failed; triggers compensation). |
| **Compensation** | Ordered teardown of successfully realized constituents when a compound service cannot be delivered. Runs in dependency-reverse order. Best-effort; failures produce `PARTIALLY_COMPENSATED` with orphan detection. |
| **Composition Visibility** | How a Meta Provider exposes its internal structure to DCM: `opaque` (top-level only), `transparent` (all constituents as DCM entities), `selective` (declared sub-set as DCM entities). |
| **Dependency Round** | A batch of constituents that can execute in parallel because all their `depends_on` constituents are complete. Multiple rounds execute sequentially; constituents within a round execute in parallel. |
| **MPX-001–MPX-008** | Meta Provider system policies. Key: MPX-001 (compensation required if partial delivery supported), MPX-002 (dependency-reverse decommission), MPX-006 (DEGRADED is a valid terminal state when accepted), MPX-008 (compound payload fully assembled by DCM before dispatch). |


### Scoring Model Terms

| Term | Definition |
|------|-----------|
| **enforcement_class** | Required property of GateKeeper policies. `compliance`: boolean deny gate — always halts on fire. `operational`: contributes `risk_score_contribution` to the request risk score. |
| **output_class** | Required property of Validation policies. `structural`: boolean pass/fail. `advisory`: contributes completeness score and warnings without blocking. |
| **request_risk_score** | Aggregate score (0–100) assembled from five weighted signals: operational GateKeeper contributions, completeness, actor risk history, quota pressure, provider accreditation richness. Drives approval routing. |
| **risk_score_contribution** | The weighted score a fired operational-class GateKeeper contributes to the request risk score. Declared as `scoring_weight` (1–100) in the policy. |
| **completeness_score** | Aggregate of advisory Validation contributions. Represents how incomplete or unusual the request is — higher = more warnings. Does not block requests. |
| **actor_risk_history_score** | Decay-weighted (λ=0.1, half-life ≈7 days) history of an actor's previous request outcomes. Contributes to request risk score. Not exposed to other consumers. |
| **quota_pressure_score** | Continuous score representing how close a Tenant is to quota limits for the requested resource type. Zero below 75% utilization; 100 at full quota. |
| **accreditation_richness_score** | Weighted sum of a provider's accreditation portfolio normalized to 0–100. Influences placement preference and inversely contributes to provider risk signal. |
| **scoring_threshold** | Profile-governed boundary on the request risk score that maps to an approval routing tier. Four tiers: auto_approve, human_review, dual_approval, committee. `auto_approve_below` may not exceed 50 (SMX-008). |
| **Risk Score Aggregator** | Sub-function of the Policy Engine. Assembles five scoring signals into the request risk score after all compliance-class and Governance Matrix evaluations complete. |
| **regulatory_mandate** | Policy metadata flag. When `true`, the policy's `enforcement_class: compliance` cannot be demoted to operational by any profile (SMX-003). Set by platform admins, audited. |
| **score_drivers** | Human-readable list of the top contributing factors to a request risk score. Exposed to consumers (top 3 only). Full breakdown in Score Record for platform admins. |
| **Score Record** | Immutable audit artifact recording the full signal breakdown, weights, routing decision, and threshold applied for a scored request evaluation. Written to Audit Store for every scored request. |


### Federation Topology

| Term | Definition |
|------|-----------|
| **Peer DCM** | A federated DCM instance. Treated as a typed Provider. Trust postures: verified (manually approved), vouched (Hub-introduced), provisional (crypto-verified only). |
| **Hub DCM** | A DCM instance that coordinates Regional DCMs in hub-spoke topology. Policy distribution source. Cannot force-activate policies on Regional DCMs. |
| **Regional DCM** | A DCM instance in a specific sovereignty region, managed by a Hub DCM. |
| **Federation Tunnel** | Mutually authenticated, encrypted, scoped channel between DCM instances. Establishes secure transport — not implicit trust. |
| **Federated Contribution** | A Peer DCM contributing registry entries, policy templates, or service layers to a receiving DCM, scoped by the peer's federation trust posture. |

---

## Part 2 — Anti-Vocabulary

Terms to avoid because they introduce ambiguity. Use the precise alternatives instead.

| Avoid | Because | Use Instead |
|-------|---------|-------------|
| **Widget** | Vague — what thing, exactly? | Name the specific resource type (VirtualMachine, IPAddress, VLAN, etc.) |
| **Realize** (standalone) | Ambiguous — "realize" can mean understand, achieve, or provision | **Provision** a VM, **fulfill** a request, **execute** a process. "Realized State" is accepted vocabulary. |
| **Data Center** (as architectural term) | A building — not architecturally meaningful | **Region** (large geographically distinct area) or **Zone** / **Availability Zone** (isolated group within a Region) |
| **Orchestrator** (as a standalone component) | Suggests a single sequencer; DCM orchestration is policy-driven, not procedural | **Request Orchestrator** (the event bus) + **Orchestration Flow Policy** (named workflow) + **Policy Engine** (evaluator) |
| **Tangible / Intangible** | Nothing in DCM architecture is intangible — these words add no precision | Describe what the thing actually is |
| **Workflow** (without qualification) | Ambiguous between Level 1 (named Orchestration Flow Policy) and general process | **Named Workflow** (Orchestration Flow Policy with `ordered: true`) or **dynamic policy** (conditional policy) |

---

## Part 3 — Roles and Personas

| Role | Scope | API surface |
|------|-------|-------------|
| **Consumer** | Requests services from the catalog; manages owned resources | Consumer API |
| **Tenant Admin** | Manages a Tenant; can author tenant-domain policies and groups | Consumer API + contribution endpoints |
| **Policy Author** | Authors policies within assigned domain scope | Consumer API contribution endpoints, Flow GUI |
| **Platform Admin** | Manages the DCM deployment; all artifact types; all domains | Admin API, Flow GUI (full) |
| **Platform Observer** | Read-only view across all platform operations | Flow GUI (read-only), Admin API (read) |
| **Service Provider Operator** | Manages a registered Service Provider | Operator Interface (provider side), Admin API (registration) |
| **Policy Reviewer** | Reviews and approves/rejects contributed policies | Admin API, Flow GUI |
| **Auditor** | Read-only access to audit records and compliance reports | Consumer API (audit), Admin API (audit) |

---

## Part 4 — Capability Domain Prefixes

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
| ACC | Accreditation Management |
| ZTS | Zero Trust and Security Posture |
| GMX | Unified Governance Matrix |
| DRC | Drift Reconciliation |
| FCM | Federated Contribution Model |
| SMX | Scoring Model |
| MPX | Meta Provider Composability |

---

*Document maintained by the DCM Project. For questions or contributions see [GitHub](https://github.com/dcm-project).*
