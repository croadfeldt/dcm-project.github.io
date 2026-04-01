---
title: Architecture Overview
type: docs
weight: 1
---

# DCM High Level Design


---

## What is DCM?

DCM (Data Center Management) is an open-source **governing framework** for enterprise on-premises and sovereign cloud infrastructure. It provides a hyperscaler-like cloud experience — the operational model and self-service capabilities of a public cloud provider — on infrastructure that organizations own and control.

DCM is **not a provisioning tool**. It is the management plane that sits above provisioning tools, governing what gets requested, approved, built, owned, and decommissioned. Provisioning tools (Ansible, Terraform, Kubernetes operators) become Service Providers that DCM orchestrates.

**Mission:** Seamlessly manage the complete lifecycle of all data center infrastructure by providing a policy-governed, data-driven, and unified platform to enable and ensure sovereignty.

---


## Design Priority Order

Every design decision in DCM is evaluated against this hierarchy. When priorities conflict, higher priorities win.

| Priority | Principle | What it means |
|----------|-----------|--------------|
| **1. Security** | Industry best practices are the baseline | Security properties present in ALL profiles; profiles control enforcement strictness, not whether security applies |
| **2. Ease of use** | The secure path must be the easy path | Auto-approval for ordinary requests; profile defaults eliminate configuration burden; secure path is easy path |
| **3. Extensibility** | Adaptable through configuration, not code | New requirements as policy additions; new contexts as profile configuration; new providers as contract implementations; custom authority tiers inserted into ordered list without breaking existing references |
| **4. Fit for purpose** | Always required | Everything serves the lifecycle management mission: request → provision → operate → decommission |

**The `minimal` profile is "security with minimal operational overhead" — not "minimal security."** All security properties are architecturally present in every profile. What varies is automation level, enforcement thresholds, and acceptable manual intervention.

---
## Session Token Revocation and Internal Component Authentication

**Session token revocation** defines the complete lifecycle for actor sessions — how tokens are created, refreshed, and revoked. Revocation is profile-governed: `minimal` allows PT5M propagation SLA; `sovereign` requires PT5S. The Session Revocation Registry is checked on every authenticated request — no component may skip this check (AUTH-018). Emergency revocation (security event) fires a `critical` urgency event that is non-suppressable. See [Session Token Revocation](data-model/session-revocation/).

**Internal component authentication** closes the zero trust model at the internal boundary. Every call between DCM control plane components — API Gateway to Request Orchestrator, Policy Engine to Storage Provider, etc. — requires both a mTLS certificate from the Internal CA and a scoped interaction credential (ZTS-002). Components may only call targets declared in their `allowed_targets` list (ICOM-004). Bootstrap tokens are one-time-use and expire within PT1H (ICOM-007). See [Internal Component Authentication](data-model/internal-component-auth/).

---

## Authority Tier Model

DCM governs decisions through an extensible **authority tier model** — a named, ordered list where each tier expresses a required level of organizational decision gravity. The default tiers are `auto → reviewed → verified → authorized`, but organizations can insert custom tiers between existing ones. Tier weight is derived from list position at evaluation time; existing tier name references always resolve correctly.

When the tier registry changes, DCM computes a **tier impact diff** identifying any items whose effective authority requirement changed. Security degradations (lower gravity than before) block activation until explicitly accepted by a verified-tier reviewer. See [Authority Tier Model](data-model/authority-tier-model/).

---

## The Problem DCM Solves

| Challenge | DCM Response |
|-----------|-------------|
| **Fragmented operations** — disparate tools, no unified control | Single control plane — one API, one data model, one policy engine |
| **No source of truth** — multiple CMDBs diverge | Four-state model provides authoritative record of intent, request, realized, and discovered state |
| **High time-to-market** — provisioning a VM may require dozens of teams | Self-service catalog with policy-governed automation — any authorized actor can request any service |
| **Drift and state discrepancy** — no reconciliation between intended and actual | Continuous drift detection comparing realized vs discovered state with automated or human-directed remediation |
| **Sovereignty requirements** — data residency, compliance, audit evidence | Unified Governance Matrix with sovereignty zone enforcement, complete provenance chain, and accreditation management |
| **Siloed governance** — platform admins bottleneck policy changes | Federated contribution model — consumers, providers, and peer DCMs all contribute within their permitted scope |

---

## Core Principles

