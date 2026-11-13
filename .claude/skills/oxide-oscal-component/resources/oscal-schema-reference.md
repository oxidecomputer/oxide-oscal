# OSCAL Component Definition — Authoring Reference

Scoped to the component definition model only, OSCAL v1.2.3, YAML format.
This is a semantic authoring guide, not a schema definition. For formal
validation use `scripts/validate.sh`.

---

## Document-Level Rules

- Every time content changes, two fields must be updated together:
  - `uuid` on the root `component-definition` element — generate a new UUID
  - `metadata.last-modified` — set to the current datetime
- Failing to update both breaks tool-based change detection
- Format and content of a document are equivalent — converting between YAML,
  JSON, and XML must not change these values

---

## metadata

Required fields:
```yaml
metadata:
  title:          # Human-readable document title
  last-modified:  # ISO 8601 datetime, updated on every change
  version:        # Document version string (your scheme, e.g. "1.0.0")
      oscal-version:  # Must match the OSCAL release, e.g. "1.2.3"
```

`roles`, `parties`, and `responsible-parties` are defined here and referenced
by ID or UUID throughout the rest of the document. See `parties-roles.md` for
the stable definitions for this document.

---

## components

A component represents a discrete, deployable thing that satisfies controls.
The Oxide Cloud Computer is modeled as a single component. Do not add
additional top-level components.

Required fields on a component:
```yaml
- uuid:          # Stable UUID, generated once, never changed
  type:          # See component types below
  title:         # Short human-readable name
  description:   # Normative statement of what the component is and does
```

Optional but expected:
```yaml
  props:         # Key-value metadata, see props below
  links:         # References to external resources
  responsible-roles:  # Who is responsible for this component
  control-implementations:  # The control coverage blocks
```

### Component Types

| type | Use when |
|---|---|
| `hardware` | Physical device or rack system |
| `software` | Application, OS, or firmware |
| `service` | Hosted or managed service |
| `policy` | A documented policy |
| `process` | An operational process or procedure |
| `validation` | A compliance validation artifact (e.g. FIPS 140-2) |
| `interconnection` | A system interconnection |

The Oxide Cloud Computer uses `hardware` as its component type, reflecting
the rack-scale system as the primary unit of deployment.

---

## description vs remarks

This distinction is the most commonly misapplied in component definitions.

**`description`** — normative, machine-relevant content
- Must be sufficient for an assessor to evaluate the control without
  reading `remarks`
- Gets imported into SSPs as the starting narrative
- Tools render and process this field
- Should not contain caveats, authoring notes, or conditional language

**`remarks`** — editorial, human-relevant content
- Caveats, context, and explanation that aid interpretation
- Customer obligation statements for partial controls
- Notes to SSP authors about what they must document
- Authoring decisions that would otherwise be opaque
- Must not contain information that belongs in a formal field
- Tools may ignore this field entirely

A reliable test: if removing `remarks` would prevent an assessor from
determining whether the control is met, that content belongs in `description`.

---

## control-implementations

Groups implemented-requirements by baseline. Each block targets one source
profile. The Oxide component definition has one block per baseline.

Required fields:
```yaml
control-implementations:
  - uuid:          # Stable UUID for this block
    source:        # URI of the OSCAL profile this block implements against
    description:   # Brief statement of what baseline this block covers
    implemented-requirements:
      - ...
```

The `source` field is a dereferenceable identifier for downstream tools, not
a runtime fetch. It must reference the canonical OSCAL profile URI for the
target baseline, not the catalog. See the relevant file in
`resources/control-narratives/` for the correct URI per baseline.

---

## implemented-requirements

One entry per control. The core authoring unit of the component definition.

Required fields:
```yaml
- uuid:          # Stable UUID, generated once, never changed
  control-id:   # Exact control identifier from the source profile
                # e.g. "ac-2", "si-7", "sc-28.1" for enhancements
  description:  # How this component implements this control (normative)
```

Expected fields:
```yaml
  props:               # Must include implementation-status (see below)
  responsible-roles:   # Who is responsible — Oxide only in this document
  remarks:             # Customer obligations, caveats, SSP author guidance
```

### control-id Format

- Base controls: lowercase with hyphen — `ac-2`, `si-7`
- Control enhancements: base control plus dot-number — `ac-2.1`, `si-7.7`
- Match the exact identifier used in the source profile; do not invent IDs

---

## props

Key-value pairs that carry structured metadata. The most important prop in
implemented-requirements is `implementation-status`.

```yaml
props:
  - name: implementation-status
    ns: https://fedramp.gov/ns/oscal
    value: implemented   # See vocabulary below
```

The `ns` field scopes the prop to a namespace. Always use the FedRAMP
namespace for `implementation-status` — it is the de facto standard for
this field even outside formal FedRAMP submissions.

