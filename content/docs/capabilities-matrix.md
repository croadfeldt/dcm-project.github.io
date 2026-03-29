# DCM — Foundational Capabilities Matrix

> **Purpose:** This document defines the core operational capabilities required for DCM to perform lifecycle management as defined by the data model. Each capability maps to a consumer/service provider perspective and will be used to drive implementation work in Jira.
>
> **How to read this document:**
> - **Capability Domain** — the architectural area the capability belongs to
> - **Capability** — a discrete operational function; the smallest unit of independently implementable behavior
> - **Consumer perspective** — what the end user / application team experiences
> - **Service Provider perspective** — what the Service Provider or platform component must implement
> - **Platform/Admin perspective** — what the platform engineer or SRE must configure or operate
> - **Depends on** — other capabilities that must exist first

---

## 1. Identity and Access Management

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| IAM-001 | Actor Authentication | Authenticate to DCM via configured IdP | — | Register and configure Auth Providers; manage local user store | — |
| IAM-002 | Session Token Management | Receive and use session tokens; token refresh | — | Configure session TTL, failover chain | IAM-001 |
| IAM-003 | Role-Based Access Control | Receive role-appropriate service catalog and API responses | — | Declare role mappings; assign roles to actors | IAM-001 |
| IAM-004 | Group Membership Resolution | Group memberships automatically applied from IdP | — | Map IdP groups to DCM groups; declare group-role relationships | IAM-001, IAM-003 |
| IAM-005 | Multi-Factor Authentication | Satisfy per-session and step-up MFA challenges | — | Configure MFA methods; declare step-up operations | IAM-001 |
| IAM-006 | SCIM Automated Provisioning | Actor created/updated/deprovisioned from IdP automatically | — | Configure SCIM endpoint and attribute mappings | IAM-001 |
| IAM-007 | Tenant Scope Enforcement | Access restricted to authorized Tenants | — | Declare Tenant membership; configure cross-tenant policies | IAM-003, IAM-004 |

---

## 2. Service Catalog

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| CAT-001 | Service Catalog Presentation | Browse available services filtered by RBAC | Declare catalog items for offered resource types | Activate catalog items; configure catalog visibility policies | IAM-003, IAM-007 |
| CAT-002 | Service Schema Discovery | View field schemas, constraints, and edit constraints for a catalog item | Declare field schemas in Resource Type Spec | Configure constraint visibility level per profile | CAT-001 |
| CAT-003 | Catalog Item Search and Filter | Search catalog by keyword, resource type, tag | — | Configure Search Index for catalog | CAT-001 |
| CAT-004 | Catalog Item Versioning | Request a specific version of a catalog item | Publish new catalog item versions following semver | Manage version lifecycle; enforce deprecation timelines | CAT-001 |
| CAT-005 | Cost Estimation | Receive estimated cost before submitting a request | Declare cost metadata on provider registration | Configure Cost Analysis component | CAT-001 |
| CAT-006 | Dependency Visualization | See required dependencies for a catalog item before requesting | Declare dependency graph in Resource Type Spec | — | CAT-001 |
| CAT-007 | Catalog Item Deprecation | Receive deprecation warnings on deprecated catalog items | Declare successor types in deprecation notice | Manage deprecation lifecycle; notify consumers | CAT-004 |

---

## 3. Request Lifecycle Management

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| REQ-001 | Submit Service Request | Submit a resource request via UI, API, or Git PR | — | Configure request ingress surfaces | IAM-007, CAT-001 |
| REQ-002 | Intent State Capture | Request stored as versioned GitOps artifact before processing | — | Configure Intent Store; manage Git repository structure | REQ-001 |
| REQ-003 | Layer Assembly | Request enriched with organizational defaults and context layers | Contribute Service Layers for resource types | Manage Core Layers; configure Layer Cache | REQ-002 |
| REQ-004 | Policy Evaluation | Request validated, transformed, and gated by applicable policies | Contribute provider-specific policies | Manage Policy Engine; configure Policy Groups and Profiles | REQ-003 |
| REQ-005 | Placement Engine Execution | Resource placed with the best available provider instance | Implement capacity reserve_query response | Configure placement constraints; manage provider priorities | REQ-004 |
| REQ-006 | Requested State Persistence | Assembled payload stored as authoritative GitOps record | — | Configure Requested Store; manage storage redundancy | REQ-005 |
| REQ-007 | Provider Dispatch | Request payload delivered to selected provider | Implement Services API to receive DCM payloads | Configure API Gateway and egress | REQ-006 |
| REQ-008 | Request Status Tracking | Monitor request status from submitted through realized | Report realization status back to DCM | Configure observability for request tracking | REQ-007 |
| REQ-009 | Request Cancellation | Cancel a pending request before realization | Handle cancellation payloads | Configure cancellation policies | REQ-002 |
| REQ-010 | Git PR Request Ingress | Submit requests via Git Pull Request with policy dry-run feedback | — | Configure Git Request Watcher; manage repository structure | REQ-001, IAM-001 |

