# SP 800-53B High Baseline: Control Narrative Reference
# Oxide Cloud Computer Component Definition

## Source and Baseline Resources

The `source` field of the SP 800-53 `control-implementations` block references
the Release 5.2.0 catalog's `back-matter` resource (pinned to oscal-content
v1.6.0), not the High baseline profile. The selection is wider than the High
baseline (see Coverage Rule and Status below), so a profile source would
mis-scope the implementation. The High baseline profile remains a
`back-matter` resource documenting the baseline whose system-implementable
controls form the coverage floor:

```yaml
source: "#<uuid of the SP 800-53 Rev 5.2.0 catalog back-matter resource>"
```

Resource links for the catalog and profile point at
`https://raw.githubusercontent.com/usnistgov/oscal-content/refs/tags/v1.6.0/...`
in XML, JSON, and YAML forms. Update the tag deliberately when moving to a
new catalog release, and record the catalog version in the block's
`catalog-version` prop.

---

## Catalog Version

The component definition targets NIST SP 800-53 Release 5.2.0 (oscal-content
v1.6.0, built on OSCAL 1.2.3). Release 5.2.0 added three controls relative to
5.1.1: SA-15(13) Logging Syntax, SA-24 Design for Cyber Resiliency, and
SI-2(7) Root Cause Analysis. None is in the High baseline, and SA-15(13) and
SA-24 are organization-implemented per Oxide's profile; none has a narrative
today. No control already in the component definition changed statement
text, title, or parameters between 5.1.1 and 5.2.0. The control
implementation carries `catalog-version` and `control-selection` props
recording this.

## Coverage Rule and Status

The coverage commitment is a floor, not a filter: the component definition
must include every SP 800-53B High baseline control that Oxide's
`sp800-53r5-implemented-by-system` profile classifies as implementable by
an information system (110 controls as of 5.2.0). Controls beyond that
floor are included at Oxide's discretion and are never removed on the
grounds that they are organization-implemented or outside a baseline. As
of 2026-11-13 the component definition holds 184 controls: all 110 of the
floor, 12 further High baseline controls classified as
organization-implemented, and 62 controls outside the High baseline. The
High baseline floor is fully covered. The CNSSI 1253 H-H-H profile has 57
system-implementable controls with no narrative yet, and the classified
overlay has 7 more; see `resources/cnssi-1253.md`.

Status convention (owner decision, 2026-11-13): `not-applicable` is
reserved for controls whose subject does not exist in the component (for
example, the wireless controls) and for purely organizational or
facility-level controls. Where the component has the subject of the
control but lacks the capability the control asks for, keep the entry,
say plainly in `description` that the component does not provide it, use
`partial`, and state the customer's obligation in `remarks`. Do not
change an existing entry between `partial` and `not-applicable` without
applying this test.

This file documents:
- Per-family disposition decisions that apply across all controls in that family
- Controls that are not applicable to this component and why
- Controls that are always customer-responsible regardless of Oxide's role
- Known gaps requiring additional implemented-requirements

---

## Family Dispositions

These decisions apply uniformly within each family and must not be contradicted
by individual implemented-requirement narratives without documenting the reason.
`oxide-architecture.md` (the fact base) is authoritative; quoted names below
are its section headings. Read the named section before drafting.

