# DCM Example Implementation #1 — Summit Demo

**Document Status:** 📋 Draft — Implementation Reference  
**Document Type:** Example Implementation  
**Scope:** Isolated from the normative DCM architecture. This document describes a specific reference implementation targeting the Summit 2026 demonstration use cases. All technology choices here are example choices. The DCM architecture and data model are implementation-agnostic.

> **This is Example Implementation #1.** It is not the DCM architecture. It is one way to implement the DCM architecture using specific Red Hat-sanctioned open source technologies, targeting the Summit 2026 demo use cases. Providers built here are expected to be replaced or extended. The value is validating the architecture and data model portability.

---

## 1. Purpose and Scope

This implementation targets three Summit 2026 demonstration use cases:

1. **Intelligent Placement** — Business logic via Policies: metadata-driven infrastructure placement enforcing sovereignty constraints via OPA
2. **Datacenter Rehydration** — Rehydration meta process: full DC restore from declared state across OCP Cluster, VM, and Network Port providers
3. **Application as a Service** — Meta Service Provider: single catalog entry composing VM + Network Port + OCP Cluster into a deployable application

Post-Summit use cases (Greening the Brownfield, New DC Deployment, Application Modernization) are architecturally supported but not in scope for this implementation.

**What this implementation validates:**
- DCM data model correctness end-to-end through real provider integrations
- Provider portability — providers built here should be replaceable without architectural changes
- OPA policy enforcement in the request pipeline
- Rehydration mechanics across multiple provider types
- ACM shim pattern as a normal Service Provider

---

## 2. Technology Stack

All technology choices are Red Hat-sanctioned open source projects.

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| **Container Platform** | OpenShift (OKD for open source) | Target deployment platform; all workloads as Pods |
| **Event Bus** | AMQ Streams (Apache Kafka on OpenShift) | Red Hat-sanctioned Kafka operator; durable event streaming for Request Orchestrator |
| **Database** | PostgreSQL | CrunchyData PGO operator or standard StatefulSet |
| **Git Server** | GitLab CE | Intent Store, Requested State Store, Policy Store; Red Hat-sanctioned |
| **Policy Engine** | OPA (Open Policy Agent) | Mode 3 sidecar; Rego for GateKeeper and Validation policies |
| **Secret Management** | HashiCorp Vault + External Secrets Operator | Credential Provider implementation |
| **Auth / IDM** | Keycloak (Red Hat SSO) | Auth Provider implementation; OIDC for consumers |
| **Service Mesh / mTLS** | OpenShift Service Mesh (Istio/Envoy) | mTLS between all DCM components and providers |
| **Observability** | OpenTelemetry + Prometheus + Grafana | OpenShift Monitoring stack |
| **Front End** | RHDH (Red Hat Developer Hub / Backstage) | Consumer UI; RHDH DCM plugin |
| **Automation** | Ansible Automation Platform (AAP) | Provider execution for VM and Cluster provisioning |
| **Cluster Lifecycle** | Red Hat ACM (Advanced Cluster Management) | OCP Cluster provider shim target |
| **Certificate Management** | cert-manager | Internal CA lifecycle; provider mTLS certificates |
| **CI/CD** | OpenShift Pipelines (Tekton) | Deployment pipeline |

---

## 3. Architecture Overview — Summit Demo Deployment

```
┌─────────────────────────────────────────────────────────────────────┐
│                    OpenShift Cluster (DCM Namespace)                │
│                                                                      │
│  ┌──────────────┐   ┌─────────────────────────────────────────┐    │
│  │     RHDH     │   │           DCM Control Plane              │    │
│  │  (Backstage) │──▶│  API Gateway ──▶ Request Orchestrator   │    │
│  │  DCM Plugin  │   │       │              │ (Kafka events)    │    │
│  └──────────────┘   │  ┌────▼────┐   ┌────▼────────────────┐ │    │
│                     │  │  OPA    │   │   Placement Engine   │ │    │
│  ┌──────────────┐   │  │Sidecar  │   │   Policy Engine      │ │    │
│  │   Keycloak   │──▶│  └─────────┘   │   Audit Component    │ │    │
│  │  (Auth/IDM)  │   │       │        │   Cost Analysis      │ │    │
│  └──────────────┘   │  ┌────▼────────────────────────────┐  │ │    │
│                     │  │        Data Layer                │  │ │    │
│  ┌──────────────┐   │  │  PostgreSQL │ GitLab │ Kafka     │  │ │    │
│  │    Vault     │◀──│  └─────────────────────────────────-┘  │ │    │
│  │(Credentials) │   └─────────────────────────────────────────┘    │
│  └──────────────┘                    │ mTLS (Istio)                 │
│                                      │                               │
│  ┌───────────────────────────────────▼────────────────────────┐    │
│  │                    Service Providers                         │    │
│  │  ┌────────────┐  ┌─────────────┐  ┌──────────────────────┐ │    │
│  │  │ VM Provider│  │Network Port │  │ OCP Cluster Provider │ │    │
│  │  │(AAP→KVM)   │  │Provider     │  │ (ACM Shim)           │ │    │
│  │  └────────────┘  └─────────────┘  └──────────────────────┘ │    │
│  │  ┌─────────────────────────────────────────────────────────┐│    │
│  │  │           Web App Meta Provider                          ││    │
│  │  │    (composes VM + Network Port + OCP Cluster)            ││    │
│  │  └─────────────────────────────────────────────────────────┘│    │
│  └──────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────▼──────────┐
                    │   Infrastructure   │
                    │  KVM / OpenStack   │
                    │  ACM-managed OCPs  │
                    │  Netbox / Neutron  │
                    └────────────────────┘
```