---

## 4. Provider Contract and Realization

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| PRV-001 | Provider Registration | — | Register provider with DCM: declare type, capabilities, sovereignty, cost metadata | Configure Provider Registry; validate sovereignty declarations | IAM-001 |
| PRV-002 | Naturalization | — | Convert DCM unified payload to provider-native format | — | PRV-001, REQ-007 |
| PRV-003 | Realization | — | Execute required actions to provision/configure/change resource | — | PRV-002 |
| PRV-004 | Denaturalization | — | Convert provider-native result back to DCM unified format | — | PRV-003 |
| PRV-005 | Realized State Reporting | — | Report realized payload and status to DCM API Gateway | Configure Realized State Store; manage Event Stream | PRV-004 |
| PRV-006 | Capacity Reporting | — | Respond to reserve_query with current capacity and availability | Configure placement engine; manage capacity confidence | PRV-001 |
| PRV-007 | Provider Health Reporting | — | Expose health check endpoint; report availability | Monitor provider health; configure trust score updates | PRV-001 |
| PRV-008 | Sovereignty Declaration Maintenance | — | Notify DCM when sovereignty data changes within declared SLA | Monitor sovereignty changes; trigger re-evaluation | PRV-001 |
| PRV-009 | Meta Provider Orchestration | — | Compose sub-providers to deliver higher-order services; manage composition visibility | Configure composite provider federation eligibility | PRV-001, PRV-003 |

---

## 5. Resource Lifecycle Management

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| LCM-001 | Resource State Transitions | Trigger lifecycle actions: suspend, resume, decommission | Handle state transition payloads | Configure lifecycle policies; manage state machine | REQ-008 |
| LCM-002 | Post-Realization Field Updates | Update editable fields on realized resources (targeted delta) | Handle delta update payloads; apply partial changes | Configure editable field declarations; manage edit policies | PRV-005 |
| LCM-003 | Resource TTL Management | Declare and extend resource TTLs; receive expiry notifications | Handle TTL-triggered decommission payloads | Configure Lifecycle Constraint Enforcer; manage expiry policies | LCM-001 |
| LCM-004 | Ownership Transfer | Transfer resource ownership to a different Tenant | — | Authorize and execute ownership transfers; record transfer history | IAM-007, LCM-001 |
| LCM-005 | Rehydration | Replay a resource's intent state to a new provider or context | Receive and execute rehydration payloads | Manage rehydration leases; configure auth level requirements | REQ-002, PRV-003 |
| LCM-006 | Billing State Management | — | — | Configure billing state policies; integrate with Cost Analysis | LCM-001 |
| LCM-007 | Resource Decommission | Decommission resources individually or as part of group decommission | Handle decommission payloads; release resources | Manage decommission workflows; coordinate dependency teardown | LCM-001 |

---

## 6. Drift Detection and Remediation

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| DRF-001 | Active Discovery | — | Expose discovery endpoint; respond to interrogation queries | Configure discovery schedules; manage Discovered Store | PRV-005 |
| DRF-002 | Drift Comparison | Receive drift notifications for owned resources | — | Configure drift detection policies; manage comparison logic | DRF-001, PRV-005 |
| DRF-003 | Drift Notification | Receive actionable drift alerts with field-level detail | — | Configure drift notification channels and escalation policies | DRF-002 |
| DRF-004 | Drift Remediation | Approve or reject automatic drift remediation | Execute remediation payloads | Configure remediation policies (revert/update/alert/escalate) | DRF-002, LCM-002 |
| DRF-005 | Unsanctioned Change Detection | Receive alerts on unauthorized resource modifications | Report all external state changes to DCM | Configure unsanctioned change policies | DRF-001 |

---

## 7. Policy Management

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| POL-001 | Policy Authoring | — | Contribute provider-specific policy rules | Author and manage policies in GitOps store | IAM-003 |
| POL-002 | Policy Validation and Shadow Mode | View shadow evaluation results on own requests | — | Configure shadow mode; review shadow results in Validation Store | POL-001 |
| POL-003 | Policy Activation and Review | — | — | Manage policy review periods; authorize policy activation | POL-001, POL-002 |
| POL-004 | Policy Group Management | — | — | Compose Policy Groups; manage profile assignments | POL-003 |
| POL-005 | Profile Management | — | — | Configure deployment profiles; manage compliance domain groups | POL-004 |
| POL-006 | Policy Provider Registration | — | Register Policy Providers; maintain provider in declared mode | Configure Policy Provider trust levels; manage trust elevation workflow | PRV-001, POL-001 |
| POL-007 | Policy Override and Constraint Visibility | View constraint details for service catalog fields | Declare constraint schemas on Resource Type Specs | Configure constraint visibility levels per profile | CAT-002, POL-003 |

