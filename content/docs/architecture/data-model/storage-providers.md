---
title: "Storage Providers"
type: docs
weight: 10
---

> **⚠️ Active Development Notice**
> 
> The DCM data model and architecture documentation are actively being developed. Concepts, structures, and specifications documented here represent work in progress and are subject to change as design decisions are finalized. Open questions are explicitly tracked and decisions are recorded as they are made.
> 
> Contributions, feedback, and discussion are welcome via [GitHub](https://github.com/dcm-project).


**Document Status:** 🔄 In Progress  
**Related Documents:** [Four States](../four-states/) | [Audit, Provenance, and Observability](../audit-provenance-observability/) | [Information Providers](../information-providers/)

---

## 1. Purpose

A **Storage Provider** is the fourth formal DCM provider type. It is the interface through which DCM persists, retrieves, and streams all state data. DCM defines the contract — the characteristics, capabilities, and obligations each store must satisfy. The implementation technology is a deployment choice made by implementors.

This is consistent with DCM's governing framework philosophy: DCM does not prescribe technology. It defines what is required and what is guaranteed. An organization using GitHub and Kafka satisfies the same contracts as one using Gitea and EventStoreDB.

---

## 2. The Four Provider Types

| Provider Type | Purpose | Data Direction | DCM Owns Result? |
|--------------|---------|---------------|-----------------|
| **Service Provider** | Realizes resources | DCM → Provider → DCM | Yes |
| **Information Provider** | Serves external authoritative data | DCM → Provider (lookup) | No |
| **Meta Provider** | Composes multiple providers | DCM → Meta → Children → DCM | Yes |
| **Storage Provider** | Persists and streams DCM state | DCM ↔ Provider | Yes — DCM is authoritative |

---

## 3. Storage Provider Contract — Base Requirements

All Storage Providers share these base contract requirements regardless of store type:

### 3.1 Registration
Same model as Service and Information Providers. Storage Providers register with DCM declaring their endpoint, store type, capabilities, and sovereignty characteristics.

```yaml
storage_provider_registration:
  uuid: <uuid>
  name: <provider name>
  display_name: <human-readable name>
  store_type: <gitops|event_stream|search_index|audit|observability>
  version: <Major.Minor.Revision>
  endpoint: <base URL>
  capabilities: <list — store-type specific>
  sovereignty_constraints: <same model as all providers>
  trust_declaration: <same model as all providers>
  status: <active|deprecated|retired>
```

### 3.2 Health Check
Same model as all providers. `GET /health` endpoint, DCM polls on configurable interval.

### 3.3 Trust
Same model as all providers. DCM validates Storage Provider identity before writing or reading state data. A compromised Storage Provider is treated as a sovereignty incident.

### 3.4 Provenance Emission Obligation
Every Storage Provider that holds state data has a contractual obligation to emit provenance events to the Audit component when state is written or modified. This is not optional — it is part of the Storage Provider contract.

```yaml
# Provenance emission event — sent to Audit component on every write
provenance_emission:
  store_type: <store type>
  operation: <write|update|delete|merge|commit>
  entity_uuid: <entity UUID affected>
  record_uuid: <UUID of the specific record written>
  actor_uuid: <UUID of the actor that triggered the write>
  timestamp: <ISO 8601>
  payload_hash: <cryptographic hash of the written payload>
  store_reference: <store-specific reference — git commit hash, event ID, etc.>
```

### 3.5 Consistency Guarantee Declaration
Each Storage Provider must declare its consistency model in registration. DCM components read this declaration and adapt their behavior accordingly.

```yaml
consistency_declaration:
  consistency_model: <strong|eventual|linearizable>
  replication_factor: <integer>
  durability_guarantee: <fsync|replicated|acknowledged>
  max_data_loss_window: <duration — e.g., PT0S for zero data loss>
```

---

## 4. GitOps Store Contract

Used for: Intent State, Requested State, Layer Store, Policy Store

### 4.1 Required Capabilities

```yaml
gitops_capabilities:
  branching: true              # Branch-per-request support
  pull_request: true           # PR creation, review, merge
  immutable_history: true      # Commits are permanent
  ci_cd_hooks: true            # Webhook triggers on push/merge
  search_index_integration: true # Search Index companion required
  access_control: true         # Per-branch, per-path access control
  signed_commits: optional     # Recommended for audit integrity
```

### 4.2 Required API Operations

| Operation | Description | Used By |
|-----------|-------------|---------|
| `create_branch` | Create a new branch from main | Intent State creation |
| `commit_file` | Commit a file to a branch | Intent and Requested State write |
| `create_pr` | Open a Pull Request for review | Intent State review workflow |
| `merge_pr` | Merge an approved PR to main | Intent State approval |
| `get_file` | Retrieve a file by path or commit | State retrieval |
| `get_history` | Retrieve commit history for a path | Audit and rehydration |
| `trigger_ci` | Trigger CI pipeline on branch | Policy pre-validation |
| `trigger_cd` | Trigger CD pipeline on merge | Requested State assembly and dispatch |
| `post_comment` | Post a comment on a PR | CI pipeline result reporting |

### 4.3 File Structure Convention

```
{store_root}/
  tenants/
    {tenant_uuid}/
      {entity_uuid}/
        intent.yaml          # Intent State record
        # OR
        requested-state.yaml # Requested State record
```

### 4.4 Search Index Companion

Every GitOps store deployment requires a companion Search Index. The Search Index is a separate Storage Provider that maintains a queryable projection of the GitOps store. See Section 6.

---

## 5. Event Stream Store Contract

Used for: Realized State, Discovered State

### 5.1 Required Capabilities

```yaml
event_stream_capabilities:
  append_only: true            # Events are never modified or deleted
  entity_keyed_streams: true   # Each entity has its own event stream
  stream_replay: true          # Streams can be replayed from any offset
  entity_uuid_lookup: true     # O(1) lookup of stream by entity UUID
  at_least_once_delivery: true # Events are never silently lost
  configurable_retention: true # Retention period configurable per stream type
  distributed_replication: true # Data replicated across nodes
  high_throughput_write: true  # Optimized for machine-generated writes
```

### 5.2 Stream Naming Convention

```
dcm.realized.{entity_uuid}    # Realized State stream per entity
dcm.discovered.{entity_uuid}  # Discovered State stream per entity
dcm.audit.{tenant_uuid}       # Audit event stream per tenant
dcm.system                    # DCM system-level events
```

### 5.3 Required API Operations

| Operation | Description | Used By |
|-----------|-------------|---------|
| `append_event` | Append an event to an entity stream | Provider callbacks, discovery |
| `read_stream` | Read events from an entity stream from offset | State retrieval, drift detection |
| `read_latest` | Read the most recent event in a stream | Current state queries |
| `replay_stream` | Replay all events from beginning | Audit, historical reconstruction |
| `list_streams` | List streams matching a pattern | Tenant-level queries |
| `get_stream_metadata` | Get stream statistics and metadata | Health monitoring |

### 5.4 Event Envelope

Every event written to the Event Stream Store uses this envelope:

```yaml
event_envelope:
  event_uuid: <uuid>
  stream_id: <stream name>
  entity_uuid: <entity UUID>
  tenant_uuid: <tenant UUID>
  event_type: <DCM event type>
  sequence_number: <monotonic integer within stream>
  timestamp: <ISO 8601>
  schema_version: <Major.Minor.Revision>
  payload_hash: <cryptographic hash>
  payload: <event-specific payload in DCM Unified Data Model format>
  provenance:
    written_by_uuid: <UUID of component that wrote this event>
    triggered_by_request_uuid: <UUID of DCM request that caused this event>
    triggered_by_actor_uuid: <UUID of actor who initiated the action>
```

### 5.5 Retention Model

| Stream Type | Default Retention | Rationale |
|-------------|------------------|-----------|
| Realized State | Permanent | Complete audit trail required |
| Discovered State | Configurable window | Operational use only — older snapshots archived |
| Audit | Regulatory period (configurable — minimum 7 years for FSI) | Compliance requirement |

---

## 6. Search Index Contract

Used for: Queryable projection of GitOps stores

### 6.1 Role and Authority

The Search Index is explicitly **non-authoritative**. If the Search Index and the GitOps store disagree on any record, the GitOps store wins unconditionally. The Search Index is a performance layer — it is never the source of truth.

The Search Index can be rebuilt from scratch from Git history at any time. This replaceability is a contract requirement — implementors must support full index rebuild from the GitOps store.

### 6.2 Required Indexed Fields

At minimum the Search Index must index these fields from Intent and Requested State records:

```yaml
indexed_fields:
  - entity_uuid          # Universal linking key
  - tenant_uuid          # Tenant ownership
  - resource_type_name   # e.g., Compute.VirtualMachine
  - resource_type_uuid   # Registry UUID
  - lifecycle_state      # Current state
  - provider_uuid        # Selected provider
  - created_timestamp    # When the record was created
  - updated_timestamp    # When the record was last updated
  - cost_center          # Business context (if declared)
  - business_unit_uuid   # Business context (if declared)
  - git_path             # Path in GitOps store — used to retrieve full record
  - git_commit_hash      # Specific commit — used for point-in-time retrieval
```

### 6.3 Required Query Operations

| Operation | Example | Used By |
|-----------|---------|---------|
| `find_by_entity_uuid` | Find all records for entity xyz | Rehydration, audit |
| `find_by_tenant` | All entities for Tenant A | Tenant management |
| `find_by_resource_type` | All VMs across all tenants | Catalog reporting |
| `find_by_lifecycle_state` | All PENDING entities | Operational monitoring |
| `find_by_field` | All entities with cost_center=BU-PAY | FinOps reporting |
| `full_text_search` | Search across all indexed text fields | Discovery, debugging |
| `count_by_field` | Count entities grouped by resource_type | Analytics |

---

## 7. DCM-Internal Caches

DCM may maintain internal performance caches between components and stores. These are not Storage Providers — they are internal implementation details that do not require external registration or trust.

### 7.1 Cache Characteristics

- **Non-authoritative** — explicitly marked. Cache hits are not treated as ground truth.
- **Cache-aside pattern** — DCM checks cache first; on miss, reads from authoritative store and populates cache
- **Invalidation on write** — any write to an authoritative store invalidates the corresponding cache entry
- **Bounded staleness** — maximum staleness window configured per cache; entries older than the window are treated as misses
- **Rebuildable** — any cache can be cleared and rebuilt from its authoritative store

### 7.2 Candidate Cache Locations

| Cache | Authoritative Source | Purpose |
|-------|---------------------|---------|
| Layer Cache | Layer Store (Git) | Avoid repeated Git reads for frequently used layers |
| Policy Cache | Policy Store (Git) | OPA policy bundles cached in Policy Engine memory |
| Catalog Cache | Catalog Store (Git) | Service catalog items cached for presentation |
| Provider Registry Cache | Provider Registry | Registered provider list cached for routing |
| Search Index | GitOps stores | Queryable projection (also functions as a cache) |

---

## 8. Storage Provider vs Service Provider — Key Differences

| Dimension | Service Provider | Storage Provider |
|-----------|-----------------|-----------------|
| **Purpose** | Realizes resources | Persists DCM state |
| **Data direction** | DCM sends, provider executes | DCM reads and writes |
| **Naturalization** | Required — DCM format → native | Not required — DCM format throughout |
| **Denaturalization** | Required — native → DCM format | Not required |
| **Provenance emission** | Required (realized state) | Required (all writes) |
| **Capacity model** | Resource capacity | Storage capacity and throughput |
| **Health model** | Is provider healthy? | Is store reachable and consistent? |

---

## 9. Open Questions

| # | Question | Impact | Status |
|---|----------|--------|--------|
| 1 | Should Storage Providers support multi-region replication as a declared capability? | Sovereignty | ❓ Unresolved |
| 2 | How are Storage Provider failures handled — failover, queuing, or rejection? | Reliability | ❓ Unresolved |
| 3 | Should the Search Index be a separate registered Storage Provider or bundled with the GitOps store? | Architecture | ❓ Unresolved |
| 4 | How does the Storage Provider model interact with air-gapped environments? | Sovereignty | ❓ Unresolved |

---

*Document maintained by the DCM Project. For questions or contributions see [GitHub](https://github.com/dcm-project).*