---

## 4. Service Providers — Summit Demo

### 4.1 VM as a Service Provider

**What it provisions:** KVM virtual machines (or OpenStack Nova instances for demo environments)  
**Execution chain:** DCM → AAP Job Template → Ansible Playbook → KVM/libvirt or OpenStack API  
**Resource type:** `Compute.VirtualMachine`

**DCM interface:**
- Implements Operator Interface Spec (OIS)
- Level 2 conformance (discovery + status callbacks)
- Registers resource types: `Compute.VirtualMachine`

**Naturalization:** DCM `Compute.VirtualMachine` fields → Ansible `extra_vars` → KVM/Nova provisioning  
**Denaturalization:** Nova instance detail / libvirt domain XML → DCM Realized State entity

**Key fields mapped:**
```yaml
# DCM requested state → AAP extra_vars
cpu_cores:        → vm_vcpus
ram_gb:           → vm_memory_mb  (×1024)
os_image:         → vm_image_name
network_zone:     → vm_network     (resolved from Core Layer)
sovereignty_zone: → vm_region      (enforced by GateKeeper before dispatch)
tenant_uuid:      → vm_project_id
resource_uuid:    → vm_dcm_id      (tagged on VM for discovery)
```

### 4.2 Network Port as a Service Provider

**What it provisions:** Network port allocation — IP address assignment, VLAN membership  
**Execution chain:** DCM → Netbox API (IPAM) or OpenStack Neutron  
**Resource type:** `Network.Port`

**Key concern for demo:** Network Port is provisioned as a dependency of VM provisioning (the VM Meta Provider or the Request Dependency Graph ensures ordering). The Network Port provider must echo `dcm_entity_uuid` back as a tag on the Netbox/Neutron resource for drift detection.

### 4.3 OCP Cluster as a Service Provider (ACM Shim)

**What it provisions:** OpenShift clusters via Red Hat ACM  
**Execution chain:** DCM → ACM API → ClusterDeployment (Hive) CR → OCP cluster  
**Resource type:** `Compute.OCPCluster`

**ACM Shim design:**
The shim is a thin Go service that implements the DCM Operator Interface and translates requests to ACM API calls. It is explicitly labeled as a shim — not a production ACM integration.

```
DCM CreateRequest (Compute.OCPCluster)
  │
  ▼ ACM Shim: translate to ACM ClusterDeployment CR
  {
    apiVersion: hive.openshift.io/v1
    kind: ClusterDeployment
    metadata:
      name: <cluster-name>
      namespace: <acm-managed-clusters-ns>
      annotations:
        dcm.redhat.com/resource-uuid: <resource_uuid>  # for correlation
    spec:
      clusterName: <cluster-name>
      platform: <vsphere|aws|baremetal>
      ...
  }
  │
  ▼ ACM Shim: poll ClusterDeployment status
  ▼ ACM Shim: on Installed=true → denaturalize → DCM callback
  POST /api/v1/provider/entities/{resource_uuid}/status
  { lifecycle_state: OPERATIONAL, realized_fields: { api_url, kubeconfig_secret_ref, ... } }
```

**ACM as Information Provider (also):** ACM feeds cluster inventory (capacity, health, current workloads) into DCM's placement engine via the Information Provider interface. This is how Intelligent Placement uses ACM data — placement queries ACM's ManagedCluster resources for available capacity.

### 4.4 Web App as a Service (Meta Provider)

**What it provisions:** Three-tier web application = VM (app server) + Network Port (IP + VLAN) + OCP Cluster (container runtime, optional)  
**Pattern:** Meta Provider — coordinates child providers per the Request Dependency Graph

**Dependency ordering:**
```
Network Port (no deps) ──────────────────────────┐
                                                   ▼
VM (depends on: Network Port) ────────────────▶  App Deployment complete
OCP Cluster (independent, parallel with VM) ──┘
```

