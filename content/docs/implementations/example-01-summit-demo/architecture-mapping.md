---
title: "Architecture Mapping"
type: docs
---

# Architecture Mapping — Example Implementation #1

This document maps each component of this example implementation to the
corresponding DCM specification document. Every design decision references
the spec; this is where to look when the implementation and spec diverge.

---

## Component → Spec Mapping

| Implementation Component | DCM Spec Reference | Notes |
|--------------------------|-------------------|-------|
| `dcm-api-gateway` (Go) | doc 25 §2, doc 49 §2 (rate limiting), doc 49 §7.1 (operation_uuid) | Custom Go; mTLS via Istio; token bucket rate limit |
| `dcm-request-orchestrator` (Go) | doc 25 §2, doc 33 (Event Catalog) | Pipeline event routing via PostgreSQL `LISTEN/NOTIFY` (standard) or Kafka (high-throughput enhancement) |
| `dcm-policy-engine` (Go + OPA) | doc B (Policy Contract), dcm-opa-integration-spec | OPA sidecar per pod; Rego policies in ConfigMap bundle; Internal evaluation mode |
| `dcm-placement-engine` (Go) | doc 29 (Scoring Model) | 5-signal weights; OPA placement-weights.rego |
| `dcm-request-processor` (Go) | doc 03 (Layering), doc 25 §2 | Reads layers from database; assembles payload |
| `dcm-audit` (Go) | doc 16 (Universal Audit), doc 49 §3 | SHA-256 hash chain; writes to PostgreSQL `audit_records` |
| `dcm-catalog` (Go) | doc 06, doc 10 | Reads from PostgreSQL `catalog_items`; RBAC via Keycloak groups |
| `dcm-discovery` (Go) | doc 13 (Ingestion), doc 06 §6 | CronJob every 15 min; polling providers via OIS discovery endpoint |
| PostgreSQL (CrunchyData PGO) | doc 51 §2 (Four Data Domains) | All four data domains (Intent, Requested, Realized, Discovered) + audit + pipeline events. RLS enforces tenant isolation. |
| Keycloak (Red Hat SSO) | doc 19 (Auth Providers) | OIDC; group membership maps to DCM roles; registered as `auth_provider` |
| HashiCorp Vault | doc 51 §4.1 (Prescribed Infrastructure) | Vault-compatible secrets API; mTLS certs, provider credentials, encryption keys |
| OpenShift Service Mesh | doc 36 (Internal Component Auth) | STRICT mTLS mode; Boundary 4 threat model mitigation |
| OPA (sidecar) | dcm-opa-integration-spec, doc B | Internal evaluation mode; Rego policies for GateKeeper + Validation |
| RHDH | dcm-rhdh-integration-spec | Application Domain interface; bearer token passthrough to API Gateway |
| AMQ Streams (Kafka) | doc 51 §4.2 (Optional) | **Optional** — deployed in this example for high-throughput event streaming. Standard deployments use PostgreSQL `LISTEN/NOTIFY`. |
| GitLab CE | doc 51 §6 (Git as Ingress Adapter) | **Optional** — deployed in this example as a Git ingress adapter. Not a state store. |

---

## Data Flow: Intelligent Placement Demo

The Summit demo Intelligent Placement use case flows through the implementation as follows:

```
1. alice@corp submits VM request in RHDH
   → RHDH calls POST /api/v1/requests (Bearer token from Keycloak)
   → dcm-api-gateway validates token, assigns operation_uuid, writes to PostgreSQL operations table
   → Writes request.initiated event to pipeline_events table (LISTEN/NOTIFY triggers orchestrator)

2. dcm-request-orchestrator receives event
   → Dispatches to dcm-request-processor

3. dcm-request-processor assembles payload
   → Reads tier/zone from request fields
   → Fetches core layers and service layers from database
   → Merges: consumer fields + core layer + service layer + provenance map
   → Writes assembled payload event → dcm-policy-engine

4. dcm-policy-engine evaluates (Internal mode)
   → Calls OPA sidecar at localhost:8181
   → Evaluates: vm-sizing.rego (Validation — structural)
   → Evaluates: tier-region.rego (GateKeeper — compliance)
   → tier-region.rego checks: request zones match tier's allowed zones
   → If DENY: operation status = FAILED, reason written to audit
   → If APPROVE: payload passed to dcm-placement-engine

5. dcm-placement-engine selects provider
   → Queries all active Service Providers for capacity data
   → Calls OPA: placement-weights.rego for each candidate
   → Aggregates 5-signal scores (capacity 35% + affinity 10% + cost 20% + perf 20% + risk 15%)
   → Selects dcm-provider-vm (highest aggregate score)
   → aggregate_score >= 40 (dev profile threshold) → auto_approve
   → Writes Requested State to PostgreSQL requested_records (append-only)

6. dcm-request-orchestrator dispatches to dcm-provider-vm
   → POST /api/v1/resources (Operator Interface)
   → dcm-provider-vm receives DCM VirtualMachine payload

7. dcm-provider-vm naturalizes and executes
   → Translates DCM VirtualMachine → automation platform parameters
   → This example uses AAP: POST /api/v2/job_templates/{id}/launch
   → DCM is automation-platform agnostic — providers can use AAP, Tekton,
     Argo Workflows, direct API calls, or any execution mechanism
   → Provisions VM

8. dcm-provider-vm denaturalizes and callbacks
   → Automation completes → provider collects result
   → Translates result → DCM VirtualMachine realized state
   → POST /api/v1/provider/entities/{entity_uuid}/status to dcm-api-gateway
     (single canonical callback path — all providers use this same endpoint)
   → DCM writes Realized State to PostgreSQL realized_entities
   → DCM writes Intent State to PostgreSQL intent_records (append-only, immutable)
   → Updates operation status: OPERATIONAL
   → Writes audit record (SHA-256 hash chain)

9. alice sees result in RHDH
   → GET /api/v1/operations/{operation_uuid} shows OPERATIONAL
   → RHDH displays provisioned VM details
```

---

## Portability Considerations

This implementation is designed as a portability exercise. Providers can be replaced:

- **dcm-provider-vm**: Replace AAP/Ansible with Terraform, CloudForms, or any automation tool
  that can accept a JSON/YAML payload and return a realized state payload.
- **dcm-provider-ocp-cluster**: Replace CAPI+RHOCP with Rancher, Tanzu, or any K8s provisioner.
- **dcm-provider-network**: Replace AAP/Ansible with NetBox automation, NSO, or vendor APIs.
- **dcm-provider-acm-shim**: This is explicitly a shim — replace with a proper ACM provider
  that implements the full OIS Level 3 contract when ready.

The DCM control plane components are not aware of which specific automation tool any provider uses.
They communicate exclusively through the Operator Interface specification.

---

## Technology Stack Decision Notes

| Decision | Chosen | Alternatives | Required? |
|----------|--------|-------------|-----------|
| Database | PostgreSQL (PGO) | CockroachDB, YugabyteDB | **Required** (all four data domains) |
| Auth | Keycloak (Red Hat SSO) | Dex, Authentik, Okta (OIDC) | **Required** (registered as auth_provider) |
| Secrets | HashiCorp Vault | OpenBao, CyberArk | **Required** (Vault-compatible API) |
| Policy runtime | OPA sidecar | OPA embedded, Styra DAS | Recommended |
| Service mesh | OpenShift Service Mesh | Cilium, Linkerd | Recommended (production) |
| Event bus | AMQ Streams (Kafka) | PostgreSQL `LISTEN/NOTIFY` (default) | **Optional** — enhancement for high-throughput |
| Git server | GitLab CE | Gitea, GitHub Enterprise | **Optional** — ingress adapter only |
| API Gateway | Traefik | Envoy, Kong | Recommended |