---

## 8. Data Layer Management

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| LAY-001 | Core Layer Authoring | — | — | Author and manage Core and Organizational Layers in GitOps | IAM-003 |
| LAY-002 | Service Layer Contribution | — | Contribute Service Layers for offered resource types | Manage layer compatibility declarations | PRV-001, LAY-001 |
| LAY-003 | Layer Cache Management | — | — | Manage Layer Cache synchronization; handle cache invalidation | LAY-001, LAY-002 |
| LAY-004 | Layer Exclusion | Declare layer exclusions on specific requests | — | Configure which layers may be excluded; manage non-excludable declarations | REQ-003 |
| LAY-005 | Layer Versioning and Lifecycle | — | — | Manage layer versions; handle deprecation; enforce immutability | LAY-001 |

---

## 9. Information and Data Integration

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| INF-001 | Information Provider Registration | — | Register Information Provider; declare authority scope and schema | Configure Information Provider Registry; manage authority layers | IAM-001 |
| INF-002 | Information Provider Push | — | Push field value updates to DCM; respond to conflict notifications | Configure ingestion pipeline; manage conflict resolution policies | INF-001 |
| INF-003 | Information Provider Pull / Discovery | — | Expose data query endpoint for DCM pull operations | Configure pull schedules; manage cache TTLs | INF-001 |
| INF-004 | Write-Back | — | Implement write-back endpoint to receive DCM-initiated updates | Configure write-back triggers via policy | INF-001, INF-002 |
| INF-005 | Confidence Score Visibility | View confidence bands on entity field values; query confidence aggregation API | — | Configure confidence scoring formula; manage trust score thresholds | INF-001 |
| INF-006 | Conflict Resolution Management | — | — | Review and resolve contested field values; manage conflict escalation | INF-002 |

---

## 10. Ingestion and Brownfield Management

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| ING-001 | Resource Discovery and Ingestion | — | Expose discovery endpoints for brownfield resources | Configure ingestion pipeline; manage __transitional__ Tenant | DRF-001 |
| ING-002 | Ingested Entity Review | — | — | Review ingested entities; resolve conflicts; promote to active Tenants | ING-001 |
| ING-003 | Bulk Promotion | — | — | Execute bulk entity promotions with preview and rollback | ING-002 |
| ING-004 | Catalog Item Association | — | — | Associate ingested entities with Resource Type Specs; create catalog items | ING-002, CAT-001 |

---

## 11. Audit and Compliance

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| AUD-001 | Audit Trail Access | Query audit records for own resources | — | Configure Audit Store; manage retention policies | IAM-003 |
| AUD-002 | Compliance Reporting | — | — | Generate compliance reports; manage report schedules | AUD-001 |
| AUD-003 | Hash Chain Verification | — | — | Run scheduled and on-demand hash chain verification; manage integrity incidents | AUD-001 |
| AUD-004 | Cross-DCM Audit Correlation | — | — | Correlate audit records across DCM instances via correlation_id; authorize cross-DCM pulls | AUD-001, DCM-001 |
| AUD-005 | Audit Record Retention Management | — | — | Configure reference-based retention; manage post-lifecycle retention | AUD-001 |

---

## 12. Observability and Operations

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| OBS-001 | Operational Dashboard | View health and status of own resources | — | Configure and manage observability dashboard | — |
| OBS-002 | Metrics and Telemetry Export | — | Expose resource-level metrics to DCM | Configure observability export; integrate enterprise observability platform | — |
| OBS-003 | Curated Event Stream Subscription | Subscribe to observability event types via Message Bus | — | Configure event stream publication policies; manage subscriber roles | OBS-002 |
| OBS-004 | Alert and Notification Management | Receive resource and policy alerts via declared channels | — | Configure alert routing; manage notification channels and escalation | OBS-001 |
| OBS-005 | Cost Analysis and Attribution | View cost estimates and actuals for owned resources | Provide cost metadata; report utilization | Configure Cost Analysis component; manage cost attribution policies | PRV-006 |

---

## 13. Storage and State Management

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| STO-001 | GitOps Store Management | — | — | Configure and manage Intent and Requested Stores; manage Git repository structure | — |
| STO-002 | Realized State Store Management | — | — | Configure Event Stream and Realized Store; manage retention | PRV-005 |
| STO-003 | Discovered State Store Management | — | — | Configure Discovered Store; manage retention policies per profile | DRF-001 |
| STO-004 | Search Index Management | Use entity and catalog search | — | Configure Search Index; manage rebuild on failure | STO-001 |
| STO-005 | Backup and Recovery | — | — | Configure backup schedules; test recovery procedures | STO-001, STO-002 |
| STO-006 | Provenance Model Configuration | — | — | Select and configure provenance model (full_inline / deduplicated / tiered); manage tier transitions | STO-001 |