**Catalog item presented to consumer:**
```yaml
catalog_item:
  name: "Web Application — Standard"
  resource_type: WebApp.ThreeTier
  fields:
    app_name: {type: string, required: true}
    environment: {type: enum, values: [dev, staging, prod]}
    sovereignty_zone: {type: string, layer_reference: location}
    include_container_runtime: {type: boolean, default: false}
```

---

## 5. Demo Use Case Flows

### 5.1 Intelligent Placement Demo

**Goal:** Consumer requests a VM specifying only sovereignty zone and SLA tier. DCM automatically places it on the correct infrastructure enforcing the sovereignty constraint via OPA.

**OPA Rego policy (Tier Region Policy — matches slide 17):**
```rego
package dcm.placement.sovereignty

import future.keywords.every

# GateKeeper policy: enforce sovereignty zone constraint
# enforcement_class: compliance (boolean deny — halts request if violated)

deny[msg] {
    input.request.fields.sovereignty_zone != null
    required_zones := {z | z := input.request.fields.sovereignty_zone}
    provider_zones := {z | z := input.provider.sovereignty_zones[_]}
    some zone in required_zones
    not zone in provider_zones
    msg := sprintf("Provider %v does not serve sovereignty zone %v", 
                   [input.provider.handle, zone])
}
```

**Request flow:**
```
1. Consumer submits via RHDH:
   POST /api/v1/requests
   { catalog_item_uuid: "vm-standard", fields: { cpu: 8, ram_gb: 32, sovereignty_zone: "EU-WEST" } }

2. Intent State written to GitLab

3. Transformation Policy fires:
   → Injects network_zone from EU-WEST Core Layer
   → Injects security_baseline from PROD GateKeeper policy group

4. Placement Engine evaluates eligible providers:
   → VM Provider EU-WEST-1: sovereignty_zones: [EU-WEST] ✅, capacity: 78% ✅ → score: 72
   → VM Provider US-EAST-1: sovereignty_zones: [US-EAST] ❌ → OPA deny fires → excluded

5. OPA GateKeeper evaluated on winning provider:
   → Tier Region Policy: EU-WEST zone present ✅
   → Security Baseline: PHI classification requires EU-WEST ✅ → PASS

6. Requested State assembled → dispatched to VM Provider EU-WEST-1

7. AAP job runs → KVM VM provisioned → callback to DCM
   POST /api/v1/provider/entities/{resource_uuid}/status { lifecycle_state: OPERATIONAL }

8. Realized State written → consumer notified via RHDH
```

### 5.2 Datacenter Rehydration Demo

**Goal:** CIO scenario — total DC loss. Rehydrate entire environment from Intent State in GitLab across all providers.

**Trigger:**
```
POST /api/v1/requests
{
  "catalog_item_uuid": "rehydration-full-dc",
  "fields": {
    "source_dc": "DC1-FRANKFURT",
    "target_dc": "DC2-AMSTERDAM",
    "rehydration_mode": "intent",    # replay original intent through current policies
    "scope": "all"
  }
}
```

**Rehydration Meta Provider orchestration:**
```
1. Retrieve all Intent State records for source_dc from GitLab
2. Build dependency graph across all resources
3. Topological sort: Network Ports first → VMs second → OCP Clusters (parallel with VMs)
4. For each resource in order:
   a. Replay Intent State through current Transformation Policies (policies may have changed)
   b. Re-evaluate Placement (target DC may have different providers)
   c. Dispatch to target DC providers
   d. Write new Realized State on success
5. Report completion status per resource
```

**What the demo shows:**
- Full DC state is declarative and replayable from GitLab
- Policies govern rehydration, not manual runbooks
- Drift between source DC Realized State and target DC Realized State is automatically reconciled
- ACM re-registers clusters with new DC's ACM hub after OCP Cluster provider completes

### 5.3 Application as a Service Demo

**Goal:** Application owner requests "Web Application — Standard" as a single catalog item. DCM orchestrates VM + Network Port + OCP Cluster as a unit.

**What the demo shows:**
- Meta Provider pattern: one request → multiple coordinated provider dispatches
- Dependency graph enforcement: Network Port before VM
- Single audit trail across all sub-resources
- Single decommission reverses all sub-provisions

---

## 6. Namespace and Pod Design

All DCM control plane components run in a single OpenShift namespace: `dcm-system`.  
Service Providers run in `dcm-providers`.  
Supporting infrastructure (GitLab, Kafka, PostgreSQL, Vault, Keycloak) runs in `dcm-infra`.

### 6.1 Pod Definitions

