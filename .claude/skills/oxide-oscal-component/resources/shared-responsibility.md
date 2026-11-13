# Shared Responsibility Patterns - Oxide OSCAL Component Definition

This document is authored by Oxide as the component provider. There is no
customer party. Customer obligations are never expressed through a party
reference or `responsible-roles` entry. They are documented exclusively in
`remarks`, with `implementation-status: partial` signaling to SSP authors
that they have work to do.

This file assigns responsibilities. It is not a fact source. Facts come
from `oxide-architecture.md`; each pattern names the sections to read, by
heading. If a pattern and the fact base disagree, the fact base wins.

---

## Responsibility Categories

### Provider-Implemented (Oxide)
Oxide designs and builds the mechanism, it operates without customer
configuration, and the fact base records no gap that the customer must
cover for this control aspect.

```yaml
responsible-roles:
  - role-id: component-provider
    party-uuids:
      - 1fd0ef7d-e65f-483c-8ce0-f6d99eb6516e
props:
  - name: implementation-status
    ns: https://fedramp.gov/ns/oscal
    value: implemented
```

No `remarks` entry is required for fully provider-implemented controls
unless there is an authoring note or known limitation worth flagging.

---

### Control with Customer Obligations
Oxide provides the mechanism or capability; the customer must configure,
operate, or supplement it. Use this category also when the mechanism covers
only part of the control's scope or has a gap listed in the fact base.
`responsible-roles` references only Oxide. `implementation-status` is
`partial`. The customer obligation is documented entirely in `remarks`.

```yaml
responsible-roles:
  - role-id: component-provider
    party-uuids:
      - 1fd0ef7d-e65f-483c-8ce0-f6d99eb6516e
props:
  - name: implementation-status
    ns: https://fedramp.gov/ns/oscal
    value: partial
remarks: >-
  Oxide provides [mechanism]. The customer is responsible for [specific
  obligations] when deploying this component. Customer-side responsibilities
  must be documented in the system SSP.
```

---

### Not Applicable to This Component
The control is organizational or facility-level and does not apply to the
Oxide cloud computer as a component.

```yaml
responsible-roles:
  - role-id: component-provider
    party-uuids:
      - 1fd0ef7d-e65f-483c-8ce0-f6d99eb6516e
props:
  - name: implementation-status
    ns: https://fedramp.gov/ns/oscal
    value: not-applicable
remarks: >-
  This control is not applicable to the Oxide cloud computer component.
  [Brief reason, for example "PE controls are the responsibility of the
  customer's facility." or "AT controls address personnel training programs
  operated by the deploying organization."] SSP authors must address this
  control at the organizational level.
```

---

## Common Patterns by Control Family

These patterns list what may be said about each topic and which statements
are required. They are not text to reproduce in every control. Per SKILL.md
rule 12, the full pattern belongs in the topic's home control (AC-17 for
technician ports, AU-12 and AU-3 for audit, SC-12 for keys, SC-17 for the
vendor PKI, SI-7 for boot integrity, SI-2 for update, SC-28 for disk
encryption). In any other control, use only the clause that bears on that
control, keep every limitation that is relevant to it, and leave the rest
to the home control.