---

## 14. DCM Federation and Multi-Instance

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| FED-001 | DCM Provider Registration | Submit requests that are routed to peer DCMs | Register as DCM Provider in peer instances | Configure DCM Provider registrations; manage federation trust | PRV-001, IAM-001 |
| FED-002 | Federation Routing | Requests automatically routed to appropriate Regional/Sovereign DCM | Respond to reserve queries from Hub DCM | Configure federation placement policies; manage sovereignty pre-filters | FED-001, REQ-005 |
| FED-003 | Federation Trust Management | — | — | Manage mTLS certificates; monitor federation trust scores; handle cert rotation | FED-001 |
| FED-004 | Cross-DCM Drift Detection | Receive drift alerts for federated resources | Publish Discovered State events to federation Message Bus | Configure federated drift detection; manage alert-and-hold policies | FED-001, DRF-002 |
| FED-005 | DCM Export and Import | — | — | Export and import DCM state packages; verify import trust scores | STO-001, STO-002 |

---

## 15. Platform Governance and Administration

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| GOV-001 | Tenant Management | — | — | Create, configure, and decommission Tenants; manage compliance overlays | IAM-007 |
| GOV-002 | Group Management | — | — | Create and manage DCM Groups; configure sovereignty rules; manage time-bounded memberships | IAM-003 |
| GOV-003 | Registry Management | — | Register and maintain Resource Type Specifications in organization registry | Manage registry sync; configure registry policies; manage Tier 3 types | PRV-001 |
| GOV-004 | Resource Type Lifecycle | — | Manage deprecation notices; declare successor types; maintain migration guidance | Enforce deprecation timelines; manage sunset periods | GOV-003 |
| GOV-005 | Platform Configuration Management | — | — | Manage platform-wide layers; configure profiles; manage deployment manifest | LAY-001, POL-005 |
| GOV-006 | Bootstrap and Self-Hosting | — | — | Manage DCM self-deployment; verify bootstrap manifest; handle repave scenarios | STO-001 |
| GOV-007 | Sovereign Deployment Management | — | — | Manage air-gapped DCM instances; configure signed bundle import; manage offline registry | FED-001, STO-001 |

---

## 16. Accreditation Management

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| ACC-001 | Accreditation Submission | — | Submit accreditation records (BAA, ISO 27001, FedRAMP, etc.) referencing external certificate evidence | Register accrediting bodies; configure minimum accreditation types per profile | PRV-001 |
| ACC-002 | Accreditation Review and Approval | — | Receive approval/rejection notification | Review submitted accreditations; verify certificate references; approve or reject via Admin API | ACC-001 |
| ACC-003 | Accreditation Lifecycle Monitoring | Receive notification when a provider's accreditation is nearing expiry or revoked | Renew accreditations before expiry; submit renewal documentation | Monitor expiry timelines; fire P90D renewal warnings; handle accreditation gaps | ACC-001 |
| ACC-004 | Accreditation Gap Response | Receive notification when a provider enters accreditation gap affecting owned resources | — | Configure Recovery Policy for accreditation gap events; manage affected entity remediation | ACC-003, POL-005 |
| ACC-005 | Data Classification Enforcement | Receive enforcement feedback when request payload contains data the selected provider cannot handle | Declare max_data_classification_accepted in capability registration | Configure classification immutability rules; manage phi/sovereign classification locks | ACC-001, PRV-001 |
| ACC-006 | DCM Deployment Accreditation | — | — | Register DCM deployment-level accreditations; expose to federation peers for trust verification | PRV-001, FED-001 |

---

## 17. Zero Trust and Security Posture

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| ZTS-001 | Mutual TLS Enforcement | All interactions authenticated via mTLS at the client side | Present valid mTLS certificate on every interaction; rotate certificates on declared schedule | Configure trust anchors; manage CA chain; enforce mTLS at all interaction boundaries | IAM-001 |
| ZTS-002 | Scoped Interaction Credentials | Receive scoped short-lived credentials for authorized operations | Validate credential scope before executing operations; reject out-of-scope credentials | Configure credential lifetime per profile; manage credential issuance via Credential Provider | IAM-001, PRV-001 |
| ZTS-003 | Certificate Rotation Management | — | Implement certificate rotation before expiry; use transition window to avoid downtime | Monitor certificate expiry; fire P14D rotation warnings; manage P7D transition window | ZTS-001 |
| ZTS-004 | Zero Trust Posture Configuration | — | — | Configure zero_trust_posture per profile (none/boundary/full/hardware_attested); manage posture overrides | POL-005 |
| ZTS-005 | Hardware Attestation (Sovereign Profile) | — | Present hardware-attested identity (TPM/HSM) for sovereign profile interactions | Configure hardware attestation requirements; manage HSM integration; enforce for sovereign profile | ZTS-001, ZTS-002 |
| ZTS-006 | Five-Check Boundary Enforcement | — | Pass all five boundary checks on every interaction: identity → authorization → accreditation → matrix → sovereignty | Monitor boundary check audit records; respond to INTERACTION_DENIED events | ZTS-001, ACC-001, GMX-001 |