**DCM API Gateway Pod:**
```yaml
containers:
  - name: api-gateway
    image: dcm/api-gateway:latest
    ports: [{containerPort: 8080, name: http}, {containerPort: 8443, name: https}]
    env:
      - {name: DCM_KAFKA_BROKERS, valueFrom: {configMapKeyRef: {name: dcm-config, key: kafka.brokers}}}
      - {name: DCM_DB_URL, valueFrom: {secretKeyRef: {name: dcm-db-secret, key: url}}}
      - {name: DCM_OPA_URL, value: "http://localhost:8181"}
    volumeMounts:
      - {name: tls-certs, mountPath: /etc/dcm/tls}
  - name: opa-sidecar                        # OPA sidecar for policy pre-check
    image: openpolicyagent/opa:latest-static
    args: ["run", "--server", "--addr=:8181", "--bundle=/policies"]
    volumeMounts:
      - {name: opa-policies, mountPath: /policies}
volumes:
  - name: tls-certs
    secret: {secretName: dcm-api-gateway-tls}
  - name: opa-policies
    configMap: {name: dcm-opa-policies}
```

**Request Orchestrator Pod:**
```yaml
containers:
  - name: orchestrator
    image: dcm/request-orchestrator:latest
    env:
      - {name: DCM_KAFKA_BROKERS, valueFrom: {configMapKeyRef: ...}}
      - {name: DCM_GITLAB_URL, valueFrom: {configMapKeyRef: ...}}
      - {name: DCM_GITLAB_TOKEN, valueFrom: {secretKeyRef: {name: dcm-gitlab-secret, key: token}}}
      - {name: DCM_DB_URL, valueFrom: {secretKeyRef: ...}}
```

**Policy Engine Pod (OPA standalone for complex policies):**
```yaml
containers:
  - name: opa-server
    image: openpolicyagent/opa:latest-static
    args: ["run", "--server", "--addr=:8181",
           "--bundle=/policies/bundles",
           "--log-level=info"]
    ports: [{containerPort: 8181, name: opa}]
    volumeMounts:
      - {name: policy-bundles, mountPath: /policies/bundles}
    livenessProbe:
      httpGet: {path: /health, port: 8181}
volumes:
  - name: policy-bundles
    projected:
      sources:
        - configMap: {name: dcm-opa-core-policies}
        - configMap: {name: dcm-opa-placement-policies}
        - configMap: {name: dcm-opa-sovereign-policies}
```

**VM Service Provider Pod:**
```yaml
containers:
  - name: vm-provider
    image: dcm/provider-vm:latest
    env:
      - {name: DCM_CONTROL_PLANE_URL, valueFrom: {configMapKeyRef: ...}}
      - {name: AAP_URL, valueFrom: {configMapKeyRef: {name: aap-config, key: url}}}
      - {name: AAP_TOKEN, valueFrom: {secretKeyRef: {name: aap-secret, key: token}}}
      - {name: PROVIDER_UUID, valueFrom: {configMapKeyRef: {name: vm-provider-config, key: provider_uuid}}}
    volumeMounts:
      - {name: provider-tls, mountPath: /etc/provider/tls}
      - {name: provider-config, mountPath: /etc/provider/config}
```

---

## 7. OpenShift Deployment YAML Files

### 7.1 File Structure

