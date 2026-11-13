# Parties and Roles — Oxide OSCAL Component Definition

This component definition is authored by Oxide Computer Company as the
component provider. There is no customer party in this document — customer
organizations will reference this component definition from their own SSPs
and document their party information there.

These are the UUID-stable party and role definitions for this document.
Always use these exact UUIDs. Never generate new UUIDs for these entries.
Run `generate-uuid.sh` only for new elements not already defined here.

---

## Roles

```yaml
- id: component-provider
  title: Component Provider
  description: >-
    The organization that designs, manufactures, and maintains the Oxide
    Cloud Computer hardware and software.
- id: creator
  title: Document Creator
  description: >-
    The Oxide team or group responsible for authoring and maintaining this
    OSCAL component definition document.
- id: contact
  title: Point of Contact
  description: >-
    The Oxide individual or team to contact with questions about the content
    of this OSCAL component definition document.
```

---

## Parties

### Oxide Computer Company (Component Provider)

```yaml
- uuid: 1fd0ef7d-e65f-483c-8ce0-f6d99eb6516e
  type: organization
  name: Oxide Computer Company
  short-name: Oxide
  links:
    - href: https://oxide.computer
      rel: website
```

**This UUID must not change.** It is referenced by `party-uuids` throughout
all `responsible-roles` entries in the document.


### Point of Contact (Oxide Security Team)

```yaml
- uuid: a182ded0-c5b0-4f37-b476-02b391327ce7
  type: organization
  name: Oxide Computer Company Security Team
  email-addresses:
    - security@oxidecomputer.com
  member-of-organizations:
    - 1fd0ef7d-e65f-483c-8ce0-f6d99eb6516e
```

The contact is a team within Oxide, not a named individual.
`member-of-organizations` links it to the Oxide party entry. Keep this UUID
stable if the team name or address changes: update the name and email in
place rather than issuing a new UUID.

---

## Responsible Parties (Metadata Level)

```yaml
- role-id: component-provider
  party-uuids:
    - 1fd0ef7d-e65f-483c-8ce0-f6d99eb6516e
- role-id: creator
  party-uuids:
    - a182ded0-c5b0-4f37-b476-02b391327ce7
- role-id: contact
  party-uuids:
    - a182ded0-c5b0-4f37-b476-02b391327ce7
```

---

## Usage in implemented-requirements

All `responsible-roles` entries reference Oxide parties only. Customer
obligations are never expressed through a party reference in this document —
they are documented in `remarks` instead.

### Fully provider-implemented control

```yaml
responsible-roles:
  - role-id: component-provider
    party-uuids:
      - 1fd0ef7d-e65f-483c-8ce0-f6d99eb6516e
```

### Control with customer obligations

Use `implementation-status: partial` and document the customer obligation
in `remarks`. Do not add a customer party reference.

```yaml
props:
  - name: implementation-status
    ns: https://fedramp.gov/ns/oscal
    value: partial
responsible-roles:
  - role-id: component-provider
    party-uuids:
      - 1fd0ef7d-e65f-483c-8ce0-f6d99eb6516e
```

```
remarks: >-
  Oxide provides [mechanism]. The customer is responsible for
  [specific obligations] when deploying this component. Customer-side
  responsibilities must be documented in the system SSP.
```

### Not applicable to this component

```yaml
props:
  - name: implementation-status
    ns: https://fedramp.gov/ns/oscal
    value: not-applicable
responsible-roles:
  - role-id: component-provider
    party-uuids:
      - 1fd0ef7d-e65f-483c-8ce0-f6d99eb6516e
```

---

## Version History

| Oxide Party UUID | Contact UUID | Since |
|---|---|---|
| 1fd0ef7d-e65f-483c-8ce0-f6d99eb6516e | a182ded0-c5b0-4f37-b476-02b391327ce7 | Initial |

Add a row only if a party UUID is ever replaced. UUIDs must
remain stable across versions — only the document-level UUID and
`last-modified` change on update.