### implementation-status Vocabulary

| value | Meaning |
|---|---|
| `implemented` | Oxide fully implements this control; no customer action needed |
| `partial` | Oxide provides the mechanism; customer must configure or operate it |
| `planned` | Implementation is not yet complete; planned for a future release |
| `alternative` | Control is satisfied through a compensating approach |
| `not-applicable` | Control does not apply to this component; reason in `remarks` |

Every implemented-requirement must carry exactly one `implementation-status`
prop. Do not omit it.

---

## responsible-roles

Associates a role with the party responsible at the level of a specific
element. In this document, only Oxide parties are referenced.

```yaml
responsible-roles:
  - role-id: component-provider
    party-uuids:
      - 1fd0ef7d-e65f-483c-8ce0-f6d99eb6516e
```

### responsible-roles vs responsible-parties

These are frequently confused:

| field | Where used | Requires party-uuid |
|---|---|---|
| `responsible-parties` | `metadata` only — document-level role mapping | Yes |
| `responsible-roles` | Within components and implemented-requirements | No (but expected) |

`responsible-roles` allows zero party-uuid references (the role is declared
but unassigned). `responsible-parties` requires at least one. In this
document, always include the Oxide party UUID in `responsible-roles`.

---

## links

References to external resources. Use `rel` to describe the relationship.

Common `rel` values for component definitions:

| rel | Use |
|---|---|
| `reference` | Supporting documentation or source material |
| `agreement` | A formal agreement governing the component |
| `policy` | A policy document relevant to the component |

```yaml
links:
  - href: https://oxide.computer/solutions/public-sector
    rel: reference
    text: Oxide Public Sector Solutions Overview
```

---

## back-matter

Collects resources referenced by `links` elsewhere in the document, and any
reference material useful to downstream consumers of the component definition.
If a link target is cited in multiple places, define it once in `back-matter`
and reference it by UUID using the `#` fragment syntax.

For this component definition, `back-matter` should include:

- **The SP 800-53 Rev 5 catalog** — allows assessors to resolve control
  definitions without an external lookup
- **Each targeted baseline profile** — documents the specific controls and
  parameters that were in scope for each `control-implementations` block
- **Oxide public documentation** — source material backing control narratives

These are distinct roles. The catalog is for control definition resolution.
The profiles document scope. Oxide documentation supports evidence traceability.
All three belong in `back-matter` even though only the profile URIs appear in
`source` fields.

```yaml
back-matter:
  resources:
    - uuid: 6bd2086f-e3e8-4a14-9149-955b053a24eb
        title:
          Electronic (OSCAL) Version of NIST SP 800-53 Rev 5.2.0 Controls and SP
          800-53A Rev 5.2.0 Assessment Procedures
        description: >-
          NIST Special Publication 800-53 Revision 5 Security and Privacy
          Controls for Information Systems and Organizations
        rlinks:
          - href: https://raw.githubusercontent.com/usnistgov/oscal-content/refs/tags/v1.4.0/nist.gov/SP800-53/rev5/xml/NIST_SP-800-53_rev5_catalog.xml
            media-type: application/oscal.catalog+xml
          - href: https://raw.githubusercontent.com/usnistgov/oscal-content/refs/tags/v1.4.0/nist.gov/SP800-53/rev5/json/NIST_SP-800-53_rev5_catalog.json
            media-type: application/oscal.catalog+json
          - href: https://raw.githubusercontent.com/usnistgov/oscal-content/refs/tags/v1.4.0/nist.gov/SP800-53/rev5/yaml/NIST_SP-800-53_rev5_catalog.yaml
            media-type: application/oscal.catalog+yaml
    - uuid: 14d870ab-b473-4830-aa8f-a5c4743769c8
      title: NIST SP 800-53B High Baseline Profile
      rlinks:
        - href: https://raw.githubusercontent.com/usnistgov/oscal-content/main/nist.gov/SP800-53/rev5/json/NIST_SP-800-53_rev5-HIGH-baseline_profile.json
    - uuid: 243cec01-cad1-4760-848c-daa6a62b6496
      title: Oxide Public Sector Solutions Overview
      rlinks:
        - href: https://oxide.computer/solutions/public-sector
```

Referencing from a link elsewhere in the document:
```yaml
links:
  - href: '#6bd2086f-e3e8-4a14-9149-955b053a24eb'
    rel: reference
```

---

## UUID Hygiene

- Generate all UUIDs using `scripts/generate-uuid.sh` — never construct manually
- Each element gets one UUID assigned at creation; it never changes
- The document-level UUID on `component-definition` is the only UUID that
  changes — it gets a new value on every content update
- UUIDs are case-insensitive in the spec but use lowercase consistently