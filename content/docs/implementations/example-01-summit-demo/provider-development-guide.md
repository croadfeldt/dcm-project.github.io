---
title: "Provider Development Guide"
type: docs
---

# Provider Development Guide

How to build a new DCM Service Provider compatible with this implementation.

---

## Overview

A DCM Service Provider is a containerized Go (or any language) service that:
1. Implements the DCM Operator Interface Specification (OIS)
2. Registers with the DCM API Gateway on startup
3. Receives `CreateRequest` payloads and executes them against a target system
4. Sends status callbacks to the DCM API Gateway

This guide follows the DCM spec for provider development.
Spec references: doc A (Provider Contract), dcm-operator-interface-spec.md, dcm-operator-sdk-api.md

---

## OIS Conformance Levels

| Level | Required Endpoints | Unlocks |
|-------|-------------------|---------|
| **Level 1** | POST /api/v1/resources, GET /health, GET /capabilities, callback on completion | Basic provisioning, decommission, capability introspection |
| **Level 2** | + GET /discover, GET /capacity, PATCH /api/v1/resources/{id} | Discovery, drift detection, updates |
| **Level 3** | + PUT /api/v1/resources/{id}:bulk-import | Brownfield ingestion |

Start with Level 1, add Level 2 for drift detection capability.

**`GET /capabilities`** returns the provider's available options — networks, storage classes, images, regions, or any domain-specific resources the consumer can reference in requests. The Policy Engine's Transformation policies query this endpoint during assembly to validate and enrich consumer input. Without it, policies would need to hardcode provider-specific values.

---

## Provider Registration

On startup, your provider must register with DCM:

```go
// Registration payload (doc A §3.1)
registration := map[string]interface{}{
    "display_name":    "My Custom Provider",
    "provider_type":   "service_provider",
    "endpoint":        "http://my-provider-service:8080",
    "public_key_pem":  loadMTLSCert(),   // Your pod's service mesh certificate
    "capabilities": map[string]interface{}{
        "supported_resource_types": []string{"Compute.VirtualMachine"},
        "ois_conformance_level": 1,
        "discovery_supported": false,
        "rehydration_supported": true,
    },
    "sovereignty_declarations": []string{"us-east-1", "us-east-2"},
}

resp, err := http.Post(
    os.Getenv("DCM_API_GATEWAY_URL") + "/api/v1/admin/providers",
    "application/json",
    jsonBody(registration),
)
// Store the returned provider_uuid
```

---

## Receiving a CreateRequest

DCM calls your provider when a request is dispatched:

```go
// POST /api/v1/resources
// Spec ref: dcm-operator-interface-spec.md §3.1
type CreateRequest struct {
    RequestUUID    string                 `json:"request_uuid"`     // == operation_uuid
    EntityUUID     string                 `json:"entity_uuid"`      // Stable entity identifier
    ResourceType   string                 `json:"resource_type"`    // e.g. "Compute.VirtualMachine"
    Fields         map[string]interface{} `json:"fields"`           // Fully assembled payload
    Provenance     map[string]interface{} `json:"provenance"`       // Field lineage
    TenantUUID     string                 `json:"tenant_uuid"`
    RequestedAt    string                 `json:"requested_at"`
}

// Your handler:
func (p *Provider) HandleCreateRequest(w http.ResponseWriter, r *http.Request) {
    var req CreateRequest
    json.NewDecoder(r.Body).Decode(&req)

    // 1. Return 200 immediately (LRO pattern — do not block)
    w.WriteHeader(http.StatusOK)
    json.NewEncoder(w).Encode(map[string]string{
        "status": "PROVISIONING",
        "message": "Request accepted",
    })

    // 2. Process asynchronously
    go p.provision(req)
}
```

---

## Sending Status Callbacks

When your provisioning completes, callback to DCM:

```go
// Spec ref: dcm-provider-callback-api.yaml, doc 43 (Provider Callback Authentication)
func (p *Provider) sendCallback(entityUUID string, success bool, result map[string]interface{}) {
    payload := map[string]interface{}{
        "dcm_entity_uuid":  entityUUID,
        "provider_entity_id": result["native_id"],   // Your system's ID
        "lifecycle_state":  "OPERATIONAL",           // or "FAILED"
        "realized_fields":  result,
        "realized_at":      time.Now().UTC().Format(time.RFC3339),
    }

    req, _ := http.NewRequest("POST",
        os.Getenv("DCM_API_GATEWAY_URL") + "/api/v1/provider/entities/" + entityUUID + "/status",
        jsonBody(payload))

    // Authenticate callback with your provider callback credential
    // This credential was issued by DCM Vault at registration (doc 43, doc 49 §7.1)
    req.Header.Set("Authorization", "Bearer " + os.Getenv("DCM_CALLBACK_TOKEN"))
    req.Header.Set("Content-Type", "application/json")

    http.DefaultClient.Do(req)
}
```

---

## Naturalization and Denaturalization

Your provider translates between DCM's unified model and your native system:

```go
// NATURALIZATION: DCM VirtualMachine → AAP Job parameters
func naturalizeToAAP(fields map[string]interface{}) map[string]interface{} {
    return map[string]interface{}{
        "extra_vars": map[string]interface{}{
            "vm_name":       fields["name"],
            "vm_cpu":        fields["cpu"],
            "vm_memory_mb":  fields["ram_gb"].(int) * 1024,
            "vm_disk_gb":    fields["storage_gb"],
            "vcenter_url":   fields["vcenter_url"],    // Injected by Core Layer
            "datastore":     fields["datastore"],      // Injected by Core Layer
            "template":      fields["os_image_path"],  // Injected by OS Image Layer
        },
    }
}

// DENATURALIZATION: AAP result → DCM VirtualMachine realized state
func denaturalizeFromAAP(aapResult map[string]interface{}) map[string]interface{} {
    artifacts := aapResult["artifacts"].(map[string]interface{})
    return map[string]interface{}{
        "ip_address":     artifacts["vm_ip"],
        "hostname":       artifacts["vm_hostname"],
        "vcenter_vm_id":  artifacts["vm_moref"],
        "power_state":    "on",
        "os_version":     artifacts["os_version"],
    }
}
```

---

## OpenShift Deployment Pattern

Use the `dcm-provider-vm` deployment as your template:
1. Copy `openshift/providers/vm-provider/deployment.yaml`
2. Update: `name`, `dcm.io/resource-type`, `provider_uuid`, `image`
3. Add Vault init container if your provider needs external credentials
4. Register resource type in `capabilities.supported_resource_types`

The service mesh handles mTLS automatically — no TLS code needed in your provider.