---

## 18. Unified Governance Matrix

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| GMX-001 | Governance Matrix Rule Authoring | — | — | Author governance matrix rules in GitOps; declare match conditions across four axes (subject/data/target/context); declare field permissions | POL-001 |
| GMX-002 | Boundary Enforcement Evaluation | Receive DENY response with governing rule_uuid and human-readable reason when a request crosses a prohibited boundary | Receive field-stripped or redacted payloads when STRIP_FIELD/REDACT decisions apply | Monitor GMX evaluation audit records; respond to DENY events | GMX-001, ZTS-006 |
| GMX-003 | Field-Level Data Control | Receive request feedback when specific payload fields are stripped or redacted by active matrix rules | Receive filtered payloads; handle missing optional fields gracefully | Configure allowlist/blocklist field permissions per rule; manage STRIP_FIELD vs REDACT vs DENY_REQUEST escalation | GMX-001 |
| GMX-004 | Sovereignty Zone Management | — | Declare operating sovereignty zones in provider registration | Register sovereignty zones; declare jurisdictions, regulatory frameworks, inter-zone agreements | PRV-001, GMX-001 |
| GMX-005 | Compliance Domain Matrix Activation | — | — | Activate compliance domain matrix rules (HIPAA, GDPR, etc.) by enabling compliance domain in profile; rules apply automatically | POL-005, GMX-001 |
| GMX-006 | Tenant and Resource-Type Matrix Overrides | — | — | Declare Tenant-level and resource-type-level matrix rules that tighten (never relax) platform defaults | GMX-001, GOV-001 |
| GMX-007 | Matrix Rule Lifecycle Management | — | — | Manage governance matrix rule lifecycle (developing → proposed → active); use shadow mode for safe validation before activation | GMX-001, POL-002 |

---

## 19. Drift Reconciliation

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| DRC-001 | Drift Record Production | Receive drift records with field-level detail: realized value, discovered value, field criticality, severity, unsanctioned flag | — | Configure Drift Reconciliation Component; manage comparison algorithm and severity thresholds | DRF-001, PRV-005 |
| DRC-002 | Unsanctioned Change Classification | Receive elevated-severity alert when change has no corresponding Requested State record | — | Configure unsanctioned change detection; manage severity escalation rules | DRC-001 |
| DRC-003 | Drift Severity Classification | Receive severity-classified drift records (minor/significant/critical) based on field criticality × change magnitude | — | Declare field criticality in Resource Type Specifications; configure magnitude thresholds per profile | DRC-001, GOV-003 |
| DRC-004 | Drift Resolution Tracking | View drift record status (open/acknowledged/resolved/escalated); receive resolved notification when next discovery confirms clean state | — | Monitor drift resolution rates; configure escalation policies for aged-open drift records | DRC-001, DRF-004 |
| DRC-005 | Governance Matrix Drift Integration | — | — | Configure governance matrix check in drift comparison pipeline: expected provider changes are not flagged as drift | DRC-001, GMX-001 |


