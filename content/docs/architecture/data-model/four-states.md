---
title: "Four States"
type: docs
weight: 2
---

> **⚠️ Active Development Notice**
> 
> The DCM data model and architecture documentation are actively being developed. Concepts, structures, and specifications documented here represent work in progress and are subject to change as design decisions are finalized. Open questions are explicitly tracked and decisions are recorded as they are made.
> 
> Contributions, feedback, and discussion are welcome via [GitHub](https://github.com/dcm-project).


**Document Status:** 🔄 In Progress  
**Related Documents:** [Context and Purpose](../context-and-purpose/) | [Entity Relationships](../entity-relationships/) | [Storage Providers](../storage-providers/) | [Audit, Provenance, and Observability](../audit-provenance-observability/)

---

## 1. Purpose

The four states are the foundational model for how DCM tracks the complete lifecycle of any resource or service. Every entity in DCM exists in one or more of these states simultaneously. The states are not sequential stages — they are parallel, independently maintained records that together provide a complete, auditable picture of what was requested, what was approved, what was built, and what actually exists.

The four states answer four distinct questions:

| State | Question Answered | Store Type |
|-------|------------------|------------|
| **Intent State** | What did the consumer ask for? | GitOps Store |
| **Requested State** | What was approved and dispatched to the provider? | GitOps Store |
| **Realized State** | What did the provider actually build? | Event Stream Store |
| **Discovered State** | What does DCM observe actually existing right now? | Event Stream Store (ephemeral) |

---

## 2. State Definitions

### 2.1 Intent State

The **Intent State** is the immutable record of a consumer's original declaration. It is captured at the moment a request is submitted — before any layer assembly, before any policy evaluation, before any provider selection.

**Characteristics:**
- Immutable once created — the consumer's original intent is never modified
- Stored in a GitOps store — branched, reviewed, merged
- The CI/CD pipeline operates on the Intent State — policy pre-validation, cost estimation, sovereignty check, approval workflow
- Versioned via Git history — every revision of an intent is traceable
- Supports human review and debate via the PR mechanism
- The entity UUID is assigned at Intent State creation — it follows the entity through all subsequent states

**When created:** Every request submission, every rehydration operation, every drift remediation authorization

**Content:** The consumer's raw declaration in DCM Unified Data Model format — what they want, not what will be built

### 2.2 Requested State

The **Requested State** is the fully assembled, policy-processed, provider-ready payload. It is produced by the Request Payload Processor from the Intent State — after layer assembly, after all policy evaluation, after provider selection.

**Characteristics:**
- Immutable once created — a new Requested State is created for each request cycle
- Stored in a GitOps store — committed, versioned, triggering CD pipeline
- The CD pipeline dispatches from the Requested State to the provider
- Contains the complete assembled payload with full field-level provenance
- Contains the results of all policy evaluations — which policies ran, what they did, what they locked
- Contains provider selection — which provider will realize this request
- Is the authoritative record of what DCM instructed a provider to build

**When created:** After Intent State approval (merge), after successful policy processing

**Content:** The complete assembled payload in DCM Unified Data Model format, with full provenance chain, policy evaluation results, provider selection, and override control metadata

### 2.3 Realized State

The **Realized State** is the provider-confirmed record of what was actually built. It is produced by the provider after successful realization — the denaturalized result of the provider's execution, translated back to DCM Unified Data Model format.

**Characteristics:**
- Append-only event stream — each state change is a new event, never an overwrite
- Stored in an Event Stream Store — high-frequency writes, entity-keyed streams
- The entity UUID is the stream key — all realized state events for an entity share the same stream
- Contains provider-specific details not in the Requested State — assigned IPs, generated passwords, actual storage sizes, provider-internal IDs
- Is the authoritative record of what actually exists from DCM's perspective
- Drift is detected by comparing Realized State against Discovered State

**When created:** After provider confirms realization, updated on every provider lifecycle event

**Content:** The realized entity in DCM Unified Data Model format, with provider-added fields, full field-level provenance including provider attribution

### 2.4 Discovered State

The **Discovered State** is what DCM observes actually existing through active discovery — polling providers, querying Kubernetes APIs, interrogating infrastructure. It is the ground truth of what physically exists, independent of what DCM thinks exists.

**Characteristics:**
- Append-only snapshot stream — each discovery cycle produces a new snapshot
- Stored in an Event Stream Store (ephemeral) — recent history retained, older snapshots archived or discarded
- High-frequency and machine-generated — not appropriate for human review
- Used exclusively for drift detection — comparing against Realized State
- May contain resources DCM did not provision — brownfield resources discovered for ingestion

**When created:** On every discovery cycle, on demand for specific entities

**Content:** Raw discovered resource state in DCM Unified Data Model format, with discovery metadata (timestamp, discovery method, provider interrogated)

---

## 3. The Entity UUID — Universal Linking Key

Every entity has a single UUID assigned at Intent State creation. This UUID is the universal key linking the entity across all four states and all stores:

```
Intent Store:    file path includes entity_uuid, content declares entity_uuid
Requested Store: file path includes entity_uuid, content declares entity_uuid
Realized Store:  event stream keyed by entity_uuid
Discovered Store: snapshot stream keyed by entity_uuid (matched via provider labels)
Audit Store:     all provenance events indexed by entity_uuid
Search Index:    entity_uuid → git_path mapping for Git stores
```

Given an entity UUID, DCM can reconstruct the complete history of that entity across its entire lifecycle — from the consumer's original intent through every state transition to the current discovered state.

---

## 4. Physical Representation — Storage Provider Model

DCM describes store **contracts**, not implementations. Each store is a Storage Provider — a formal DCM provider type with registration, health check, and trust obligations. Implementors choose the technology that satisfies the contract.

See [Storage Providers](../storage-providers/) for the complete contract specifications.

### 4.1 GitOps Stores (Intent and Requested)

**Contract characteristics:**
- Branch-per-request — each request is a branch in the store
- Pull Request semantics — review, comment, approve, merge
- Immutable history — commits are permanent records
- CI/CD hook support — commits trigger pipeline execution
- Indexed for query — a Search Index projection enables field-based queries at scale
- Entity UUID → file path mapping maintained in the Search Index

**Typical implementations:** GitHub, GitLab, Gitea, Forgejo (with Elasticsearch/OpenSearch as the Search Index)

**Repository structure:** Deferred pending Q54 resolution (provider selection in Requested State affects directory structure). Will be documented in `04-examples.md`.

### 4.2 Event Stream Stores (Realized and Discovered)

**Contract characteristics:**
- Append-only — events are never overwritten or deleted
- Entity-keyed streams — each entity has its own event stream identified by entity UUID
- Queryable by entity UUID — O(1) lookup of an entity's event stream
- Replayable — the stream can be replayed from any point to reconstruct state at any timestamp
- Distributed and redundant — data is replicated across nodes with configurable consistency guarantees
- High throughput — designed for machine-generated, high-frequency writes

**Typical implementations:** Kafka with log compaction, EventStoreDB, Apache Pulsar

### 4.3 Search Index (Git Store Projection)

**Contract characteristics:**
- Derived from Git stores — rebuilt from Git history on demand
- Explicitly non-authoritative — Git always wins if index and Git disagree
- Queryable by indexed fields: entity_uuid, tenant_uuid, resource_type, lifecycle_state, timestamp, cost_center, business_unit, provider_uuid
- Lightweight — stores indexed fields only, not full payloads
- Fast — designed for millisecond query response at millions of records

**Typical implementations:** Elasticsearch, OpenSearch, Meilisearch

---

## 5. Rehydration

Rehydration is the process of using a previously stored state record as the starting point for a new request. It is not a shortcut around governance — **all relevant governance policies always apply regardless of rehydration source.** Rehydration is a new request that happens to start from a known prior state.

### 5.1 Three Rehydration Sources

**From Intent State:**
- The consumer's original declaration is replayed
- Full layer assembly runs — current layers applied
- All governance policies run — current policies applied
- Provider selection runs fresh
- Most likely to produce a different result than the original — policies and layers may have changed
- Use cases: upgrade resource to current standards, apply new sovereignty constraints, environment refresh

**From Requested State:**
- The previously assembled, policy-processed payload is loaded
- Layer assembly is skipped — layers were already applied
- All governance policies run — current policies applied
- Provider selection: configurable via flag (see Section 5.3)
- Use cases: reproduce a resource as closely as possible to the approved specification

**From Realized State:**
- The provider-confirmed realized payload is loaded
- Provider-specific fields are stripped — DCM unified format only
- Layer assembly is skipped
- All governance policies run — current policies applied
- Provider selection: configurable via flag
- Use cases: exact reproduction for disaster recovery, environment cloning, replacing a failed resource

### 5.2 The Common Governance Pipeline

Regardless of rehydration source, all requests flow through the same governance pipeline:

```
Rehydration source selected and loaded
  │
  │  Source payload becomes the basis for a new Intent State record
  │  New entity UUID assigned (or existing UUID preserved — policy decision)
  │  Rehydration provenance recorded: source_store, source_record_uuid,
  │  rehydration_reason, requested_by_uuid, rehydration_timestamp
  ▼
If source = Intent:
  │  Full layer assembly runs (Steps 1-7)
  │  Current layers applied
  ▼
If source = Requested or Realized:
  │  Layer assembly skipped
  │  Payload loaded as pre-assembled
  │  If source = Realized: provider-specific fields stripped
  ▼
Placement evaluation
  │  See Section 5.3 — configurable
  ▼
Policy Engine — ALL governance policies applied
  │  Authorization policies: does this actor have permission to rehydrate?
  │  Transformation policies: current enrichment applied
  │  Validation policies: current constraints checked
  │  GateKeeper policies: current field locks applied
  │  Gatekeeping policies: is this resource type still permitted?
  │
  │  Governance is NEVER skippable — not for any rehydration source,
  │  not for any actor, not for any urgency claim
  ▼
New Requested State produced and stored
  │  New record — never overwrites the source record
  │  Source record remains immutable
  │  Provenance chain links to source record
  ▼
Provider dispatch
  │  Dispatched to selected provider
  ▼
New Realized State events produced
  │  New event stream or continuation of existing stream
  │  Provenance links to rehydration Requested State
```

### 5.3 Placement Flag — Provider-Portable Rehydration

When rehydrating from Requested State or Realized State, provider selection is configurable via an explicit flag in the rehydration request:

```yaml
rehydration_request:
  uuid: <uuid>
  source_store: <intent|requested|realized>
  source_record_uuid: <uuid of source record>

  placement:
    re_evaluate: false
    # false (default): honor provider selection from source record
    #   Use when: original provider is available and appropriate
    #   Result: resource reproduced on same provider
    #
    # true: strip provider selection, run placement policies fresh
    #   Use when: original provider unavailable, decommissioned,
    #   at capacity, or no longer sovereign-compliant
    #   Result: placement policies select provider from current landscape
    #   Named concept: Provider-Portable Rehydration

    placement_constraints:
      # Optional — additional constraints for re-evaluation
      # Only applicable when re_evaluate: true
      exclude_provider_uuids: [<uuid>, ...]
      require_region: <region>
      require_sovereignty_capability: <capability>

  governance:
    apply_all_policies: true
    # Always true — governance is never skippable
    # Included explicitly for auditability — the rehydration record
    # must declare that governance was applied

    policy_version: current
    # current (default): apply today's policies
    # pinned: apply policies as of a specific timestamp
    #   Use when: exact historical reproduction required
    #   (audit evidence, regulatory examination, environment reconstruction)
    #   Requires elevated authorization — bypasses current GateKeeper policies
    #   Only SRE and Admin actors may use pinned policy version

    pinned_timestamp: <ISO 8601>
    # Required when policy_version: pinned

  rehydration_reason: <human-readable — recorded in provenance>
  requested_by_uuid: <actor UUID — authorization checked>
```

### 5.4 The Four Rehydration Modes

Two independent axes — placement and policy version — produce four distinct rehydration configurations:

| Mode | re_evaluate | policy_version | Use Case |
|------|-------------|----------------|----------|
| **Faithful** | false | current | Same provider, current governance |
| **Provider-Portable** | true | current | New provider, current governance |
| **Historical Exact** | false | pinned | Same provider, historical governance (audit evidence) |
| **Historical Portable** | true | pinned | New provider, historical governance |

Historical modes require elevated authorization. All modes run governance — the difference is whether governance uses current or pinned policies.

### 5.5 Partial Resolution of Q54 — Provider Selection

The placement flag model clarifies the Q54 question (selected_provider as policy output vs placement component). The emerging answer:

**Policies set placement constraints — the placement component selects the provider.**

A GateKeeper policy may output: "must be in region EU-WEST, must support sovereignty capability PCI-DSS." The placement component reads these constraints and selects the specific provider within those constraints. The policy does not name the provider. The placement component names the provider.

This is consistent with the portability model — a policy that names a specific provider would be portability-breaking. Policies set constraints. Placement honors constraints and selects.

---

## 6. Drift Detection

Drift is the difference between what DCM believes exists (Realized State) and what actually exists (Discovered State).

### 6.1 Drift Detection Flow

```
Discovery cycle completes
  │  Provider interrogated → Discovered State snapshot written
  ▼
Drift Detection component
  │  Loads latest Discovered State for entity UUID
  │  Loads latest Realized State events for entity UUID
  │  Field-by-field comparison
  ▼
No drift detected
  │  Discovery timestamp updated
  │  No action
  ▼
Drift detected
  │  Drift record created with:
  │    - entity_uuid
  │    - drifted_fields: [{field_path, realized_value, discovered_value}]
  │    - discovery_timestamp
  │    - drift_severity: <minor|significant|critical>
  ▼
Policy Engine evaluates drift
  │  Drift response policy determines action:
  │    REVERT: submit a rehydration request from Realized State to restore
  │    UPDATE_DEFINITION: promote discovered state to new Realized State
  │    ALERT: notify personas, no automatic action
  │    ESCALATE: trigger human review workflow
  │
  │  Response determined by drift severity, resource type,
  │  resource ownership, and organizational policy
  ▼
Audit Store records drift event with full provenance
```

### 6.2 Unsanctioned Changes

A specific category of drift — a change made directly to a resource without a corresponding DCM request. Detected by:
- Kubernetes: CR spec change without DCM request annotation
- VMware/OpenStack: resource modification not traceable to a DCM Requested State record
- General: any Discovered State field value that differs from Realized State without a Requested State record explaining the change

Unsanctioned changes are always reported to the Policy Engine as `UNSANCTIONED_CHANGE` events. Policy determines the response.

---

## 7. CI/CD Integration

The GitOps stores are the natural integration point for CI/CD pipelines. DCM does not prescribe a specific CI/CD tool — the GitOps store contract requires hook support, and the CI/CD tool is a deployment choice.

### 7.1 CI Pipeline (Intent State)

Triggered on: branch creation or update (new or revised intent)

```
CI pipeline executes:
  1. Policy pre-validation (dry run — no state changes)
     → Reports: which policies would apply, what they would do
  2. Cost estimation
     → Reports: estimated cost for lifecycle of this resource
  3. Dependency graph validation
     → Reports: all required dependent resources, any conflicts
  4. Sovereignty constraint check
     → Reports: which sovereignty constraints apply, any violations
  5. Authorization check
     → Reports: does this actor have permission to request this resource type?
  6. Auto-approve evaluation
     → Reports: can this be merged automatically, or does it require human review?

All results posted as PR comments on the Intent State branch
Consumer and approvers can review and debate before merge
```

### 7.2 CD Pipeline (Requested State)

Triggered on: Intent State merge (PR merged to main)

```
CD pipeline executes:
  1. Request Payload Processor assembles full payload
  2. Full policy evaluation (binding — not dry run)
  3. Provider selection (or re-evaluation if placement flag set)
  4. Requested State committed to Git store
  5. Provider dispatch via API Gateway
  6. Status monitoring — poll or receive callbacks until terminal state
  7. Status written back to PR or status file
  8. Consumer notification
```

### 7.3 The Third Rail — Direct API Ingress

Not all requests come through the GitOps PR workflow. Some requests come through direct API submission — automated systems, CI/CD pipelines, Terraform providers, programmatic consumers. These bypass the human review workflow but not governance.

Direct API ingress:
- Creates an Intent State record (the submitted payload becomes the intent)
- Runs the same CI validation pipeline but non-interactively
- If auto-approve policy permits: proceeds directly to assembly and dispatch
- If human review required: creates a PR for review before proceeding
- Same governance pipeline regardless of ingress path

The three ingress paths — PR workflow, direct API, and programmatic (Terraform/Ansible) — all converge on the same governance pipeline. The ingress path affects the review workflow; it never affects governance.

---

## 8. Open Questions

| # | Question | Impact | Status |
|---|----------|--------|--------|
| 1 | Git repository structure for Intent and Requested stores — deferred pending Q54 resolution | Store design | ❓ Unresolved |
| 2 | Should the entity UUID be preserved or regenerated on rehydration? | Entity identity | ❓ Unresolved |
| 3 | For pinned policy version rehydration — what is the minimum authorization level required? | Security | ❓ Unresolved |
| 4 | How are concurrent rehydration requests for the same entity handled — serialized or rejected? | Concurrency | ❓ Unresolved |
| 5 | Should the Discovered Store retain full history or only a configurable window? | Retention | ❓ Unresolved |
| 6 | How does the Search Index handle Git store unavailability — serve stale results or fail? | Reliability | ❓ Unresolved |

---

## 9. Related Concepts

- **Storage Provider** — the formal provider type for all DCM stores
- **Entity UUID** — the universal linking key across all four states
- **Rehydration** — using a prior state record as the starting point for a new request
- **Provider-Portable Rehydration** — rehydration with provider selection re-evaluated
- **Drift Detection** — comparing Realized State against Discovered State
- **Unsanctioned Change** — a resource modification not traceable to a DCM request
- **CI/CD Integration** — GitOps stores as the natural CI/CD integration point
- **Search Index** — queryable projection of GitOps stores, explicitly non-authoritative

---

*Document maintained by the DCM Project. For questions or contributions see [GitHub](https://github.com/dcm-project).*