| Principle | Meaning |
|-----------|---------|
| **Declarative** | Data describes what should exist, not how to achieve it |
| **API-First** | Every capability is available via a standard API |
| **Policy-Governed** | All business logic flows through the Policy Engine — never hard-coded |
| **Idempotent** | Applying the same data multiple times always produces the same result |
| **Immutable if Versioned** | Published versions never change — changes produce new versions |
| **Provider-Agnostic** | DCM defines contracts, not implementations |
| **GitOps-Native** | Intent and policy artifacts are Git-native — branched, reviewed, versioned |
| **Federated by Default** | All authorized actor types contribute data within their permitted scope |
| **AI-Ready** | Standalone architecture designed with AIOps layering in mind |

---

## The Three Foundational Abstractions

Every concept in DCM maps to one of three foundational abstractions. There is no fourth.

```
┌─────────────────────────────────────────────────────────────────┐
│                          DATA                                    │
│  Everything that exists, is stored, has a lifecycle.            │
│  Entities, layers, policies, accreditations, audit records,     │
│  groups, relationships — all Data.                              │
└──────────────────────────┬──────────────────────────────────────┘
                           │ flows through
              ┌────────────┴────────────┐
              ▼                         ▼
┌─────────────────────┐   ┌─────────────────────────────────────┐
│      PROVIDER        │   │              POLICY                  │
│  Every external      │   │  Every rule that fires on Data,      │
│  component DCM       │   │  decides what happens, transforms    │
│  calls or that       │   │  values, or enforces constraints.    │
│  calls DCM.          │   │  Seven typed output schemas.         │
│  Eleven typed        │   │  One evaluation algorithm.           │
│  capability          │   │  Same lifecycle for all.             │
│  extensions.         │   │                                      │
│  One base contract.  │   │                                      │
└─────────────────────┘   └─────────────────────────────────────┘
```

**The runtime loop:**
```
Event (Data state change)
  → Policy Engine evaluates all matching Policies
  → Policies produce decisions / mutations / actions
  → Actions invoke Providers or produce new Data
  → New Data triggers new Events → repeat
```

See [Foundational Abstractions](data-model/foundations/) for the complete model.

---

## The Four States

Every resource entity in DCM has four independently maintained lifecycle stages stored in specialized stores:

| State | What it records | Store |
|-------|----------------|-------|
| **Intent** | What did the consumer declare? | GitOps — immutable, PR-reviewed |
| **Requested** | What was assembled, validated, and dispatched? | Write-once snapshot — full provenance |
| **Realized** | What did the provider confirm it built? | Snapshot store — append-only |
| **Discovered** | What actually exists right now, independently observed? | Ephemeral stream — ground truth for drift |

The **entity UUID** links the entity across all four states throughout its entire lifecycle.

---

## Provider Model

DCM defines contracts, not implementations. Eleven provider types all implement the **unified Provider base contract** (registration, health, sovereignty, accreditation, governance matrix enforcement, zero trust). What varies is the capability extension.

| Provider Type | Capability |
|--------------|-----------|
| **Service Provider** | Realizes infrastructure resources (VMs, networks, storage, containers) |
| **Information Provider** | Serves authoritative external data (CMDB, HR, Finance) |
| **Storage Provider** | Persists DCM state (GitOps stores, event streams, audit) |
| **Meta Provider** | Composes multiple providers into compound services |
| **Policy Provider** | Evaluates policies externally (OPA sidecar, Mode 1–4) |
| **Credential Provider** | Issues and rotates secrets and credentials |
| **Auth Provider** | Authenticates actor identities |
| **Notification Provider** | Delivers notifications via configured channels |
| **Message Bus Provider** | Async event streaming |
| **Registry Provider** | Serves the Resource Type Registry |
| **Peer DCM** | Another DCM instance — federation is the Provider abstraction applied across instances |

See [Unified Provider Contract](data-model/provider-contract/) for the base contract and all capability extensions.

---

## Policy Model

Policies are the orchestration in DCM. Seven typed output schemas, one base contract, one evaluation algorithm.

| Policy Type | Output | Fires on |
|-------------|--------|---------|
| **GateKeeper** | allow/deny (compliance) or risk score contribution (operational) | Request payload |
| **Validation** | pass/fail (structural) or completeness score + warnings (advisory) | Request payload |
| **Transformation** | field mutations | Request payload |
| **Recovery** | action + parameters | Failure/timeout trigger |
| **Orchestration Flow** | step sequence | Pipeline events (named workflows) |
| **Governance Matrix Rule** | ALLOW / DENY / STRIP_FIELD / REDACT | Any cross-boundary interaction — always boolean |
| **Lifecycle Policy** | action on related entity | Relationship events |