## 20. Federated Contribution Model

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| FCM-001 | Consumer Policy Authoring | Author and submit tenant-domain policies (GateKeeper, Transformation, Recovery, Lifecycle, Orchestration Flow, Governance Matrix rules) via API or Flow GUI; receive PR URL and shadow mode results | — | Configure consumer policy authoring permissions (policy_author role); manage review requirements per profile | POL-001, IAM-003, IAM-007 |
| FCM-002 | Provider Resource Type Publication | — | Publish Resource Type Specifications and Catalog Items for offered resource types via provider contribution API; receive registry PR for platform admin review | Manage provider contribution registry; configure review requirements for provider specs; manage Organization-tier registry | PRV-001, GOV-003 |
| FCM-003 | Provider Service Layer Contribution | — | Contribute Service Layers for offered resource types; layers applied during request assembly for all consumers requesting that resource type | Review and activate provider-contributed layers; manage layer compatibility | PRV-001, LAY-002 |
| FCM-004 | Consumer Resource Group and Definition Contribution | Author and manage resource groups, notification subscriptions, webhook registrations, and cross-tenant authorization records within own Tenant | — | Configure contribution permissions per role; manage Tenant-scoped artifact lifecycle | IAM-007, GOV-002 |
| FCM-005 | Federation Contribution (Peer DCM) | — | Peer DCM contributes registry entries, policy templates, and service layers via federation channels | Manage federation contribution trust posture (verified/vouched/provisional); configure review requirements per trust posture; manage cross-DCM artifact lifecycle | FED-001, GOV-003, POL-003 |
| FCM-006 | Contribution Review and Lifecycle | View contribution status (proposed, pending_review, active, withdrawn); withdraw a pending contribution; receive notification when contribution is approved or rejected | Receive notification when provider contributions are reviewed | Review and approve/reject contributions via Admin API; manage shadow review periods; assign new owners to orphaned artifacts | POL-002, POL-003 |
| FCM-007 | Contributor Scope Enforcement | Receive clear DENY response when attempting to contribute outside permitted domain scope | Receive DENY when contributing specs for resource types not offered | Monitor Governance Matrix enforcement at contribution time; configure scope violation audit and notification | GMX-001, GMX-002 |

---


## 21. Scoring Model

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| SMX-001 | Operational GateKeeper Scoring | Receive risk score and score_drivers with request acknowledgment; understand why score is at its level | Declare `enforcement_class: operational` and `scoring_weight` on contributed GateKeeper policies | Configure operational GateKeeper policies with appropriate weights; manage per-policy enforcement class | POL-001, REQ-004 |
| SMX-002 | Advisory Validation and Completeness Score | Receive advisory_warnings list with request acknowledgment; understand what optional improvements exist | Declare `output_class: advisory` on advisory Validation policies | Configure advisory Validation policies; manage completeness score thresholds | POL-001, REQ-004 |
| SMX-003 | Actor Risk History Tracking | View own risk history score and contributing events via Consumer API | — | Monitor actor risk history; reset scores for trusted automation accounts; configure decay parameters | AUD-001, IAM-001 |
| SMX-004 | Quota Pressure Scoring | Receive quota_pressure as a score driver when approaching Tenant quota limits | — | Configure per-resource-type quota limits; manage free_threshold parameter | IAM-007, REQ-004 |
| SMX-005 | Provider Accreditation Richness Scoring | — | Benefit from lower risk contribution by maintaining rich accreditation portfolio | Configure accreditation richness weights; manage portfolio scoring | ACC-001, PRV-001 |
| SMX-006 | Profile Scoring Threshold Management | — | — | Configure approval routing thresholds per profile (auto/reviewed/verified/authorized + custom tiers via named-tier list); manage signal weights; enforce SMX-008 (max auto_approve_below: 50) | POL-005, REQ-004 |
| SMX-007 | Policy Enforcement Class Override | — | Contribute policies with declared enforcement_class; receive notification when profile overrides enforcement class | Declare per-profile enforcement class overrides; manage regulatory_mandate flag to protect compliance-class policies from demotion | POL-004, POL-005 |
| SMX-008 | Score Audit Trail | Query risk score and routing decision for own requests; view score_drivers and advisory_warnings | — | Query full Score Record detail including signal breakdown and actor risk history; manage score audit retention | AUD-001, REQ-004 |

---


## 22. Meta Provider Composability

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| MPX-001 | Compound Service Request | Request a compound service as a single catalog item; receive composite entity UUID; track compound execution status via standard request status endpoint | Register as Meta Provider with constituent specification; implement compound dispatch endpoint | Configure Meta Provider registration; manage composite service catalog items | CAT-001, REQ-007, PRV-001 |
| MPX-002 | Dependency-Ordered Constituent Execution | — | Execute constituents in declared dependency order; manage parallel rounds; respect depends_on declarations | Configure composition model; monitor execution round progress via status events | MPX-001, PRV-003 |
| MPX-003 | Partial Delivery and DEGRADED State | Receive DEGRADED composite entity when partial delivery is accepted; choose to accept or reject degraded state | Declare partial_delivery_supported and required_for_delivery per constituent; return DEGRADED compound payload | Configure accept_degraded_delivery per profile; manage degraded notification urgency | MPX-001, PRV-005 |
| MPX-004 | Compound Compensation | Receive notification and recovery decision when compound service fails; approve or reject compensation | Implement compensation in dependency-reverse order; guarantee idempotent decommission calls | Configure compensation timeout; manage PARTIALLY_COMPENSATED orphan detection | MPX-001, LCM-007, DRC-001 |
| MPX-005 | Transparent Constituent Visibility | Query and manage DCM-visible constituent entities independently (when transparency mode); receive constituent-level drift alerts | Declare composition_visibility mode; register transparent constituents with deterministic UUIDs | Configure visibility mode per compound resource type; manage constituent entity lifecycle policies | MPX-001, DRF-001 |
| MPX-006 | Compound Execution Status Tracking | Monitor compound execution round progress via request status; see component-level status during long-running compositions | Send intermediate status events to DCM during execution; declare status_reporting.interval | Monitor compound execution health; configure execution timeout alerts | MPX-001, REQ-008 |
| MPX-007 | Nested Meta Provider Composition | Request high-order compound services composed of other compound services (max depth 3) | Implement as a Meta Provider that calls other Meta Providers as constituents; declare max_nesting_depth | Configure nesting depth limits; manage nested compensation chains | MPX-001, PRV-009 |

