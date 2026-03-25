---
title: High Level Design
type: docs
weight: 1
---

# DCM High Level Design

> **⚠️ Active Development Notice**
> 
> The DCM data model and architecture documentation are actively being developed. Concepts, structures, and specifications documented here represent work in progress and are subject to change as design decisions are finalized. Open questions are explicitly tracked and decisions are recorded as they are made.
> 
> Contributions, feedback, and discussion are welcome via [GitHub](https://github.com/dcm-project).


## What is DCM?

DCM (Data Center Management) is an open-source **governing framework** for
enterprise on-premises and sovereign cloud infrastructure. It provides a
hyperscaler-like cloud experience — the operational model and self-service
capabilities of a public cloud provider — on infrastructure that organizations
own and control.

DCM is **not a provisioning tool**. It is the management plane that sits above
provisioning tools, governing what gets requested, approved, built, owned, and
decommissioned. Provisioning tools (Ansible, Terraform, Kubernetes operators)
become Service Providers that DCM orchestrates.

**Mission:** Seamlessly manage the complete lifecycle of all data center
infrastructure by providing a policy-governed, data-driven, and unified platform
to enable and ensure sovereignty.

---

## The Problem DCM Solves

Enterprise organizations managing private cloud infrastructure face consistent
challenges that public cloud providers have already solved — and that DCM brings
to on-premises:

| Challenge | DCM Response |
|-----------|-------------|
| **Fragmented operations** — disparate tools, no unified control | Single control plane — one API, one data model, one policy engine |
| **No source of truth** — multiple CMDBs diverge | Four-state model provides authoritative record of intent, request, realized, and discovered state |
| **High time-to-market** — a VM may require dozens of teams | Self-service catalog with policy-governed automation |
| **Drift and state discrepancy** — no reconciliation between intended and actual | Continuous drift detection comparing realized vs discovered state |
| **Sovereignty requirements** — data residency, compliance, audit evidence | Policy Engine with sovereignty enforcement, complete provenance chain |

---

## Core Principles

| Principle | Meaning |
|-----------|---------|
| **Declarative** | Data describes what should exist, not how to achieve it |
| **API-First** | Every capability is available via a standard API |
| **Policy-Governed** | All business logic flows through the Policy Engine — not hard-coded |
| **Idempotent** | Applying the same data multiple times always produces the same result |
| **Immutable if Versioned** | Published versions never change — changes produce new versions |
| **Provider-Agnostic** | DCM defines contracts, not implementations |
| **GitOps-Native** | Intent and Requested state are Git-native — branched, reviewed, versioned |
| **Kubernetes Superset** | DCM extends Kubernetes upward — operators become DCM Service Providers |

---

## Architecture Overview

DCM consists of four major architectural layers:

```
┌─────────────────────────────────────────────────────────────┐
│                    CONSUMER INGRESS                          │
│         Web UI  │  Consumer API  │  Direct API (3rd Rail)   │
└────────────────────────────┬────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────┐
│                    CONTROL PLANE                             │
│                                                              │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────┐ │
│  │ Service     │  │  Request     │  │   Policy Engine    │ │
│  │ Catalog     │  │  Payload     │  │                    │ │
│  │             │  │  Processor   │  │  Transformation    │ │
│  └─────────────┘  └──────────────┘  │  Validation        │ │
│                                      │  GateKeeper        │ │
│  ┌─────────────┐  ┌──────────────┐  └────────────────────┘ │
│  │ IDM / IAM   │  │  Audit &     │                          │
│  │             │  │  Observ.     │  ┌────────────────────┐ │
│  └─────────────┘  └──────────────┘  │   API Gateway      │ │
│                                      └────────────────────┘ │
└────────────────────────────┬────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────┐
│                      PROVIDERS                               │
│                                                              │
│  Service Providers   │  Information Providers               │
│  Meta Providers      │  Storage Providers                   │
│                                                              │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐  │
│  │ KubeVirt │ │ VMware   │ │ OpenStack│ │ HR / Finance │  │
│  │ AAP      │ │ Bare     │ │ CAPI     │ │ CMDB / ITSM  │  │
│  │ CloudNPG │ │ Metal    │ │ Storage  │ │ Custom       │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## The Four States

Every resource in DCM exists across four independently maintained state records:

| State | Question | Store |
|-------|----------|-------|
| **Intent** | What did the consumer ask for? | GitOps — immutable, branched, PR reviewed |
| **Requested** | What was approved and dispatched? | GitOps — assembled, policy-processed, full provenance |
| **Realized** | What did the provider actually build? | Event Stream — append-only, entity-keyed |
| **Discovered** | What actually exists right now? | Event Stream — ground truth for drift detection |

The **entity UUID** is the universal linking key — assigned at Intent State creation, it links the entity across all four states and all stores throughout its entire lifecycle.

---

## The Data Model

The DCM Data Model is the foundational layer that governs how all data is
represented, versioned, assembled, and governed. Key concepts:

**Data Layers** assemble a complete request payload from composable, versioned
units of configuration. 36 layer definitions can govern 40,000 VMs without
duplication. Layers are organized by Domain (system, platform, tenant, service,
provider), identified by a human-readable Handle, and ordered by a hierarchical
Priority Schema for deterministic conflict resolution.

**Resource Types** are portable, vendor-neutral definitions of resource classes.
They live in the DCM Resource Type Registry alongside Information Types
(Business.*, Identity.*, Compliance.*) — same registry, different category prefix.

**Entity Relationships** use a universal bidirectional model for all connections
between entities — whether VM-to-Storage, Application-to-WebServer, or
Resource-to-BusinessUnit. One model, all relationships.

**Field Override Control** uses a graduated three-level model: no declaration
(allow by default), simple `override: immutable`, or a full actor-permission
matrix. The Policy Engine is the sole authority for setting override control.

**Artifact Metadata** is universal — every layer, policy, resource type, catalog
item, and provider registration carries a standard metadata block with creator,
owner, modification history, and contact information.

---

## Provider Model

DCM defines **contracts**, not implementations. Four provider types:

| Type | Purpose |
|------|---------|
| **Service Provider** | Realizes resources — KubeVirt, VMware, Ansible, Terraform |
| **Information Provider** | Serves authoritative external data DCM references but does not own |
| **Meta Provider** | Composes multiple providers into higher-order services |
| **Storage Provider** | Persists DCM state — GitOps stores, event streams, audit store |

All providers follow the same registration, health check, trust, and contract model.

---

## Policy Engine

The Policy Engine is the single authoritative logic gate for all business rules.
Three policy types in execution order:

1. **Transformation** — enriches and modifies the payload; may set field constraints
2. **Validation** — checks payload against rules; pass/fail, no modification
3. **GateKeeper** — highest authority; can override any field; enforces sovereignty

Policies follow a three-tier hierarchy: Global → Tenant → User. A Global policy
cannot be overridden by Tenant or User policies. The Policy Engine uses OPA/Rego
for policy implementation.

Policies support five statuses: **developing** (dev mode only), **proposed**
(shadow execution — output captured but not applied, for validation),
**active**, **deprecated**, and **retired**.

---

## Kubernetes as a Superset

DCM is designed as a **superset of Kubernetes** — extending Kubernetes' declarative
model upward to the management plane:

| Kubernetes | DCM |
|-----------|-----|
| Single cluster | Multi-cluster, multi-infrastructure |
| Namespace isolation | First-class Tenant ownership model |
| RBAC + admission webhooks | Policy Engine with field-level override control |
| No cost attribution | Full lifecycle cost analysis |
| No cross-cluster management | Unified management plane |

Kubernetes operators become DCM Service Providers through the
[DCM Operator Interface Specification](specifications/operator-interface-spec/).
The [DCM Operator SDK](specifications/operator-sdk-api/) enables Level 1 conformance
in one day.

---

## Digital Sovereignty

DCM addresses four sovereignty dimensions:

| Dimension | DCM Enabler |
|-----------|-------------|
| **Data and Content Sovereignty** | Data Model, Policy Engine, Validated Providers |
| **Operational Sovereignty** | Policy Engine — Sovereign Execution Posture |
| **Security and Compliance** | Audit, GRC, complete provenance chain |
| **Mobility and Placement** | Policy Engine placement constraints, provider portability |

**Sovereign Execution Posture** — the target end state where all operations are
governed, auditable, and compliant with sovereignty requirements. This is the
north star concept of DCM.

---

## Request Lifecycle

A complete request lifecycle from consumer intent to realized resource:

```
Consumer submits request
  │
  ▼  [Git branch created — CI pipeline fires]
Intent State captured (immutable consumer declaration)
  │  CI: policy pre-validation, cost estimate, sovereignty check
  │  Human review via PR (if policy requires)
  ▼  [PR merged — CD pipeline fires]
Request Payload Processor
  │  Layer assembly (Base → Core → Intermediate → Service → Request)
  │  Policy Engine (Transformation → Validation → GateKeeper)
  ▼
Requested State committed to Git (full provenance chain)
  │  Provider selected by placement component
  ▼
Provider dispatch via API Gateway
  │  Naturalization: DCM format → provider native format
  │  Provider realizes resource
  │  Denaturalization: provider native → DCM format
  ▼
Realized State (event stream, provider-confirmed)
  │
  ▼  [Continuous]
Drift Detection: Discovered State vs Realized State
  │  Unsanctioned changes → Policy Engine response
  │  Drift → REVERT | UPDATE | ALERT | ESCALATE
```

---

## Related Documents

- [Data Model](data-model/) — Complete data model documentation
- [Specifications](specifications/) — Operator Interface Specification, Kubernetes compatibility, SDK API, CNCF strategy
- [Enhancements](../enhancements/) — Enhancement proposals for the DCM project