```
example-implementation-1-summit/
├── ansible/
│   ├── site.yml                          # Master playbook — full deployment
│   ├── inventory/
│   │   ├── hosts.yml                     # OpenShift cluster inventory
│   │   └── group_vars/
│   │       ├── all.yml                   # Global variables
│   │       └── openshift.yml             # OCP-specific vars
│   ├── roles/
│   │   ├── prerequisites/                # oc CLI, operators, namespace setup
│   │   ├── infra/                        # GitLab, Kafka, PostgreSQL, Vault, Keycloak
│   │   ├── dcm-control-plane/            # All DCM components
│   │   ├── dcm-providers/                # All provider deployments
│   │   └── dcm-demo-data/                # Seed data, sample policies, catalog items
│   └── README.md
├── openshift/
│   ├── namespaces/
│   │   ├── dcm-system.yaml
│   │   ├── dcm-providers.yaml
│   │   └── dcm-infra.yaml
│   ├── operators/
│   │   ├── amq-streams-subscription.yaml
│   │   ├── cert-manager-subscription.yaml
│   │   ├── external-secrets-subscription.yaml
│   │   └── crunchy-postgres-subscription.yaml
│   ├── infra/
│   │   ├── gitlab/
│   │   │   ├── gitlab-deployment.yaml
│   │   │   ├── gitlab-service.yaml
│   │   │   ├── gitlab-route.yaml
│   │   │   ├── gitlab-pvc.yaml
│   │   │   └── gitlab-configmap.yaml
│   │   ├── kafka/
│   │   │   ├── kafka-cluster.yaml        # AMQ Streams Kafka CR
│   │   │   └── kafka-topics.yaml         # DCM topic definitions
│   │   ├── postgresql/
│   │   │   ├── postgrescluster.yaml      # CrunchyData PGO CR
│   │   │   └── postgresql-init-job.yaml  # Schema init
│   │   ├── vault/
│   │   │   ├── vault-deployment.yaml
│   │   │   ├── vault-service.yaml
│   │   │   └── vault-init-job.yaml       # Vault init + unseal
│   │   └── keycloak/
│   │       ├── keycloak-deployment.yaml
│   │       ├── keycloak-service.yaml
│   │       ├── keycloak-route.yaml
│   │       └── keycloak-realm-configmap.yaml
│   ├── dcm-system/
│   │   ├── api-gateway/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── route.yaml
│   │   │   └── configmap.yaml
│   │   ├── request-orchestrator/
│   │   │   ├── deployment.yaml
│   │   │   └── configmap.yaml
│   │   ├── policy-engine/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── policies-configmap.yaml   # OPA Rego policies
│   │   ├── placement-engine/
│   │   │   ├── deployment.yaml
│   │   │   └── configmap.yaml
│   │   ├── audit-component/
│   │   │   ├── deployment.yaml
│   │   │   └── configmap.yaml
│   │   ├── cost-analysis/
│   │   │   ├── deployment.yaml
│   │   │   └── configmap.yaml
│   │   └── shared/
│   │       ├── network-policy.yaml       # Istio mTLS + NetworkPolicy
│   │       ├── peer-authentication.yaml  # Istio mTLS PeerAuthentication
│   │       ├── rbac.yaml                 # ServiceAccount + ClusterRoleBinding
│   │       └── external-secrets.yaml     # ExternalSecret CRs → Vault
│   ├── dcm-providers/
│   │   ├── vm-provider/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── configmap.yaml
│   │   │   └── registration-job.yaml     # Registers provider with DCM on deploy
│   │   ├── network-port-provider/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── configmap.yaml
│   │   ├── ocp-cluster-provider/         # ACM Shim
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── configmap.yaml
│   │   └── web-app-meta-provider/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       └── configmap.yaml
│   └── rhdh/
│       ├── rhdh-deployment.yaml
│       ├── rhdh-configmap.yaml           # app-config.yaml with DCM plugin config
│       └── rhdh-route.yaml
└── config/
    ├── dcm/
    │   ├── profiles/
    │   │   └── dev.yaml                  # Profile config for demo
    │   ├── policies/
    │   │   ├── sovereignty-gatekeeper.rego
    │   │   ├── tier-region-policy.rego    # Matches slide 17 exactly
    │   │   └── placement-preferences.rego
    │   ├── catalog-items/
    │   │   ├── vm-standard.yaml
    │   │   ├── ocp-cluster-standard.yaml
    │   │   ├── network-port-standard.yaml
    │   │   └── web-app-three-tier.yaml   # Meta Provider catalog item
    │   └── resource-types/
    │       ├── compute-virtualmachine.yaml
    │       ├── compute-ocpcluster.yaml
    │       └── network-port.yaml
    └── providers/
        ├── vm-provider-registration.yaml
        ├── network-port-provider-registration.yaml
        ├── ocp-cluster-provider-registration.yaml
        └── web-app-meta-provider-registration.yaml
```

### 7.2 Key Kubernetes Resources

**Kafka Topics (AMQ Streams):**
```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: dcm.requests.initiated
  namespace: dcm-infra
  labels:
    strimzi.io/cluster: dcm-kafka
spec:
  partitions: 6
  replicas: 3
  config:
    retention.ms: 604800000    # 7 days
    cleanup.policy: delete
---
# One topic per pipeline stage:
# dcm.requests.initiated
# dcm.requests.assembling
# dcm.requests.policy-evaluating
# dcm.requests.placing
# dcm.requests.dispatching
# dcm.requests.dispatched
# dcm.requests.completed
# dcm.requests.failed
# dcm.providers.callbacks
# dcm.audit.events
```

**Istio mTLS PeerAuthentication:**
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: dcm-mtls-strict
  namespace: dcm-system
spec:
  mtls:
    mode: STRICT    # All intra-namespace traffic must be mTLS
---
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: dcm-providers-mtls-strict
  namespace: dcm-providers
spec:
  mtls:
    mode: STRICT
```

**External Secrets (Vault → OpenShift Secrets):**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: dcm-db-secret
  namespace: dcm-system
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: dcm-db-secret
  data:
    - secretKey: url
      remoteRef:
        key: secret/dcm/postgresql
        property: connection_url
```

---

## 8. Configuration Files