---


## 23. Credential Provider Model

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| CPX-001 | Resource Credential Issuance | Receive credential metadata and retrieval URL with realized resource; retrieve credential value via authenticated endpoint | Declare credential requirements in Resource Type Spec; receive credential issuance confirmation | Register Credential Provider; configure credential types and lifetimes per resource type; manage issuance policies | PRV-005, ZTS-002 |
| CPX-002 | DCM Interaction Credential Issuance | — | Validate scoped interaction credential on every DCM dispatch; reject interactions without valid scoped credential (CPX-002) | Configure interaction credential lifetime per profile; manage Credential Provider for DCM-internal use | ZTS-002, PRV-001 |
| CPX-003 | Credential Rotation | Receive rotation notification before old credential expires; retrieve new credential during transition window | Implement rotate endpoint; honor transition window; notify DCM when rotation is complete | Configure rotation schedules and transition windows per credential type; manage pre-expiry rotation warnings | CPX-001, IAM-001 |
| CPX-004 | Emergency Rotation and Security Event Response | Receive immediate notification on emergency rotation; retrieve new credential via fastest channel | Implement immediate revocation with no transition window on security_event trigger | Configure security event triggers; manage emergency rotation audit trail; notify platform admin | CPX-003, OBS-004 |
| CPX-005 | Credential Revocation | Receive revocation notification when credentials are revoked (actor deprovisioned, entity decommissioned); confirm transition to new credential | Implement revoke endpoint with declared SLA; invalidate value immediately on emergency revocation | Manage Credential Revocation Registry; configure revocation cache TTL per profile (PT1M standard, PT30S fsi/sovereign); enforce CPX-007 (decommission blocks on credential revocation) | CPX-001, LCM-007 |
| CPX-006 | Revocation Propagation | — | Refresh revocation cache within profile-governed TTL; validate credential UUID against cache at use time (not only at receipt) | Configure revocation cache TTL; monitor revocation propagation latency; alert on SLA violations | CPX-005, IAM-001 |
| CPX-007 | Audit Trail for Credential Lifecycle | View own credential record history (issue, rotate, revoke events); every value retrieval audited with retrieval_uuid | — | Query full credential audit trail including retrieval count; manage credential audit retention | CPX-001, AUD-001 |

---


## 24. Authority Tier Model

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| ATM-001 | Authority Tier Registry | Reference approval decisions by tier name; tier weight resolved dynamically from ordered list | Implement approval workflows that reference tier names (not hardcoded weights) | Manage the ordered authority tier list; control tier positions and gravity values | POL-005 |
| ATM-002 | Custom Tier Definition | — | — | Contribute custom tiers between existing tiers; declare decision_gravity and dcm_gate semantics; requires verified-tier approval | ATM-001, FCM-001 |
| ATM-003 | Dynamic Threshold Configuration | View which tier an action routes to | — | Configure profile approval_routing as named-tier threshold list; adjust score ranges when new tiers inserted | ATM-001, SMX-001 |
| ATM-004 | Tier Registry Change Impact Detection | Receive notification when tier changes affect owned resources or pending approvals | — | Propose tier registry changes; receive tier impact diff report; review SECURITY_DEGRADATION and BROKEN_REFERENCE items; accept degradations via Admin API | ATM-001, AUD-001 |
| ATM-005 | Degradation Review Gate | — | — | Review and explicitly accept each SECURITY_DEGRADATION item before a registry change activates; provide compensating control rationale; must hold verified or authorized tier reviewer role | ATM-004, IAM-001 |
| ATM-006 | Profile Gap Detection | — | — | Receive PROFILE_GAP warnings when tier registry changes leave profile threshold lists incomplete; update threshold lists or acknowledge gap within approval window | ATM-003, ATM-004 |
| ATM-007 | Tier Registry Audit Trail | Query historical tier registry versions and impact reports | — | Access full audit trail of all tier registry changes: proposal, impact assessment, degradation acceptances, activation | ATM-004, AUD-001 |

---


## 25. Event Catalog

