---
title: "Unified Provider Contract"
type: docs
weight: -9
---

> **⚠️ Active Development Notice**
>
> The DCM data model and architecture documentation are actively being developed.
>
> Contributions, feedback, and discussion are welcome via [GitHub](https://github.com/dcm-project).

**Document Status:** 🔄 In Progress
**Document Type:** Architecture Foundation
**Related Documents:** [Foundational Abstractions](00-foundations.md) | [Policy Contract](B-policy-contract.md) | [Registration Specification](../specifications/dcm-registration-spec.md) | [Governance Matrix](27-governance-matrix.md) | [Accreditation](26-accreditation-and-authorization-matrix.md)

---

## 1. The Unified Provider Contract

Every Provider in DCM — regardless of type — implements a single base contract. What varies between provider types is the **capability extension**: the specific operations exposed, the data that flows in each direction, and the typed schemas for that exchange.

```
┌─────────────────────────────────────────────────────────┐
│                BASE PROVIDER CONTRACT                    │
│                                                          │
│  Registration · Health · Sovereignty · Accreditation    │
│  Governance Matrix · Zero Trust · Lifecycle              │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │           CAPABILITY EXTENSION                   │   │
│  │                                                  │   │
│  │  What operations this provider type exposes.     │   │
│  │  What data flows in which direction.             │   │
│  │  What schemas govern the exchange.               │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**Adding a new provider type** = implement the base contract + define a capability extension. No changes to the core required.

---

## 2. Base Contract — Registration

All providers register through the same pipeline. See [Registration Specification](../specifications/dcm-registration-spec.md) for the complete flow.

```yaml
provider_base_registration:
  # Standard artifact metadata
  artifact_metadata:
    uuid: <uuid>
    handle: "<tier>/<category>/<name>"    # e.g., "org/compute/eu-west-prod-1"
    version: "1.0.0"
    status: submitted                      # submitted → validating → active
    owned_by: { display_name: "<team>" }

  provider_type_id: <type>               # from Provider Type Registry
  display_name: "<human-readable name>"
  description: "<what this provider does>"

  # All providers declare these
  sovereignty_declaration:
    operating_jurisdictions: [<country_codes>]
    data_residency_zones: [<zone_ids>]
    sub_processors: []                   # third parties with data access

  accreditations:
    - accreditation_uuid: <uuid>         # reference to registered accreditation
      framework: <framework>
      status: active

  # Endpoints (which endpoints are required varies by type — see extensions)
  health_endpoint: "https://<provider>/health"

  # Zero trust identity
  certificate:
    pem: <provider-certificate>
    ca_chain: <ca-chain>
    rotation_interval: P90D
```

**Registration lifecycle states:**
```
SUBMITTED → VALIDATING → PENDING_APPROVAL → ACTIVE
                       ↘ REJECTED
ACTIVE → SUSPENDED | DEREGISTERING → DEREGISTERED | FORCED_DEREGISTERED
```

---

## 3. Base Contract — Health Check

Every provider implements a health endpoint. DCM calls it on the declared interval.

```
GET {health_endpoint}

Response 200:
{
  "status": "healthy | degraded | unhealthy",
  "version": "<provider version>",
  "capabilities_available": ["<list of currently available capabilities>"],
  "details": { }    # provider-specific; DCM treats as opaque
}
```

**DCM response to health states:**
- `healthy` → normal operations; next poll scheduled
- `degraded` → reduced routing preference; platform admin notified (medium urgency)
- `unhealthy` / no response → after `failure_threshold`: status → DEGRADED; new requests not routed
- After 2× `failure_threshold`: status → UNAVAILABLE; drift detection triggered on all hosted entities

---

## 4. Base Contract — Governance Matrix Enforcement

Every interaction with every provider is evaluated against the Governance Matrix before data crosses the boundary. This is not optional and not configurable per provider — it is a base contract requirement.

```
Outbound interaction (DCM → Provider):
  1. Classify all fields in the payload by data_classification
  2. Resolve provider's active accreditations
  3. Evaluate Governance Matrix: permitted | strip_field | deny | redact
  4. Apply field permissions
  5. Audit record written (regardless of outcome)
  6. If DENY: interaction blocked; entity enters PENDING_REVIEW if appropriate

Inbound interaction (Provider → DCM):
  1. Authenticate provider identity (mTLS)
  2. Verify credential scope matches the operation
  3. Accept payload; apply data_classification tags
  4. Store in appropriate store per data_classification
```

---

## 5. Base Contract — Zero Trust

All provider interactions operate under the active zero trust posture. Minimum requirement for all providers at all profiles:

- Mutual TLS authentication on every call (both sides present certificates)
- Scoped, short-lived interaction credentials (not long-lived API keys)
- Every call authenticated; no implicit trust from network position or prior calls
- Certificate rotation on declared interval

Higher profiles add: certificate pinning, per-message signing, hardware attestation.

---

## 6. Base Contract — Provider Lifecycle Events

Providers must report state changes via lifecycle events. This is a base contract obligation — not optional:

```json
POST {dcm_lifecycle_endpoint}
{
  "event_uuid": "<uuid>",
  "event_type": "<event_type>",
  "provider_uuid": "<uuid>",
  "affected_entity_uuids": ["<uuid>"],
  "event_timestamp": "<ISO 8601>",
  "severity": "INFO | WARNING | CRITICAL"
}
```

---

## 7. Capability Extensions — All Eleven Types

### 7.1 Service Provider

**What it does:** Realizes infrastructure resources. Receives assembled payloads, provisions the resource, returns realized state.

**Additional endpoints:**
```
POST {dispatch_endpoint}         # receive and execute dispatch payload
POST {cancel_endpoint}           # receive cancellation request (if supported)
POST {discover_endpoint}         # receive discovery request; return discovered state
```

**Capability declaration extension:**
```yaml
service_provider_capabilities:
  resource_types:
    - fqn: Compute.VirtualMachine
      spec_version: "2.1.0"
      catalog_item_uuid: <uuid>
  cancellation:
    supports_cancellation: true
    cancellation_supported_during: [DISPATCHED, PROVISIONING]
  discovery:
    supports_discovery: true
    discovery_method: api_query | passive_event | hybrid
  naturalization:
    target_format: openstack_nova | vmware_vsphere | custom
  cost_metadata:
    opex_per_unit_per_hour: 0.28
    currency: USD
```

**Data direction:** DCM sends assembled Requested State → Provider naturalizes → executes → denaturalizes → returns Realized State. DCM writes Realized State to Snapshot Store.

---

### 7.2 Information Provider

**What it does:** Serves authoritative external data to enrich DCM's understanding of resources and business context.

**Additional endpoints:**
```
POST {query_endpoint}            # receive query; return data in DCM unified format
POST {write_back_endpoint}       # optional; receive DCM updates to push to source system
```

**Capability declaration extension:**
```yaml
information_provider_capabilities:
  data_domains:
    - domain: business_data
      data_types: [business_unit, cost_center, product_owner]
      authority_level: primary | secondary | supplementary
  query_capacity:
    max_queries_per_second: 100
  confidence_model:
    data_freshness_sla: PT1H
  write_back_supported: false
```

**Data direction:** DCM sends lookup query → Provider returns data in DCM format → DCM enriches entity fields.

---

### 7.3 Storage Provider

**What it does:** Persists DCM state data. Implements one or more store contracts (GitOps, write-once snapshot, event stream, search index, audit).

**Additional endpoints:**
```
POST {write_endpoint}            # receive and persist data
GET  {read_endpoint}             # return stored data
POST {query_endpoint}            # execute indexed query (search index sub-type)
GET  {health_endpoint}           # includes store-specific metrics
```

**Capability declaration extension:**
```yaml
storage_provider_capabilities:
  store_types:
    - gitops               # Intent and Requested stores
    - write_once_snapshot  # Realized store
    - event_stream         # Discovered store
    - search_index         # Query projection
    - audit                # Audit store
  consistency: strong | eventual | bounded_staleness
  geo_replicated: true
  encryption_at_rest: AES-256
  hsm_backed: false
```

**Data direction:** Bidirectional. DCM writes state; DCM reads state. Provider never initiates.

---

### 7.4 Meta Provider

**What it does:** Composes multiple child providers to deliver a compound service as a single catalog item. The Meta Provider declares a compound service definition — constituent resource types, dependencies, and delivery requirements — so DCM can place, sequence, and govern the constituents. For its own resource types (`provided_by: self`), the Meta Provider executes as a standard Service Provider. All orchestration, placement, sequencing, failure handling, and compensation is performed by DCM using the declared dependency graph.

> **Full specification:** See [Meta Provider Composability Model](30-meta-provider-model.md) for the complete orchestration contract, four-state model, failure propagation, compensation, and system policies (MPX-001–MPX-008).

**Capability declaration extension (summary — full schema in doc 30):**
```yaml
meta_provider_capabilities:
  constituent_provider_types: [service_provider, information_provider, meta_provider]
  composition_model:
    execution: dependency_ordered    # sequential | parallel | dependency_ordered
    max_concurrent_realizations: 10
    max_constituent_count: 20
    max_nesting_depth: 3
  partial_delivery_supported: true
  compensation_supported: true      # required if partial_delivery_supported: true (MPX-001)
  compensation_timeout: PT30M
  idempotency_guaranteed: true
  status_reporting:
    supported: true
    interval: PT30S
  resource_types_composed:
    - fqn: ApplicationStack.WebApp
      version: "2.0.0"
      constituents:
        - resource_type: Compute.VirtualMachine
          required_for_delivery: required
        - resource_type: Network.IPAddress
          required_for_delivery: required
        - resource_type: DNS.Record
          required_for_delivery: partial
      composition_visibility: selective   # opaque | transparent | selective
```

**Composite status determination:**
- `REALIZED` — all required constituents succeeded
- `DEGRADED` — required constituents succeeded; one or more partial constituents failed (accepted if `partial_delivery_supported: true`)
- `FAILED` — one or more required constituents failed → compensation executes

**Data direction:** DCM sends fully assembled compound payload → Meta Provider orchestrates constituents in dependency order → aggregates realized states → returns compound realized state to DCM.

---

### 7.5 Policy Provider

**What it does:** Evaluates policies externally. Receives a DCM payload, evaluates Rego or custom logic, returns a typed policy decision.

**Additional endpoints:**
```
POST {evaluate_endpoint}         # receive payload; return policy decision
POST {test_endpoint}             # receive test case; return evaluation result (shadow mode)
```

**Capability declaration extension:**
```yaml
policy_provider_capabilities:
  mode: 1 | 2 | 3 | 4
  policy_types: [gatekeeper, validation, transformation, recovery]
  framework: opa | cedar | custom
  shadow_mode_supported: true
  endpoint_sovereignty_zone: <zone_id>   # required for Mode 4
```

**Data direction:** DCM sends payload + active policy bundle → Provider evaluates → returns typed decision (allow/deny, mutations, action).

---

### 7.6 Credential Provider

**What it does:** Issues, stores, rotates, and revokes credentials and secrets.

**Additional endpoints:**
```
POST {issue_endpoint}            # request a credential; return scoped credential
POST {rotate_endpoint}           # rotate an existing credential
DELETE {revoke_endpoint}         # revoke a credential
```

**Capability declaration extension:**
```yaml
credential_provider_capabilities:
  credential_types: [api_key, x509_certificate, service_account_token]
  dynamic_secrets: true          # generate on demand; expire after use
  hsm_backed: false
  fips_140_2_level: 1 | 2 | 3
```

**Data direction:** DCM requests credential → Provider issues scoped credential → DCM includes in provider dispatch.

---

### 7.7 Auth Provider

**What it does:** Authenticates actor identities and resolves their roles and group memberships.

**Additional endpoints:**
```
POST {authenticate_endpoint}     # receive credentials; return auth token + claims
POST {authorize_endpoint}        # receive token + operation; return allow/deny
GET  {identity_endpoint}         # return actor claims for a token
```

**Capability declaration extension:**
```yaml
auth_provider_capabilities:
  authentication_modes: [oidc, ldap, saml, mtls, hardware_token]
  mfa_methods: [totp, push_notification, hardware_token]
  rbac_model: flat | hierarchical | abac
  step_up_supported: true
  token_lifetime:
    default: PT1H
    max: PT8H
```

**Data direction:** Consumer sends credentials → Auth Provider validates → returns token + claims → DCM extracts actor identity.

---

### 7.8 Notification Provider

**What it does:** Receives unified notification envelopes from DCM and delivers them via configured channels.

**Additional endpoints:**
```
POST {delivery_endpoint}         # receive notification envelope; deliver to channel
POST {delivery_status_endpoint}  # callback: report delivery status to DCM
```

**Capability declaration extension:**
```yaml
notification_provider_capabilities:
  delivery_channels:
    - channel_type: slack | pagerduty | email | webhook | sms | servicenow
      supports_urgency_routing: true
      config_schema_ref: <uuid>
  delivery_guarantees:
    at_least_once: true
    idempotency_key: notification_uuid
    max_latency_seconds: 30
  sovereignty_aware_delivery: true
```

**Data direction:** DCM sends notification envelope → Provider translates to channel format → delivers → reports status.

---

### 7.9 Message Bus Provider

**What it does:** Provides persistent, high-throughput asynchronous event streaming between DCM components and external systems.

**Capability declaration extension:**
```yaml
message_bus_capabilities:
  protocols: [kafka, amqp, mqtt]
  persistence: true
  durability: at_least_once | exactly_once
  external_endpoints: false          # true only if messages leave sovereignty boundary
  topics:
    - name: dcm.events
      retention: P7D
```

**Data direction:** Bidirectional publish/subscribe. DCM publishes events; components and external systems subscribe.

---

### 7.10 Registry Provider

**What it does:** Serves the Resource Type Registry — the authoritative catalog of resource types available to DCM deployments.

**Additional endpoints:**
```
GET  {registry_endpoint}         # serve registry entries (full or incremental)
GET  {bundle_endpoint}           # serve signed registry bundle (air-gapped mode)
```

**Capability declaration extension:**
```yaml
registry_provider_capabilities:
  serves_tiers: [core, verified_community, organization]
  incremental_sync: true
  signed_bundles: true           # for air-gapped deployments
  bundle_signing_key_ref: <uuid>
```

**Data direction:** DCM pulls registry entries → Provider returns signed bundle or live entries.

---

### 7.11 Peer DCM (Federation)

**What it does:** Another DCM instance participating in federation. Treated as a typed Provider with a federation tunnel as the communication channel.

**Capability declaration extension:**
```yaml
peer_dcm_capabilities:
  dcm_version: "1.0.0"
  tunnel_type: peer | parent_child | hub_spoke
  deployment_accreditations: [<accreditation_uuids>]
  inbound_authorization:          # what this peer may request from local DCM
    - operation: catalog_query
      resource_types: [Compute.VirtualMachine]
  outbound_authorization:         # what local DCM may request from this peer
    - operation: placement_query
      resource_types: [Compute.VirtualMachine]
  data_boundary:
    max_classification: restricted
  trust_posture: verified | vouched | provisional
```

**Data direction:** Bidirectional within declared authorization scope. Federation tunnel with mTLS, certificate pinning, per-message signing.

---

## 8. Provider Type Registry

The Provider Type Registry is the authoritative list of provider types that a DCM deployment accepts registrations for. It follows the three-tier registry model (Core / Verified Community / Organization).

```yaml
provider_type_registry_entry:
  provider_type_id: service_provider
  tier: core
  default_approval_method: human_review   # auto | human_review | dual_approval | committee
  enabled_in_profiles: [minimal, dev, standard, prod, fsi, sovereign]
  capability_extension_schema_ref: <uuid>
```

Profile-governed approval methods override provider type defaults. See [Registration Specification](../specifications/dcm-registration-spec.md) Section 3 for the complete approval method resolution model.

---

## 9. Related Policies

| Policy | Rule |
|--------|------|
| `PRV-001` | All providers implement the base contract. No provider is exempt from registration, health check, sovereignty declaration, governance matrix enforcement, or zero trust authentication. |
| `PRV-002` | Governance Matrix evaluation occurs before every provider interaction. It is not configurable per provider and cannot be bypassed. |
| `PRV-003` | Provider capability declarations are verified at registration. Capabilities not declared at registration cannot be invoked after activation. |
| `PRV-004` | Peer DCM instances are treated as typed providers. Federation is the Provider abstraction applied across DCM instances — not a separate abstraction. |
| `PRV-005` | Adding a new provider type requires implementing the base contract and defining a capability extension. No changes to DCM core are required. |

---

*Document maintained by the DCM Project. For questions or contributions see [GitHub](https://github.com/dcm-project).*