### 8.1 DCM Dev Profile (config/dcm/profiles/dev.yaml)
```yaml
profile:
  name: dev
  version: "1.0.0"
  
rate_limiting:
  requests_per_minute: 120
  burst_max: 40

approval_thresholds:
  auto_approve_below: 40
  reviewed_above: 40
  verified_above: 70
  authorized_above: 90

credential:
  rotation_interval: P180D
  idle_detection_threshold: P14D
  revocation_cache_ttl: PT5M
  algorithm_mode: forbidden_list
  forbidden_algorithms: [MD5, SHA1, DES, 3DES, RC4]

audit:
  hash_chain_sweep_interval: P7D
  retention_minimum: P365D

shadow_mode:
  review_period: P7D
  auto_promote_on_zero_divergence: true

storage:
  intent_store:
    type: gitlab
    url: "${GITLAB_URL}"
    namespace: "dcm-intent"
  requested_store:
    type: gitlab
    url: "${GITLAB_URL}"
    namespace: "dcm-requested"
  snapshot_store:
    type: postgresql
    schema: realized_state
  audit_store:
    type: kafka
    topic_prefix: "dcm.audit"
  search_index:
    type: postgresql
    schema: search_index

placement:
  scoring_weights:
    sovereignty: 40
    capacity: 25
    cost: 15
    performance: 10
    availability: 10
  placement_cache_ttl: PT5M
```

### 8.2 Tier Region Policy (config/dcm/policies/tier-region-policy.rego)

This matches the policy shown on slide 17 of the roadmap deck exactly.

```rego
package dcm.gatekeeper.sovereignty

import future.keywords.every
import future.keywords.in

# enforcement_class: compliance
# This policy denies any request where the selected provider
# does not serve all sovereignty zones required by the request.
#
# Matches slide 17: "Tier Region Policy"

default allow := false

allow {
    count(deny_reasons) == 0
}

deny_reasons[msg] {
    # Sovereignty zones declared on the request (via Core Layer injection)
    required_zones := {z | z := input.request.assembled_fields.sovereignty_zones[_]}
    
    # Zones the selected provider serves
    provider_zones := {z | z := input.provider.sovereignty_zones[_]}
    
    # Every required zone must be in provider zones
    some zone in required_zones
    not zone in provider_zones
    
    msg := sprintf(
        "Sovereignty violation: provider '%v' does not serve zone '%v' (required by request %v)",
        [input.provider.handle, zone, input.request.resource_uuid]
    )
}

deny_reasons[msg] {
    # No extra zones — provider must not serve zones the request hasn't authorized
    # This prevents over-broad placement
    provider_zones := {z | z := input.provider.sovereignty_zones[_]}
    required_zones := {z | z := input.request.assembled_fields.sovereignty_zones[_]}
    
    some zone in provider_zones
    not zone in required_zones
    input.request.assembled_fields.strict_zone_match == true
    
    msg := sprintf(
        "Strict zone match: provider '%v' serves zone '%v' not authorized by request",
        [input.provider.handle, zone]
    )
}
```

### 8.3 Sample Catalog Item — VM Standard (config/dcm/catalog-items/vm-standard.yaml)
```yaml
catalog_item:
  uuid: "ci-vm-standard-001"
  handle: "vm-standard"
  display_name: "Virtual Machine — Standard"
  description: "General purpose virtual machine with policy-governed placement"
  resource_type: "Compute.VirtualMachine"
  version: "1.0.0"
  
  fields:
    cpu_cores:
      type: integer
      required: true
      constraint: {min: 1, max: 64}
      display_name: "vCPU count"
    
    ram_gb:
      type: integer
      required: true
      constraint: {min: 1, max: 512}
      display_name: "RAM (GB)"
    
    os_image:
      type: string
      required: true
      constraint:
        type: layer_reference
        layer_type: os_image_catalog
      display_name: "Operating System"
    
    sovereignty_zone:
      type: string
      required: true
      constraint:
        type: layer_reference
        layer_type: sovereignty_zone
      display_name: "Sovereignty Zone"
    
    environment:
      type: enum
      values: [dev, staging, prod]
      default: dev
      display_name: "Environment Tier"
  
  service_layers:
    - layer_type: location
      required: true
    - layer_type: network_zone
      required: true
    - layer_type: security_baseline
      required: false

  cost_estimate:
    basis: declared_static
    currency: USD
    monthly_estimate_per_vcpu: 12.50
    monthly_estimate_per_gb_ram: 2.00
```

---

## 9. Ansible Deployment Playbooks