| ID | Capability | Consumer | Service Provider | Platform/Admin | Depends On |
|----|-----------|---------|---------|---------------|-----------|
| EVT-001 | Event Subscription | Subscribe to DCM events via Notification Provider or Message Bus; filter by event type, entity type, urgency; idempotency via event_uuid | Publish standard events when provider actions occur; use reverse-DNS prefix for non-standard events | Configure Notification Provider channels and audience routing | IAM-001, OBS-001 |
| EVT-002 | Request Pipeline Events | Receive real-time status of own requests (submitted → intent_captured → policies_evaluated → requires_approval → approved → dispatched → realized/failed) | — | Configure request event delivery per profile; manage urgency routing | REQ-001 |
| EVT-003 | Entity Lifecycle Events | Receive entity lifecycle events (realized, state_changed, ttl_warning, decommissioning, etc.) for owned entities and entities with stakes | — | Configure entity event delivery; manage stakeholder audience routing | LCM-001 |
| EVT-004 | Security and Critical Events | Receive critical security events (audit chain alerts, sovereignty violations, unsanctioned provider writes) regardless of subscription preferences | — | Configure non-suppressable event delivery; manage security team routing | AUD-001, ZTS-001 |
| EVT-005 | Approval Pipeline Events | Receive approval events (requires_approval, decision_recorded, quorum_reached, window_expiring, expired) for own requests and approvals | — | Configure reviewer notification routing; manage approval window alerts | ATM-001, IAM-001 |
| EVT-006 | Provider and Infrastructure Events | — | Publish provider health events (registered, healthy, unhealthy, degraded); publish provider_update events on entity changes | Monitor provider health events; configure provider degradation alerts | PRV-001 |
| EVT-007 | Tier Registry and Governance Events | — | — | Receive tier_registry events (proposed, impact_assessed, degradation_detected, activated); configure governance event routing | ATM-004 |

---


## Capability Count Summary

| Domain | Capabilities |
|--------|-------------|
| Identity and Access Management | 7 |
| Service Catalog | 7 |
| Request Lifecycle Management | 10 |
| Provider Contract and Realization | 9 |
| Resource Lifecycle Management | 7 |
| Drift Detection and Remediation | 5 |
| Policy Management | 7 |
| Data Layer Management | 5 |
| Information and Data Integration | 6 |
| Ingestion and Brownfield Management | 4 |
| Audit and Compliance | 5 |
| Observability and Operations | 5 |
| Storage and State Management | 6 |
| DCM Federation and Multi-Instance | 5 |
| Platform Governance and Administration | 7 |
| Accreditation Management | 6 |
| Zero Trust and Security Posture | 6 |
| Unified Governance Matrix | 7 |
| Drift Reconciliation | 5 |
| Federated Contribution Model | 7 |
| Scoring Model | 8 |
| Meta Provider Composability | 7 |
| Credential Provider Model | 7 |
| Authority Tier Model | 7 |
| Event Catalog | 7 |
| **Total** | **162** |

---

## Dependency Map — Critical Path Capabilities

These capabilities block the most downstream work and should be implemented first:

```
IAM-001 (Actor Authentication)
  └── IAM-002 (Session Tokens) → IAM-003 (RBAC) → IAM-007 (Tenant Scope)
        └── CAT-001 (Service Catalog)
              └── REQ-001 (Submit Request)
                    └── REQ-002 (Intent State) → REQ-003 (Layer Assembly)
                          └── REQ-004 (Policy Evaluation) → REQ-005 (Placement)
                                └── REQ-007 (Provider Dispatch)
                                      └── PRV-003 (Realization) → PRV-005 (Realized State)
                                            └── LCM-001 (State Transitions)
                                                  └── DRF-001 (Discovery) → DRF-002 (Drift)

PRV-001 (Provider Registration) — parallel critical path
  └── PRV-002 (Naturalization) → PRV-003 (Realization)
  └── PRV-006 (Capacity Reporting) → REQ-005 (Placement)
```

**Minimum viable DCM capability set (to demonstrate end-to-end lifecycle):**

IAM-001 → IAM-002 → IAM-003 → IAM-007 → CAT-001 → REQ-001 → REQ-002 → REQ-003 → REQ-004 → REQ-005 → REQ-006 → REQ-007 → PRV-001 → PRV-002 → PRV-003 → PRV-004 → PRV-005 → LCM-001 → DRF-001 → DRF-002 → AUD-001

**21 capabilities for a functional end-to-end demonstration.**

**Note:** FCM-001 through FCM-007 (Federated Contribution Model) are not on the critical path — they extend DCM's multi-user capabilities but are not required for the initial end-to-end lifecycle demonstration.

---

*Document maintained by the DCM Project. For questions or contributions see [GitHub](https://github.com/dcm-project).*