### Audit Logging (AU family)
Facts: see "Audit Logging" in `oxide-architecture.md` ("Scope", "Records,
retention and access", "Alerts and webhooks"). Describe coverage as
"authenticated, state-changing requests to the external API, and login
attempts", with the exceptions that matter to the control. Never imply that a resource
identifier, a request body, or the content of a change is recorded. Where
the control covers privileged or maintenance access (AC-6(9), AU-12, AU-14,
MA-4, SI-4), name the technician port paths that are not audited. The rack
does not push records and alerts do not carry audit events.

Pattern: Customer obligations in `remarks`. `implementation-status: partial`.

Remarks template:
```
Oxide records an audit log entry for each authenticated, state-changing
request to the external API and for each login attempt, for successes and
failures, with these exceptions: [exceptions relevant to this control, for example: read (GET)
requests; self-logout; requests rejected at authentication other than
login attempts; wicket sessions, support SSH sessions and management
network unlock at the technician ports]. Local and SAML login attempts are
also recorded, without identifying the user. Entries carry the time, actor,
source address, authentication method, request URI, operation and result.
They have no resource identifier field and no request body, so the content
of a change is not recorded. Entries are kept on the rack for 90 days and
then permanently deleted; the period is not configurable. The rack does not
push audit records, and its alert mechanism does not deliver audit events.
The customer is responsible for fetching entries through the API at a
regular interval (fleet viewer role; Oxide publishes OpenTelemetry
Collector receivers for this), storing them externally for [retention
period required by the baseline], and performing review, correlation and
alerting in their own tooling. Retention beyond 90 days depends entirely on
this customer-side collection.
```

---

### Access Control - Account Management (AC-2)
Facts: see "API, Identity and Access" ("Authentication, sessions and
tokens", "Roles, provisioning and tenancy", "Open gaps"). Oxide provides
account management through the API. The customer is responsible for account
lifecycle procedures, access reviews, and identity provider integration,
and in particular for:

- choosing the silo identity mode at creation (it cannot be changed);
- in SAML silos with JIT user creation, ending a departed user's access
  with the logout endpoint, because removal at the identity provider does
  not remove or deactivate the user on the rack (SCIM silos deactivate
  through the identity provider);
- removing SSH keys from instances, which deactivated or deleted users
  keep access to;
- managing the local `recovery` silo fleet admin account.

Pattern: Customer obligations in `remarks`. `implementation-status: partial`.

---

### Access Control - Least Privilege (AC-6)
Facts: see "Roles, provisioning and tenancy". Oxide provides roles
assignable on the fleet, a silo, or a project. The customer is responsible
for role assignment and periodic review, including fleet roles (fleet admin
can change any silo's role policy, identity provider configuration and
quotas; fleet viewer can read the audit log) and any silo-to-fleet role
mapping. For AC-6(9), apply the Audit Logging and Technician Port patterns.

Pattern: Customer obligations in `remarks`. `implementation-status: partial`.

---

### Authentication, Sessions and Tokens (IA-2, IA-5, AC-7, AC-8, AC-12)
Facts: see "Authentication, sessions and tokens" and "Open gaps". Points
that change what the customer must do:

- MFA: none built in. Attribute it to the customer's identity provider,
  never to Oxide. Local-only silos, including `recovery`, are
  password-only.
- Local passwords: no minimum length, complexity, expiry, lockout or login
  rate limiting, and no self-service change. An administrator sets
  passwords. The customer compensates by procedure and by restricting local
  accounts.
- Console sessions: fixed idle and absolute limits with no setting. One
  session cannot be revoked alone; only all of a user's sessions and
  tokens together.
- Device tokens: no expiry unless a silo admin sets a maximum lifetime,
  which applies only to tokens created afterwards.
- No login banner setting. SAML assertion replay is an open gap.
- The API source-address allow-list defaults to "any".

Pattern: `implementation-status: partial`, with the customer's identity
provider settings and compensating procedures in `remarks`. Where the
control rests on a capability listed under "Open gaps" (for example AC-7,
AC-8), say so and flag the status for human review.

---

### Cryptographic Key Management (SC-12, SC-17, SC-28)
Facts: see "Storage and Encryption" (especially "Key custody", "Local
disks", "External interfaces"), "Trust Quorum", and "Code Signing and
Supply Chain". Say where each key is generated and stored, and nothing
more. Never write that keys never leave the rack, that disk keys are
managed by the trust quorum, that the customer holds no keys, or that there
is "a unique key per disk" without the sharing described here. Do not claim key
rotation for distributed disks, erasure of key material, or FIPS
validation.

**Keys on the rack** (see "Key custody"): distributed-disk keys are
generated by Nexus, stored unwrapped in the control plane database, and
shared with snapshots and derived disks; ZFS dataset keys for control plane
data are derived per U.2 drive from the rack secret; the rack secret is
split by the trust quorum into shares that are exchanged only with attested
member sleds but stored unencrypted on M.2 drives (state the theft
threshold as the fact base does, and never call keys or shares "sealed");
local disks are not encrypted by the rack; external TLS private keys are
customer-generated and a copy is stored on the rack.

**Signing keys at Oxide** (see "Signing hierarchy", "Offline roots and
ceremonies"): Oxide Computer Company keeps offline root keys and separate
online signing keys for RoT code signing and platform identity. Signing
happens at Oxide, not on the customer's rack. No signature on SP firmware
is verified at update or boot. Physical protection of the keystore,
ceremony witnesses, record retention and record availability are "Oxide
statements without a public source": attribute them to Oxide Computer
Company and add no detail.

Pattern: `implementation-status: partial` for all three. SC-28: the
local-disk exception and unencrypted M.2 drives. SC-12: customer TLS key
lifecycle, customer keys for local disks, no disk key rotation. SC-17:
external certificates come from the customer's PKI; Oxide's signing PKI is
not a certificate service for the customer.

Remarks template:
```
Oxide encrypts distributed disks and control plane datasets with keys
generated and stored on the rack: distributed-disk keys are generated by
the control plane and stored in its database (a disk's key is shared with
its snapshots and with disks derived from them), and control plane dataset
keys are derived per storage drive from a rack secret that is split across
sleds. Local disks are not encrypted by the component; the customer is
responsible for encrypting them in the guest or application and for
managing those keys. The customer is responsible for generating, issuing,
renewing and replacing the external TLS certificates and private keys,
which are uploaded to and stored on the rack. The component does not rotate
distributed-disk keys. [For signing keys: Oxide Computer Company states
that its offline root keys are kept in a physically protected offline
keystore and used only in witnessed, recorded ceremonies.] The customer is
responsible for [protecting or wiping removed drives per media procedures,
other obligations] and for documenting this key model in the system SSP.
```

---

### Software Update (SI-2, CM-3, CM-14)
Facts: see "Software Update" (every subsection) and, for the offline path,
"Wicket". What the pattern depends on:

- The customer's comparison of the bundle's SHA checksum with the value
  from Oxide Support is the only step that ties a bundle to Oxide, because
  the trust root is taken from the bundle. Do not name the algorithm or say
  how Support conveys the value.
- TUF signatures are checked once, at repository upload, against the
  rack's trust store. Later checks are by hash against the verified
  metadata. Metadata expiry is not enforced.
- TUF metadata is signed with a per-build key, not a persistent Oxide key.
  Do not write that bundles are signed by Oxide. RoT and RoT bootloader
  images carry their own signatures, verified at RoT boot; SP firmware has
  none.
- Setting the target release starts the update; there is no separate
  approval step. Update commands require fleet admin and are audit-logged.
- Offline update at the technician port does not consult the trust store
  and needs no credential. Its controls are the checksum comparison and the
  customer's control of access to the technician ports.
- No abort, rollback, or downgrade. Recovery is forward-only with Oxide
  Support. Do not claim anti-rollback.

Pattern: Customer obligations in `remarks`. `implementation-status: partial`.

Remarks template:
```
Oxide distributes update bundles through a customer-specified file
transfer. The customer is responsible for validating the SHA checksum of
each bundle against the value provided by Oxide Support before adding the
bundle's trust root to the rack; this comparison is the only step that
ties the bundle to Oxide. For updates driven through the API, the component
verifies the repository's signatures against the trust store once, at
upload, and checks each artifact by hash at installation. Offline updates
performed at the technician ports do not use the trust store; the customer
is responsible for controlling physical and network access to those ports.
Updates cannot be aborted or rolled back. The customer is responsible for
restricting the fleet admin role, removing trust roots that are no longer
needed, approving updates under [change control process] before the target
release is set, and documenting this procedure in the system SSP.
```

---

### Technician Port and Maintenance Access (AC-17, IA-2, IA-5, MA-4)
Facts: see "Technician Port and Maintenance Access" (every subsection). A
host on a locked technician port reaches three switch zone services:
wicket, which needs no credential; SSH as `support`, which needs an Oxide
support hardware-token key; and the API proxy, which uses ordinary customer
API credentials. The lock protects only direct access to the management
network. Rules for narratives:

- The customer's physical control of the ports, and network control of any
  jumpbox cabled to them, is the primary safeguard and the only one that
  covers wicket. State it first.
- Hardware tokens protect `support` SSH and unlock only. Do not credit
  them, the unlock protocol, or API authentication with protecting wicket.
- Unlock requires a signature only when the switch's root of trust is in
  the release lifecycle state. State that condition, and that Oxide
  Computer Company states every customer rack ships in that state.
- Do not say access requires physical presence. Remote support runs through
  a customer-provided jumpbox.
- Wicket sessions, `support` SSH sessions, and unlock and re-lock are not
  in the audit log. API proxy requests are.
- That the tokens are Yubikeys, need a PIN, are assigned to named
  personnel, are tracked, and have the PIN rotated on transfer are "Oxide
  statements without a public source". Attribute them to Oxide Computer
  Company.
- Do not describe the port as SSH-only or as reserved to Oxide support.

Pattern: Customer obligations in `remarks`. `implementation-status: partial`.

Remarks template:
```
The customer is responsible for controlling physical access to the
technician ports and network access to any jumpbox or other host cabled to
them. This is the primary safeguard for the technician ports: the wicket
setup and recovery interface reachable there requires no credential and
can power-control and update rack components. Oxide support shell access
and management network unlock require keys held on hardware tokens used
by Oxide support [unlock: when the switch root of trust is in the release lifecycle
state, in which Oxide Computer Company states every customer rack ships]; the API proxy requires the customer's own API credentials. Wicket
sessions, support SSH sessions and management network unlock are not
recorded in the component's audit log. Oxide Computer Company states that
it has no standing access to customer environments and does not perform
maintenance without a customer-initiated support engagement; the component
has no phone-home feature and makes no connection back to Oxide. The
customer is responsible for
granting and terminating jumpbox and network access for each Oxide support
session, keeping its own record of that access, monitoring the ports and
attached hosts under [facility and network monitoring procedures], and
documenting the technician port access model in the system SSP.
```

**AC-17:** Cite the lock applied at each switch SP start, the unlock
duration limit, the return to locked on expiry or SP restart, and explicit
re-lock, all scoped to direct management network access.

**IA-2:** Describe each path separately (wicket has no identification or
authentication) and let the assessor judge.

**IA-5:** The trusted key set is fixed in the switch SP firmware image
(unlock) and the switch zone image (`support` SSH). Adding or revoking a
key requires a software update, so revocation is not immediate.

**MA-4:** Oxide Computer Company has no standing access to customer
environments and does not perform maintenance without a customer-initiated
support engagement (Oxide statements; attribute them to Oxide Computer
Company). The rack has no phone-home feature and makes no connection back
to Oxide (documented). For a support session, Oxide requests access, the
customer grants credentials and jumpbox accounts, and the customer
terminates access afterwards. The customer authorizes and records each
session.

---

### Incident Response (IR family)
Facts: see "Audit Logging" and "Vulnerability Reporting and Advisories".
The audit log supports customer investigation within its stated scope and
90-day retention; apply the Audit Logging pattern and its limits (no
record of reads, of change content, or of the unaudited technician port
paths; no alerts for audit or authentication events). DTrace and trust
quorum service logs are diagnostics, not audit records. Oxide publishes
advisories and a security reporting contact. Its incident response plan
covers Oxide products and build systems and excludes incidents in customer
environments; do not assert response SLAs. Oxide does not manage the
customer's IR process.

Pattern: `implementation-status: not-applicable` for IR-2 (training) and
IR-8 (plan). `implementation-status: partial` for IR-4 and IR-6, with
customer IR process obligations, off-rack log collection, and advisory
monitoring in `remarks`.

---

### Configuration Management (CM family)
Facts: see "Software Update", "Network Isolation", "API, Identity and
Access". Oxide ships system software as one release bundle, and
configuration changes are made through the API, where they are audit-logged
within the scope of the Audit Logging pattern (the content of a change is
not recorded). The customer is responsible for documenting the baseline
configuration in the SSP, including shipped defaults they must review
(default VPC firewall rules admit SSH and ICMP from any source; the API
allow-list defaults to "any"; device tokens do not expire by default), and
for managing changes under their CM process. CM-3 and CM-14 carry the
obligations in the Software Update pattern.

Pattern: Customer obligations in `remarks`. `implementation-status: partial`.

---

### Supply Chain (SR family)
Facts: see "Code Signing and Supply Chain", and follow its "Control mapping
notes" for each control. The principal Oxide-authored components are open
source, but not all build inputs are public, and proprietary third-party
firmware is present (see "Open source scope"). Never write "no third-party
firmware", "all software is open source", or "reproducible" (except Hubris
images, as qualified in "Build provenance"; otherwise "pinned by version
and hash").

- **SR-3:** offline roots, a separate online signer, and scripted, recorded
  ceremonies, scoped to RoT firmware and platform identity. The tooling is
  public; ceremony records are not.
- **SR-4:** the RoT image certificate chain shows who signed, not source
  provenance. Other evidence: hash pinning of release inputs. For SP, host
  OS and control plane artifacts, no signature under a persistent Oxide key
  is verified.
- **SR-5:** weak fit. Do not claim resistance to insider compromise. Quote
  "Manufacturing and acquisition posture" statements as Oxide's own.
- **SR-11:** RoT firmware authenticity is enforced on the device. Do not
  write that customers can independently verify it. For SP firmware, cite
  TUF hashes and RoT measurement. Make no claim about counterfeit
  prevention or tamper-evident packaging.

Pattern: `implementation-status: partial` for SR-3, SR-4 and SR-11, with
the scope limit, the customer's bundle checksum comparison, and the
customer's own acquisition and component-authenticity procedures in
`remarks`. Flag SR-5 for human review. `implementation-status:
not-applicable` for SR-2, with a `remarks` note directing SSP authors to
their organizational supply chain risk management plan.

---

## Implementation Status Decision Guide

| Situation | implementation-status |
|---|---|
| Oxide fully implements, no customer action needed, no gap in the fact base | `implemented` |
| Oxide provides mechanism, customer must configure, operate, or supplement it | `partial` |
| Mechanism covers part of the control's scope, or the fact base lists a gap | `partial`, gap and customer action in `remarks` |
| The component has the subject of the control (for example, an audit log) but lacks the capability the control asks for, and the narrative states what the customer must supply | `partial`, with the absence stated plainly in `description` and the customer's obligation in `remarks` |
| The subject of the control does not exist in the component (for example, wireless interfaces), or the control is organizational or facility-level | `not-applicable` |
| Control will be addressed in a future Oxide release | `planned` |
| Control is addressed through a compensating approach | `alternative` |
| Needed capability is absent from the fact base or under "Not Established by This Reference" | flag for human review |

---

## Remarks Template for Customer Obligations

```
Oxide provides [mechanism]. The customer is responsible for [specific
obligations] when deploying this component. Customer-side responsibilities
must be documented in the system SSP.
```