### AC - Access Control
**Disposition: Shared**
The Oxide Cloud Computer provides the mechanism: API-enforced roles on the
fleet, silos and projects, with silos as the tenancy boundary (see "Roles,
provisioning and tenancy"). The customer is responsible for policy: account
provisioning, role assignment, access reviews and least privilege.
`description` covers the mechanism; `remarks` documents customer obligations
per the shared responsibility patterns. Gaps to carry (see "Open gaps" and
"Authentication, sessions and tokens"):
- **AC-2:** users created just in time are not removed when removed at the
  IdP, and deactivated users keep SSH access to instances holding their keys.
- **AC-7:** local password login has no lockout and no rate limiting.
- **AC-8:** the API has no setting for a system use notification.
- **AC-11, AC-12:** console sessions end after 8 hours idle or 24 hours in
  total, with no setting. Device tokens do not expire by default; a silo
  admin can set a maximum lifetime for tokens created later. One session
  cannot be revoked on its own, only all of a user's sessions and tokens.

**AC-17 specifically (also AC-6(9)):** follow "Technician Port and
Maintenance Access". The host on a technician port may be a laptop on site
or a customer-provided jumpbox used for remote support, so do not say access
requires physical proximity. The lock protects direct access to the
management network only: it is opened by challenge-response for at most one
hour and returns when the duration elapses or the switch SP restarts. A
locked port still reaches three switch zone services: wicket (no
credential), `support` SSH (Oxide support hardware-token key) and the API
proxy (ordinary API credentials; reachable even when the IP allow-list
blocks access). Wicket, `support` SSH and unlock are not in the audit log.
The safeguard for wicket is customer control of physical access to the
ports and network access to anything cabled to them. See the technician
port pattern in shared-responsibility.md.

### AT - Awareness and Training
**Disposition: Customer-responsible**
AT controls address personnel training programs. Oxide has no role in
the customer's training process. All AT controls should carry
`implementation-status: not-applicable` for the component and a `remarks`
note directing the SSP author to document this in their organization-level
controls.

### AU - Audit and Accountability
**Disposition: Shared**
The Oxide Cloud Computer records authenticated, state-changing requests to
the external API, and login attempts, with the exceptions listed in "Audit Logging" (see also
Authoring Rule 10). The customer is responsible for collection off the
rack, retention beyond 90 days, monitoring and review. Narratives must
reflect:
- **Not audited (AU-2, AU-12, AU-14):** GET requests, including denied
  reads and serial console access; requests rejected at authentication
  (other than login attempts, whose entries identify neither user nor
  session); self-logout; session and token expiry; internal APIs; and
  wicket sessions, `support` SSH and unlock at the technician port.
- **Record content (AU-3):** use the field list in "Records, retention and
  access". There is no resource identifier field and no request or
  response body; the resource appears only in the URI and operation ID.
- **Access (AU-6, AU-9):** fleet `viewer` role only, with no silo-scoped
  view and no filter other than time range. Completed entries are
  immutable; there is no API to modify or delete them.
- **Alerts (AU-5, AU-6):** webhook alerts cover only a liveness probe and
  power shelf hardware classes. Notification of audit, account or
  authentication events depends on customer tooling reading the log.

**AU-11 specifically:** retention is 90 days from completion, then
permanent deletion, with no setting to change it, and the rack does not
push records. Narratives must state the customer-side fetch-and-externalize
obligation as required, not optional. See shared-responsibility.md for the
AU remarks template.

### CA - Assessment, Authorization, and Monitoring
**Disposition: Customer-responsible**
CA controls govern the authorization process itself. Public source for the
principal Oxide-authored components (see "Open source scope") and the audit
log API support evidence collection, but the customer owns assessment and
authorization. Do not assert penetration test or third-party assessment
results (see "Not Established by This Reference"). Use `partial` for CA-7
and CA-8 where this support is a factor; `not-applicable` for CA-1, CA-2,
CA-3, CA-5, CA-6, which are purely organizational.

### CM - Configuration Management
**Disposition: Shared**
Oxide Computer Company ships each release as one update bundle (see
"Software Update"). The customer is responsible for documenting the
baseline configuration in the SSP, managing changes through the API per
their CM process, and maintaining system inventory. For CM-7, note that a
new VPC's default firewall rules admit SSH and ICMP from any source.

**CM-3, CM-5 and CM-14 specifically:** follow "Software Update".
- Update commands require fleet admin; setting the target release starts
  the update with no separate approval step.
- The customer compares the bundle checksum with the value from Oxide
  Support. This is the only step that ties a bundle to Oxide, because the
  trust root is taken from the bundle itself. Assign it explicitly.
- TUF signatures are verified once, at repository upload, against the
  trust store. Afterwards artifacts are checked by SHA-256 against the
  verified metadata. Metadata expiry is not enforced; do not cite it.
- RoT and bootloader images carry signatures the RoT verifies at boot. No
  signature on SP firmware is verified at update or boot.
- The offline update path through wicket does not consult the trust store
  and needs no credential.
- Downgrades are refused and there is no abort or rollback: recovery is
  forward-only with Oxide Support. Do not claim rollback or anti-rollback.

See the Software Update pattern in shared-responsibility.md.

### CP - Contingency Planning
**Disposition: Customer-responsible**
The customer owns the plan. Cite only capabilities the fact base lists:
distributed disks kept as three copies on three sleds, with Crucible
repairing replicas; point-in-time snapshots of distributed disks; restart
of a failed instance on another sled under the default auto-restart policy;
and storage unlock at cold boot without human intervention (see "Storage
and Encryption" and "Trust Quorum"). Limits to state: local disks are a
single copy with no snapshots, and if fewer than K trust quorum shares
survive, everything encrypted under the rack secret is lost. Use `partial`
where a listed capability directly supports a CP requirement;
`not-applicable` where the control is purely organizational.

### IA - Identification and Authentication
**Disposition: Shared**
The Oxide Cloud Computer authenticates API users and devices. The customer
integrates an identity provider, defines authentication policy and manages
user credentials. Oxide Computer Company manages the support access keys.

**IA-2 specifically:** address two populations separately.
- Control plane users: there is no built-in MFA. For SAML silos MFA is
  whatever the customer's IdP enforces; attribute it to the IdP. Local-only
  silos, including the built-in `recovery` silo, are password only. SAML
  assertion IDs are not tracked, which matters for replay resistance.
- Oxide support access: hardware-token (PIV) keys protect `support` SSH
  and management network unlock only. Wicket needs no credential and the
  API proxy uses customer API credentials. That the tokens are Yubikeys and
  require a PIN are statements of Oxide Computer Company without a public
  source; attribute them (see "Support credentials"). Describe the
  mechanism and leave sufficiency to the assessor.

**IA-3 specifically:** scope to sled-to-sled authentication. Each RoT holds
an identity key certified under Oxide's platform identity PKI; sleds
authenticate each other in sprockets sessions (mutual TLS 1.3 with
attestation), and trust quorum checks the attested identity against its
member list (see "Sled identity" and "Sprockets"). Say what peers verify,
not that identity "prevents" rogue sleds. Other control plane traffic on
the underlay is unauthenticated (see "Internal communications").

**IA-5 specifically:** the support key set is fixed in the switch SP
firmware image and the switch zone image and changes only by software
update, so revocation follows the update cadence. Token assignment,
custodianship tracking and PIN rotation are Oxide Computer Company
statements without a public source. Local passwords are hashed with
Argon2id; there is no minimum length, complexity, expiry or lockout, and
no self-service change. See the technician port pattern in
shared-responsibility.md.

### IR - Incident Response
**Disposition: Customer-responsible**
IR controls address the customer's incident response capability. The audit
log (within the AU scope above) supports investigation, but Oxide does not
manage the customer's IR process, and Oxide's public incident response plan
excludes incidents in customer environments. Use `partial` for IR-4 and
IR-6 where the audit log provides direct support; `not-applicable` for
IR-2 (training) and IR-8 (plan), which are purely organizational.

### MA - Maintenance
**Disposition: Shared**
Normal updates are applied by the customer's operators (fleet admin role)
through the API, using bundles that Oxide Computer Company distributes,
without physical access. Offline update through wicket is described in
public documentation as performed by Oxide Support, on site or remotely
through the customer's jumpbox; SSD firmware updates also involve Oxide
Support. Hardware replacement requires physical access. The customer
authorizes maintenance and controls physical access to the rack.

**MA-3 specifically:** shared, not provider-implemented. Wicket is a
maintenance path with no logical access control: without a credential it
can run an offline update and power-control any sled, switch or power shelf
controller (see "Wicket"). Its safeguard is customer control of physical
access to the technician ports and network access to anything cabled to
them. **MA-6:** the fact base lists no support SLA; flag for review.

**MA-4 specifically:** Oxide Computer Company has no standing access to
customer environments and does not perform maintenance without a
customer-initiated support engagement; narratives must say so, attributed
to Oxide Computer Company. The rack has no phone-home feature and makes no
connection back to Oxide. For remote support, Oxide requests access, the
customer grants credentials and jumpbox accounts, Oxide staff SSH from the
jumpbox to the rack, and the customer terminates the access afterwards.
Narratives must describe each path's authentication as under AC-17 and
IA-2, state that wicket sessions, `support` SSH sessions and unlock are not
in the audit log (API proxy requests are), and assign session
authorization, jumpbox access control and session monitoring to the
customer. See the technician port pattern in shared-responsibility.md.

### MP - Media Protection
**Disposition: Shared**
SC-28 carries the technical description; MP narratives must use the same
scope. The M.2 boot drives are not encrypted and hold configuration and
trust quorum shares, and local disks are not encrypted. Do not claim
erasure or zeroization of key material; wiping M.2 drives at decommission
is a procedure, not a system function (see "Trust Quorum"). The customer is
responsible for media handling, sanitization and disposal, including
removed sleds and drives.

### PE - Physical and Environmental Protection
**Disposition: Customer-responsible**
The Oxide Cloud Computer is deployed in a customer-controlled facility.
All PE controls (physical access, environmental controls, power, etc.) are
the customer's responsibility. Use `not-applicable` for all PE controls in
this component definition; the SSP author must document PE controls in
their facility-level controls, including physical control of the
technician ports, which is the only safeguard for the wicket path.

### PL - Planning
**Disposition: Not applicable**
PL controls are organizational and documentation controls. They do not apply
to a hardware/software component. Use `not-applicable` for all PL controls.

### PM - Program Management
**Disposition: Not applicable**
PM controls are organizational governance controls. They do not apply to this
component. Use `not-applicable` for all PM controls.

### PS - Personnel Security
**Disposition: Not applicable**
PS controls govern personnel vetting and management. They do not apply to
this component. Use `not-applicable` for all PS controls.

### PT - PII Processing and Transparency
**Disposition: Customer-responsible**
PT controls address how the customer processes PII in systems running on
the Oxide Cloud Computer. Silo isolation and distributed-disk encryption
(within the SC-28 scope below) support PT requirements, but the customer
owns the PII processing policy.

### RA - Risk Assessment
**Disposition: Customer-responsible**
RA controls govern the customer's risk assessment process. Use `partial`
for RA-5 where public source for the principal Oxide-authored components
and Oxide's published security advisories support the customer's
vulnerability management. Follow "Vulnerability Reporting and Advisories":
reports go to a published security contact and are acknowledged within 72
hours. Do not assert a published vulnerability disclosure policy.

### SA - System and Services Acquisition
**Disposition: Shared**
SA-4 (acquisition process) is customer-responsible. For the rest follow
"Control mapping notes", "Open source scope" and "Build provenance". The
principal Oxide-authored components are open source; not all build inputs
are public, and proprietary third-party firmware is present.

**SA-10, SA-15 specifically:** cite public version control, build inputs
pinned by version and hash, and a scripted release process that runs in CI
on every commit. Signed release builds are identified as future work.
Write "pinned by version and hash", not "reproducible", except for Hubris
images with the RFD 605 qualification. **SA-11:** partial; follow "Memory
Safety" and do not assert test, assessment or audit results.

### SC - System and Communications Protection
**Disposition: Shared** (changed from provider-implemented: internal
traffic and local disks are not cryptographically protected, and
certificates, guest traffic encryption and firewall policy are the
customer's.)

Provider mechanisms: Crucible encryption of distributed disks, ZFS
encryption of control plane datasets, HTTPS on the external API and
console, VPC enforcement by OPTE in the host OS on each sled, and the trust
quorum. Exceptions narratives must carry:
- **SC-28** (see "Storage and Encryption"): scope encryption claims to
  distributed disks. A snapshot holds the same key as its disk, and a disk
  created from a snapshot or image embeds the source key, so do not write
  "a unique key per disk" without this. There is no key rotation. Local
  disks and the M.2 boot drives are not encrypted; assign local-disk
  encryption to the customer. Control plane datasets on U.2 drives are
  ZFS-encrypted with one key per drive.
- **SC-8** (see "Internal communications"): external API and console are
  HTTPS only, with customer-supplied certificates. Control plane services
  and the control plane database use the underlay without TLS and without
  authentication; describe the protection as network isolation, with the
  sprockets exception for trust quorum traffic. Guest overlay traffic
  between sleds is not encrypted; that is a customer responsibility.
- **SC-7** (see "Network Isolation"): a new VPC's default rules admit SSH
  and ICMP from any source.
- **SC-13:** FIPS 140 validation and FIPS-approved mode are not
  established (see "Not Established by This Reference"). Do not assert
  them; direct the customer to confirm with Oxide.

**SC-12 and SC-17 specifically:** state where each key is generated and
stored, as in "Key custody", and nothing more.
- Distributed-disk keys: generated by Nexus, stored unwrapped in the
  control plane database. Held by the rack, not by the customer and not by
  the trust quorum.
- ZFS dataset keys: derived on each sled from the rack secret, not stored
  persistently. The rack secret is split into shares stored unencrypted on
  each member sled's M.2 drives and exchanged over sprockets. Do not say
  keys or shares are sealed, wrapped or hardware-protected.
- External TLS private keys: generated by the customer outside the rack,
  uploaded and stored in the control plane database. The customer controls
  issuance and replacement; the rack holds a copy.
- Local disks: no rack-managed key.
- Vendor signing keys (see "Code Signing and Supply Chain"): held by Oxide
  Computer Company, not on the rack. Offline roots certify online signing
  keys, which sign RoT firmware and the RoT bootloader; a separate root
  anchors platform identity. SP firmware is outside this hierarchy.

The customer manages external TLS keys and any local-disk or in-guest
encryption keys, and documents the rack-held keys in the SSP. See
shared-responsibility.md for the key management remarks template.

### SI - System and Information Integrity
**Disposition: Shared** (changed from provider-implemented: the bundle
checksum comparison and monitoring of integrity events fall to the
customer, and no host OS boot verification is established.)

**SI-7 specifically:** follow "Hardware Root of Trust" exactly and treat
each mechanism separately.
- RoT firmware, verified boot: the boot ROM verifies the bootloader, which
  verifies both Hubris slots and boots one that passes. A failing slot is
  skipped; if neither passes, the RoT does not boot.
- SP firmware, measured only: the RoT records a SHA3-256 digest of the SP
  firmware when it catches an SP reset. It holds no expected value and
  never prevents the SP from booting, so SP integrity depends on a verifier
  appraising the attested measurement. No SP signature is verified.
- Attestation covers RoT and SP firmware only. Nothing in the fact base
  establishes verification or measurement of the host OS at boot; do not
  say the host OS, control plane software or guests are verified, measured
  or attested.
- Update time: signatures checked at upload, hash checks afterwards (CM-3).

**SI-2 specifically:** use the update model under CM-3, including the
customer checksum step, the wicket offline path and forward-only recovery.
See the Software Update pattern in shared-responsibility.md. **SI-4,
SI-5:** state the alert scope under AU and the technician port audit gap;
for advisories follow "Vulnerability Reporting and Advisories".

### SR - Supply Chain Risk Management
**Disposition: Shared** (changed from provider-implemented: public
evidence covers RoT firmware and platform identity only, part of the model
rests on Oxide statements without a public source, and the step that ties
an update bundle to Oxide is the customer's checksum comparison.)

The principal Oxide-authored components are open source. Proprietary
third-party firmware is present (see "Open source scope"); never claim "no
third-party firmware", "no black-box components" or "all software is open
source".

**SR-3, SR-4, SR-5, SR-11 specifically:** follow "Control mapping notes".
- SR-3: offline roots, a separate online signer and scripted, recorded
  ceremonies, scoped to RoT firmware and platform identity. The tooling is
  public; ceremony records are not.
- SR-4: RoT images and the bootloader carry a certificate chain to an Oxide
  root, enforced by the RoT at boot. This shows who signed, not source
  provenance. For SP, host OS and control plane artifacts, no signature
  under a persistent Oxide key is verified; cite hash pinning of inputs.
- SR-5: weak fit. The only public multi-party mechanism is the split backup
  of the root keys. Do not claim resistance to insider compromise.
- SR-11: RoT firmware authenticity is enforced on the device. Do not write
  that customers can independently verify it (see "Build provenance").

Ceremony witnesses and retention of ceremony records are Oxide Computer
Company statements without a public source (see "Offline roots and
ceremonies"); attribute them. SR-2 (supply chain risk management plan) is
an organizational control the customer owns.

---

## Not-Applicable Controls (Component Scope)

The following control families have no applicable controls for a hardware/
software component in a customer-operated facility. All controls in these
families should carry `implementation-status: not-applicable`:

- AT (Awareness and Training)
- PE (Physical and Environmental Protection): customer facility responsibility
- PL (Planning)
- PM (Program Management)
- PS (Personnel Security)

---

## Known Gaps

Document controls in the High baseline floor not yet covered by an
implemented-requirement here. Update this list as gaps open or close.

None as of 2026-11-06: all 110 system-implementable High baseline controls
have an implemented-requirement (see Coverage Rule and Status). Re-check
this against the High baseline profile whenever the catalog version or
the implemented-by-system profile changes.

---

## Narrative Quality Standards

When drafting or refining a `description` for this baseline:

1. Name the Oxide mechanism and the property it provides (not a generic
   claim), and stop there: how the mechanism works belongs in the linked
   documentation (SKILL.md rule 12)
2. Name the architectural element responsible (RoT, SP, control plane,
   storage service, trust quorum) only where it tells the assessor who or
   what enforces the control
3. Be precise about what is automatic vs. what requires configuration
4. Do not claim FIPS validation or anything else listed under "Not
   Established by This Reference" in oxide-architecture.md
5. Avoid passive voice: "The Oxide Cloud Computer encrypts distributed
   disk data at rest" not "data at rest is encrypted"
6. **Distinguish product from vendor.** "Oxide" alone is ambiguous: it can
   mean the Oxide Cloud Computer (the product, in the customer's facility)
   or Oxide Computer Company (the vendor, in its own facilities). Use "the
   Oxide Cloud Computer" for what the product does on premises and "Oxide
   Computer Company" for vendor activity (signing ceremonies, release
   engineering, support). Assessors rely on this distinction when
   evaluating trust boundaries and shared responsibility scope.
7. For SI-7, distinguish RoT verified boot from RoT measurement of the SP,
   and limit attestation claims to RoT and SP firmware
8. For SC-12, list each key class from "Key custody" with where it is
   generated and stored, in a clause each, and keep vendor signing keys
   separate. Other controls refer to SC-12 instead of repeating the list
9. For supply chain narratives (SR-3 through SR-11), follow "Control
   mapping notes" and scope claims to RoT firmware and platform identity
10. For AC-17, IA-2, IA-5 and MA-4, do not conflate control plane user
    authentication (customer-configured) with Oxide support access
    (hardware-token keys managed by Oxide Computer Company)
11. Never state that a technician port access path is authenticated
    without naming wicket, which requires no credential. The full
    technician port description lives in AC-17; other controls state only
    the part that bears on them
12. Describe audit coverage as "authenticated, state-changing requests to
    the external API, and login attempts, with the exceptions listed here"
13. Attribute "Oxide statements without a public source" to Oxide Computer
    Company
14. Describe the mechanism and assign responsibilities; do not write that
    a mechanism "satisfies" a control or baseline
15. Apply the detail test in SKILL.md rule 12 to every sentence: keep it
    only if it changes the assessor's determination or the customer's
    obligation. Limitations always pass that test; mechanism rarely does
16. `remarks` states customer obligations and SSP guidance. It does not
    restate the description