### 9.1 Master Playbook (ansible/site.yml)
```yaml
---
- name: DCM Example Implementation #1 — Summit Demo
  hosts: localhost
  gather_facts: false
  
  vars_files:
    - inventory/group_vars/all.yml
    - inventory/group_vars/openshift.yml
  
  pre_tasks:
    - name: Verify OpenShift CLI available
      command: oc version
      register: oc_version
      failed_when: oc_version.rc != 0

    - name: Verify logged in to OpenShift
      command: oc whoami
      register: oc_user
      failed_when: oc_user.rc != 0

    - name: Display deployment target
      debug:
        msg: "Deploying DCM Summit Demo as {{ oc_user.stdout }} on {{ openshift_api_url }}"

  roles:
    - role: prerequisites        # Operators, namespaces, RBAC
    - role: infra                # GitLab, Kafka, PostgreSQL, Vault, Keycloak
    - role: dcm-control-plane   # All DCM system components
    - role: dcm-providers        # All provider deployments + registration
    - role: dcm-demo-data        # Seed: catalog items, policies, resource types, users

  post_tasks:
    - name: Wait for DCM API Gateway to be ready
      uri:
        url: "{{ dcm_api_url }}/livez"
        status_code: 200
      register: health_check
      retries: 30
      delay: 10
      until: health_check.status == 200

    - name: Display deployment summary
      debug:
        msg:
          - "DCM Summit Demo deployment complete"
          - "API Gateway: {{ dcm_api_url }}"
          - "RHDH: {{ rhdh_url }}"
          - "GitLab: {{ gitlab_url }}"
          - "Keycloak: {{ keycloak_url }}"
          - "Demo credentials: admin/{{ demo_admin_password }}"
```

### 9.2 Global Variables (ansible/inventory/group_vars/all.yml)
```yaml
---
# OpenShift cluster
openshift_api_url: "https://api.{{ cluster_domain }}:6443"
openshift_ingress_domain: "apps.{{ cluster_domain }}"

# Namespaces
dcm_namespace: dcm-system
dcm_providers_namespace: dcm-providers
dcm_infra_namespace: dcm-infra

# Component URLs (constructed from ingress domain)
dcm_api_url: "https://dcm-api.{{ openshift_ingress_domain }}"
rhdh_url: "https://rhdh.{{ openshift_ingress_domain }}"
gitlab_url: "https://gitlab.{{ openshift_ingress_domain }}"
keycloak_url: "https://keycloak.{{ openshift_ingress_domain }}"
vault_url: "https://vault.{{ openshift_ingress_domain }}"
kafka_bootstrap: "dcm-kafka-bootstrap.{{ dcm_infra_namespace }}.svc:9092"

# DCM configuration
dcm_profile: dev
dcm_version: "0.1.0-summit"
dcm_image_registry: "quay.io/dcm-project"

# Demo configuration
demo_admin_password: "{{ lookup('password', '/dev/null length=24 chars=ascii_letters,digits') }}"
demo_sovereignty_zones:
  - EU-WEST
  - US-EAST
  - US-GOV

# AAP configuration
aap_url: "{{ vault_lookup('secret/dcm/aap/url') | default('https://aap.example.com') }}"

# GitLab configuration
gitlab_root_token: "{{ vault_lookup('secret/dcm/gitlab/root-token') }}"
gitlab_dcm_group: "dcm"
```

### 9.3 Infrastructure Role — Kafka (ansible/roles/infra/tasks/kafka.yml)
```yaml
---
- name: Create Kafka cluster for DCM
  kubernetes.core.k8s:
    state: present
    definition:
      apiVersion: kafka.strimzi.io/v1beta2
      kind: Kafka
      metadata:
        name: dcm-kafka
        namespace: "{{ dcm_infra_namespace }}"
      spec:
        kafka:
          version: 3.7.0
          replicas: 3
          listeners:
            - name: plain
              port: 9092
              type: internal
              tls: false
            - name: tls
              port: 9093
              type: internal
              tls: true
          config:
            offsets.topic.replication.factor: 3
            transaction.state.log.replication.factor: 3
            transaction.state.log.min.isr: 2
            default.replication.factor: 3
            min.insync.replicas: 2
          storage:
            type: persistent-claim
            size: 20Gi
            class: standard
        zookeeper:
          replicas: 3
          storage:
            type: persistent-claim
            size: 5Gi
            class: standard
        entityOperator:
          topicOperator: {}
          userOperator: {}

- name: Create DCM Kafka topics
  kubernetes.core.k8s:
    state: present
    definition: "{{ lookup('template', 'kafka-topics.yaml.j2') }}"

- name: Wait for Kafka cluster to be ready
  kubernetes.core.k8s_info:
    api_version: kafka.strimzi.io/v1beta2
    kind: Kafka
    name: dcm-kafka
    namespace: "{{ dcm_infra_namespace }}"
  register: kafka_status
  until: >
    kafka_status.resources[0].status.conditions |
    selectattr('type', 'equalto', 'Ready') |
    selectattr('status', 'equalto', 'True') | list | length > 0
  retries: 30
  delay: 20
```

