# DCM Normative Data Specifications

**Status:** Draft — Ready for implementation feedback
**Version:** 1.0.0
**GitHub:** https://github.com/dcm-project

These are the machine-readable normative specifications for the DCM data model. They are the
code-generation layer — SDK authors, server stub generators, and validation middleware should
use these files, not the narrative documentation in `data-model/`.

The narrative documentation remains authoritative for intent and rationale. These schemas are
authoritative for field names, types, constraints, and API shapes.

---

## Files

### JSON Schema (entity, policy, provider, and event data shapes)

| File | Describes | Types | Source docs |
|------|-----------|-------|-------------|
| `dcm-common.json` | Shared primitive types reused across all schemas | 17 | `00-foundations.md`, `16-universal-audit.md` |
| `entities/dcm-entities.json` | All three entity types (Infrastructure Resource, Composite Resource, Process Resource) | 18 | `01-entity-types.md` |
| `policies/dcm-policies.json` | All seven policy types and their output schemas | 31 | `B-policy-contract.md`, `14-policy-profiles.md` |
| `providers/dcm-providers.json` | Provider base contract and all 11 capability extensions | 19 | `A-provider-contract.md`, `dcm-registration-spec.md` |
| `events/dcm-events.json` | Base event envelope + all 82 event-specific payload schemas | 75 | `33-event-catalog.md` |
| `resource-types/resource-type-spec-template.json` | Resource Type Spec schema + authoring guide + Compute.VirtualMachine example | 3 | `05-resource-type-hierarchy.md`, `20-registry-governance.md` |

### OpenAPI 3.1 (API shapes)

| File | Describes | Paths | Schemas | Source docs |
|------|-----------|-------|---------|-------------|
| `openapi/dcm-consumer-api.yaml` | Consumer API — application teams and Tenant owners | 59 | 31 | `consumer-api-spec.md` |
| `openapi/dcm-admin-api.yaml` | Admin API — platform engineers and SREs | 41 | 19 | `dcm-admin-api-spec.md` |
| `openapi/dcm-operator-api.yaml` | Operator Interface Services API — provider-facing (DCM is client) | 5 | 12 | `dcm-operator-interface-spec.md` |
| `openapi/dcm-provider-callback-api.yaml` | Provider Callback API — endpoints DCM exposes for operators to call (registration, realized state push, interim status, update notifications, lifecycle events) | 7 | 11 | `dcm-operator-interface-spec.md` |

## AEP Alignment