### Hybrid Scoring Model

DCM uses a **hybrid model**: questions of fact use boolean gates; questions of degree use scoring.

**GateKeeper policies declare `enforcement_class`:**
- `compliance` — boolean deny gate. Used for regulatory requirements (PHI→BAA, sovereign data boundaries). Cannot be scored around.
- `operational` — contributes a weighted `risk_score_contribution` to the aggregate request risk score. Used for operational policies (cost ceilings, size limits, quota pressure).

**Validation policies declare `output_class`:**
- `structural` — boolean pass/fail. Missing required fields, type errors.
- `advisory` — completeness score contribution + warning list. Recommended fields absent, unusual values.

**Five scoring signals** aggregate into a request risk score (0–100): operational GateKeeper contributions (45%), actor risk history (20%), completeness warnings (15%), quota pressure (10%), provider accreditation richness (10%).

**Profile-governed thresholds** map the score to approval routing: auto / reviewed / verified / authorized (+ custom tiers). Thresholds use a named-tier dynamic list; see [Authority Tier Model](data-model/authority-tier-model/). Thresholds are tunable per profile without touching individual policies. Profiles can also override enforcement class per policy — escalating operational policies to compliance-class, or demoting non-regulatory compliance policies to operational.

The Governance Matrix is **always boolean** — scoring never applies to cross-boundary data decisions.

See [Scoring Model](data-model/scoring-model/) for the complete specification.

**Two-level orchestration:**
- **Level 1 — Named Workflow Artifacts:** Orchestration Flow Policy with `ordered: true` — explicit, visible, auditable step sequence. This is the named pipeline skeleton.
- **Level 2 — Dynamic Policies:** GateKeeper, Transformation, Recovery policies fire when conditions match, alongside workflow steps, without being declared in the workflow.

Both levels are evaluated by the same Policy Engine through the same event bus. See [Unified Policy Contract](data-model/policy-contract/).

---

## Unified Governance Matrix

The Governance Matrix is the single enforcement point for all cross-boundary data and capability decisions. It governs every interaction between DCM and any provider, peer DCM, or external endpoint.

**Four axes per rule:** Subject (who) · Data (what — including field-level paths) · Target (where — sovereignty zone, jurisdiction, accreditation) · Context (profile, zero trust posture, TLS state)

**Decision vocabulary:** ALLOW · DENY · ALLOW_WITH_CONDITIONS · STRIP_FIELD · REDACT · AUDIT_ONLY

**Hard vs soft enforcement:** Hard rules cannot be relaxed by any downstream rule. `sovereign` and `classified` data never crossing any boundary is always hard.

**Profile-bound defaults:** Each profile activates a set of default matrix rules. Organizations tighten (never relax) with Tenant and resource-type overrides.

See [Unified Governance Matrix](data-model/governance-matrix/).

---

## Federated Contribution Model

DCM defaults to a federated model for data creation. Every authorized actor type can contribute Data artifacts within their permitted scope — all via the same GitOps PR model with profile-governed review.

| Contributor | Can contribute |
|-------------|---------------|
| **Platform Admin** | All artifact types at all domains |
| **Consumer / Tenant** | Tenant-domain policies, resource groups, notification subscriptions, service definitions |
| **Service Provider** | Resource Type Specs (their types), catalog items, service layers, provider policies |
| **Peer DCM** | Registry entries, policy templates, service layers (scoped by federation trust posture) |

Contributor scope is enforced by the Governance Matrix as a hard DENY — a consumer cannot contribute system-domain policies regardless of what they declare.

See [Federated Contribution Model](data-model/federated-contribution-model/).

---

## Control Plane Components

Nine internal components implement the three abstractions at runtime:

| Component | Role |
|-----------|------|
| **Request Orchestrator** | Event bus — no pipeline logic; policies define all behavior |
| **Policy Engine** | Evaluates all policy types using the same algorithm |
| **Placement Engine** | Six-step provider selection (sovereignty → accreditation → capability → reserve query → tie-breaking → confirm) |
| **Cost Analysis** | Pre-request estimation and ongoing attribution |
| **Lifecycle Constraint Enforcer** | Monitors TTL/expiry; fires expiry actions through the standard pipeline |
| **Discovery Scheduler** | Schedules and dispatches discovery requests to Service Providers |
| **Notification Router** | Resolves notification audiences from the relationship graph |
| **Drift Reconciliation** | Compares Discovered vs Realized state; produces drift records; never writes to Realized Store |
| **Search Index** | Non-authoritative queryable projection of GitOps stores; always rebuildable |

---

## Zero Trust and Security

DCM operates on a network-position-grants-zero-trust model. Every interaction boundary applies five checks regardless of the caller's network location:

```
Identity verification (mTLS)
  → Authorization verification (scoped credential)
    → Accreditation check (does the target hold required certs?)
      → Governance Matrix check (are the fields permitted to cross?)
        → Sovereignty check (does the endpoint satisfy constraints?)
```

All five checks produce audit records regardless of outcome. Profile-governed zero trust posture: none (minimal) → boundary (dev/standard) → full (prod/fsi) → hardware_attested (sovereign).

---

## Request Lifecycle

A complete path from consumer intent to realized resource:

```
Consumer submits request (API, Web UI, or Git PR)
  │
  ▼ Intent State captured — versioned GitOps artifact
  │ Policy pre-validation (shadow mode); cost estimate; sovereignty check
  │
  ▼ Request Payload Processor:
  │   1–4: Layer assembly (Base → Core → Service → Request Layer)
  │   5:   Pre-placement policies (Transformation, Validation, GateKeeper)
  │   6:   Placement Engine — sovereignty filter → accreditation filter →
  │         capability filter → parallel reserve queries → tie-breaking →
  │         confirm selection
  │   7:   Post-placement policies (provider-aware enrichment)
  │   8:   Requested State written to write-once store (full provenance)
  │   9:   Provider dispatch
  │
  ▼ Service Provider:
  │   Naturalize (DCM format → provider native)
  │   Execute (provision the resource)
  │   Denaturalize (provider native → DCM unified format)
  │   Return Realized State
  │
  ▼ Realized State written — confirmed by provider
  │
  ▼ Continuous discovery → Drift Reconciliation
      Discovered State vs Realized State
      Drift: field-level detail, severity classification, unsanctioned detection
      Response: REVERT | ACCEPT_DRIFT | NOTIFY_AND_WAIT | ESCALATE
```

---

## Capabilities Summary

134 capabilities across 21 domains. Full detail in the [Capabilities Matrix](../capabilities-matrix/).

**Minimum viable end-to-end set (21 capabilities):**
IAM-001 → IAM-002 → IAM-003 → IAM-007 → CAT-001 → REQ-001 → REQ-002 → REQ-003 → REQ-004 → REQ-005 → REQ-006 → REQ-007 → PRV-001 → PRV-002 → PRV-003 → PRV-004 → PRV-005 → LCM-001 → DRF-001 → DRF-002 → AUD-001

---

## APIs and Interfaces

| Interface | Purpose |
|-----------|---------|
| **Consumer API** | Service catalog, request submission, resource management, drift, groups, notifications, cost, quota, contribution endpoints |
| **Admin API** | Tenant management, provider review, accreditation approval, discovery triggers, orphan resolution, quota, Search Index management |
| **Operator Interface** | What Service Providers implement — dispatch, cancel, discover, health |
| **Flow GUI** | Visual policy composer — execution graph, canvas, simulation, shadow mode, authoring |
| **Flow GUI API** | Backend serving the Flow GUI — graph data, simulation, shadow promotion, canvas PR creation |

---

## Related Documents

- **[Foundational Abstractions](data-model/foundations/)** — Data, Provider, Policy — read this first
- **[Unified Provider Contract](data-model/provider-contract/)** — base contract + 11 typed extensions
- **[Unified Policy Contract](data-model/policy-contract/)** — base contract + 7 output schemas
- **[Federated Contribution Model](data-model/federated-contribution-model/)** — who contributes what and how
- **[Data Model](data-model/)** — complete 28-document data model reference
- **[Specifications](specifications/)** — Consumer API, Admin API, Operator Interface, OPA Integration, Flow GUI, Registration, Examples, Kubernetes compatibility, SDK, CNCF strategy
- **[Capabilities Matrix](../capabilities-matrix/)** — 134 capabilities across 21 domains