### 9.4 Provider Registration Task (ansible/roles/dcm-providers/tasks/register.yml)
```yaml
---
# Run after all providers are deployed and healthy
# Registers each provider with the DCM control plane via the Admin API

- name: Get DCM admin token from Keycloak
  uri:
    url: "{{ keycloak_url }}/realms/dcm/protocol/openid-connect/token"
    method: POST
    body_format: form-urlencoded
    body:
      grant_type: client_credentials
      client_id: dcm-admin
      client_secret: "{{ dcm_admin_client_secret }}"
    return_content: true
  register: admin_token_response

- name: Set admin token fact
  set_fact:
    dcm_admin_token: "{{ (admin_token_response.content | from_json).access_token }}"

- name: Register VM Service Provider
  uri:
    url: "{{ dcm_api_url }}/api/v1/admin/providers"
    method: POST
    headers:
      Authorization: "Bearer {{ dcm_admin_token }}"
      Content-Type: "application/json"
    body: "{{ lookup('template', 'vm-provider-registration.json.j2') }}"
    body_format: json
    status_code: [200, 201, 409]  # 409 = already registered
  register: vm_provider_reg

- name: Register Network Port Provider
  uri:
    url: "{{ dcm_api_url }}/api/v1/admin/providers"
    method: POST
    headers:
      Authorization: "Bearer {{ dcm_admin_token }}"
      Content-Type: "application/json"
    body: "{{ lookup('template', 'network-port-provider-registration.json.j2') }}"
    body_format: json
    status_code: [200, 201, 409]

- name: Register OCP Cluster Provider (ACM Shim)
  uri:
    url: "{{ dcm_api_url }}/api/v1/admin/providers"
    method: POST
    headers:
      Authorization: "Bearer {{ dcm_admin_token }}"
      Content-Type: "application/json"
    body: "{{ lookup('template', 'ocp-cluster-provider-registration.json.j2') }}"
    body_format: json
    status_code: [200, 201, 409]

- name: Approve all pending providers
  include_tasks: approve-provider.yml
  loop: "{{ ['vm-provider', 'network-port-provider', 'ocp-cluster-provider', 'web-app-meta-provider'] }}"
  loop_var: provider_handle
```

---

## 10. Implementation Notes and Portability

### 10.1 Provider Portability

Every provider in this implementation is replaceable without changes to the DCM control plane. The interface is the Operator Interface Specification. A VMware vSphere VM provider, an OpenStack Nova provider, or a bare metal Redfish provider all implement the same contract. To replace the AAP-based VM provider with a Terraform-based provider: implement the same OIS endpoints, register with DCM, deregister the old provider. The DCM data model, policy engine, and placement logic are unchanged.

### 10.2 ACM Shim Upgrade Path

The ACM shim registers as a normal Service Provider. When a proper ACM provider is built, it registers alongside the shim with different capability declarations. The Placement Engine routes requests to the appropriate provider based on resource type and capability matching. No DCM core changes are required.

### 10.3 What Changes vs What Doesn't

**Does not change when providers are replaced:**
- Data model (entity schemas, four states, layering)
- Policy evaluation (OPA policies evaluate request data, not provider internals)
- API contracts (all 132 endpoints)
- Audit trail (hash chain, provenance)
- Placement engine (scores eligible providers, doesn't care what they are)

**Changes when providers are replaced:**
- Naturalization (DCM model → native tool format)
- Denaturalization (native tool response → DCM model)
- Provider-specific Ansible playbooks / Terraform modules
- Provider registration YAML (declares what the new provider offers)

---

## 11. Demo Data — Seed State

On deployment, the `dcm-demo-data` Ansible role seeds the following:

**Tenants:** `payments-bu`, `platform-team`  
**Demo users:** `alice@demo.local` (Consumer), `bob@demo.local` (Platform Admin)  
**Resource types:** `Compute.VirtualMachine`, `Compute.OCPCluster`, `Network.Port`, `WebApp.ThreeTier`  
**Catalog items:** VM Standard, OCP Cluster Standard, Network Port Standard, Web App Three-Tier  
**Core Layers:** EU-WEST location layer, US-EAST location layer, PROD network zone layer  
**Providers:** VM Provider (EU-WEST), Network Port Provider, OCP Cluster Provider (ACM Shim)  
**Sample policies:** Tier Region Policy (sovereignty GateKeeper), Placement Preference Policy  
**Demo scenario scripts:** `demo-1-intelligent-placement.sh`, `demo-2-rehydration.sh`, `demo-3-app-as-a-service.sh`

---

*This is Example Implementation #1. It demonstrates one way to implement the DCM architecture for the Summit 2026 use cases. It is not the normative DCM architecture — see [00-foundations.md](../data-model/00-foundations.md) for the authoritative architecture.*