The OpenAPI specifications follow [AEP (API Enhancement Proposals)](https://aep.dev) conventions
in three areas:

**1. Custom methods (AEP-136)** — Actions on resources use colon syntax rather than slash-separated
verb paths. For example: `POST /resources/{name}:suspend` rather than `POST /resources/{name}/suspend`.
This applies to all state-transition and action operations across the Consumer and Admin APIs.

**2. Long-Running Operations (AEP-151)** — Async operations that produce a trackable result return
an `Operation` resource with a stable `name` field (poll URL), a `done` boolean, and either a
`response` or `error` field when complete. Operations that are genuinely fire-and-forget (capacity
reports, interim status, lifecycle events) retain `202 Accepted` without an Operation body.

**3. Pagination (AEP-158)** — List endpoints use `page_size` and `page_token` query parameters.
Responses include a `next_page_token` field (empty string when no further pages exist).

**What was deliberately not aligned:**

- **Resource names** — DCM retains UUIDs as the primary identifier. AEP's hierarchical
  `name` strings (`tenants/{t}/resources/{r}`) are not used because DCM's UUID immutability
  guarantee across ownership transfers and provider migrations is more architecturally
  significant than AEP naming convention compliance.
- **Timestamp field names** — `created_at`/`updated_at` are retained in API responses rather
  than `create_time`/`update_time`. Renaming these would require a data model change (the fields
  exist in the entity schemas and Realized State records) with no functional benefit.


---

## Schema Design Principles

**1. `$ref` over duplication.** Types defined in `dcm-common.json` are referenced by `$ref` from
all other schemas. The common types — uuid, handle, semver, iso8601_datetime, artifact_metadata,
sovereignty_declaration — are defined once.

**2. Discriminated unions via `entity_type` / `policy_type`.** The `dcm_entity` and `dcm_policy`
union types use the `entity_type` and `policy_type` fields as discriminators. Validation tools
that support OpenAPI 3.1 discriminators can route to the correct sub-schema automatically.

**3. `additionalProperties: false` on all closed shapes.** Entities and provider registrations
use `additionalProperties: false` where the shape is fully known. Resource-type-specific fields
(which vary by resource type) use `additionalProperties: true` on the `fields` object only.

**4. Field-level provenance as a pattern.** The `field_provenance` type in `dcm-common.json`
documents the provenance metadata that any data field may carry as a sibling `_provenance` key.
This is a pattern, not enforced by schema (because JSON Schema cannot express "every field may
have a sibling `_fieldname_provenance` key" without enumeration).

**5. ISO 8601 throughout.** All datetime fields use `format: date-time`. All duration fields use
`format: iso8601_duration` with the pattern `P...`. All country codes use `pattern: [A-Z]{2}`.

**6. Closed vocabularies as enums.** All closed vocabularies from the narrative documentation
are expressed as `enum` arrays. The closed vocabulary for payload_type (policy match conditions),
lifecycle states, ownership models, provider types, and credential types are all enumerated.

---

## Usage

### Validation (Python)

```python
import json
import jsonschema
from pathlib import Path

schema_dir = Path("dcm-docs/schemas")

# Load schemas
common = json.loads((schema_dir / "dcm-common.json").read_text())
entities = json.loads((schema_dir / "entities/dcm-entities.json").read_text())

# Build a resolver that handles $ref across files
store = {
    "https://dcm-project.io/schemas/common/v1": common,
    "https://dcm-project.io/schemas/entities/v1": entities,
}
resolver = jsonschema.RefResolver.from_schema(entities, store=store)

# Validate an entity
entity = { ... }
jsonschema.validate(entity, entities, resolver=resolver)
```

### Validation (Go)

```go
import (
    "github.com/santhosh-tekuri/jsonschema/v5"
    _ "github.com/santhosh-tekuri/jsonschema/v5/httploader"
)

compiler := jsonschema.NewCompiler()
compiler.AddResource("dcm-common.json", openFile("schemas/dcm-common.json"))
compiler.AddResource("entities/dcm-entities.json", openFile("schemas/entities/dcm-entities.json"))

schema, err := compiler.Compile("entities/dcm-entities.json")
if err != nil { panic(err) }

var entity interface{}
json.Unmarshal(data, &entity)
if err := schema.Validate(entity); err != nil {
    fmt.Println(err)
}
```

### OpenAPI Code Generation

```bash
# Generate Go server stubs from Consumer API
oapi-codegen -package api -generate server,types \
  schemas/openapi/dcm-consumer-api.yaml > pkg/api/consumer.gen.go

# Generate Python client from Admin API
openapi-python-client generate \
  --path schemas/openapi/dcm-admin-api.yaml \
  --output dcm-admin-client/

# Generate TypeScript types
openapi-typescript schemas/openapi/dcm-consumer-api.yaml \
  --output src/types/dcm-consumer-api.ts
```

---

## What Is Not Yet Here

### Resource Type Field Schemas (per resource type)

The `resource-types/resource-type-spec-template.json` defines the schema for the Resource Type Spec envelope and provides a worked `Compute.VirtualMachine` example. Individual resource type field schemas are owned by Service Providers and published to the Resource Type Registry — DCM does not define them centrally. Service Providers should use the template and authoring guide to produce their own schemas.

### Resource Type Field Schemas (per resource type)

The `resource-types/resource-type-spec-template.json` defines the schema for the Resource Type Spec envelope and includes a complete `Compute.VirtualMachine` worked example. Individual resource type field schemas are owned by Service Providers and published to the Resource Type Registry per the template authoring guide.

---

*Document maintained by the DCM Project. For questions or contributions see [GitHub](https://github.com/dcm-project).*
