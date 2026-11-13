# CNSSI No. 1253 H-H-H Baseline + Classified System Overlay: Control Narrative Reference
# Oxide Cloud Computer Component Definition

## Baseline Source

The `source` field for `control-implementations` blocks targeting this
baseline must reference the appropriate Oxide-authored OSCAL profile. Two
profiles exist, both in this repository:

**H-H-H baseline (no overlay):**
`profiles/cnss-1253/cnssi-1253-hhh_profile.yaml`

**H-H-H baseline with Classified System Overlay (CNSSI 1253E5):**
`profiles/cnss-1253/cnssi-1253e5-classified-overlay_profile.yaml`

No published URL has been assigned for these profiles yet. When one is,
record it here and use it as `source`, pinned to a tagged release and
never to a branch (Authoring Rule 5). Until then, ask before writing a
`source` value; do not invent a host.

Use the overlay profile as the source whenever the component definition is
scoped to classified NSS environments. Use the base H-H-H profile only for
unclassified NSS workloads.

Both profiles are **non-authoritative transcriptions** maintained by Oxide.
CNSS has not published official OSCAL profiles for CNSSI 1253. Any conflict
between an Oxide profile and the published CNSSI document is resolved in
favor of the published document; report it against this repository so the
transcription can be corrected.

The control selections have been checked mechanically against the NIST SP
800-53 Rev 5.2.0 catalog (every identifier exists and none is withdrawn).
They have not been independently re-verified against the CNSSI documents
themselves. One difference from the NIST High baseline is known and
unexplained: the H-H-H profile omits IA-12(5), which the NIST High
baseline includes. Confirm it against Appendix D before relying on it.

---

## How CNSSI 1253 Differs from SP 800-53B

Three differences matter when authoring narratives for this baseline:

1. **No high-water mark.** SP 800-53B collapses C/I/A into a single impact
   level (Low/Moderate/High). CNSSI 1253 tracks C, I, and A independently.
   The H-H-H baseline means High on all three; other permutations exist but
   are not targeted by this component definition.
2. **Explicit C/I/A association per control.** Appendix D tables annotate
   each control/enhancement with the objective(s) it addresses. When a
   narrative justifies a control, it should speak to the specific objective
   the control protects rather than generic "confidentiality, integrity,
   and availability" boilerplate.
3. **NSS-specific parameter values.** Appendix D embeds NSS parameter values
   (in the 2022 edition these are in the Appendix D tables themselves rather
   than a separate Appendix E as in the 2014 edition). These values override
   SP 800-53B defaults. **They are not yet transcribed:** neither profile
   has a `set-parameters` block, only commented-out placeholders. Until
   they are, take parameter values from the published Appendix D directly.
   The `description` of an implemented-requirement must be consistent with
   the NSS parameter value, not the SP 800-53B default.

---

## Coverage Status

No `control-implementations` block targets this baseline yet. Many H-H-H
controls already have narratives in the SP 800-53 block; as of 2026-11-13,
57 system-implementable H-H-H controls and 7 more from the classified
overlay have no narrative anywhere in the component definition. Most of
the 57 are the SA-8 design principle enhancements; the rest are spread
across AC, AU, CA, CM, IA, IR, MA, RA, SC and SI. The overlay profile adds
28 controls to H-H-H: AC-3(2), AC-16(5), AC-19(4), AC-20(4), AU-6(8),
AU-6(9), MP-5(3), MP-8, MP-8(1), MP-8(2), MP-8(4), PE-2(3), PE-3(2), PE-19,
PE-19(1), PM-12, PS-3(1), PS-6(2), RA-6, SA-4(6), SC-7(26), SC-8(3),
SC-8(4), SC-12(2), SC-12(3), SC-15(3), SC-42 and SI-4(21).

When adding implemented-requirements against CNSSI 1253, start from the
SP 800-53B High narratives (`sp800-53-high.md`) and adjust for:
- Any NSS parameter value difference from Appendix D
- Any control added by the Classified System Overlay (if using the overlay
  profile as source)
- Any C/I/A objective that CNSSI associates with the control differently
  from how the narrative frames it

---

## Family Dispositions

The family-level dispositions in `sp800-53-high.md` transfer substantially
unchanged to CNSSI 1253: the component boundary is the same regardless of
baseline. Use `sp800-53-high.md` as the starting point and apply the
adjustments below.

### PE - Physical and Environmental Protection
**Still customer-responsible, but sharper under the Classified Overlay.**
The overlay profile adds PE-2(3), PE-3(2), PE-19 and PE-19(1) (facility
access and information leakage). The Oxide Cloud Computer is deployed in a customer-controlled
facility, so PE controls remain customer-responsible, but the `remarks` on
each PE implemented-requirement should explicitly note the overlay's
additional facility-level expectations so the SSP author knows to address
them.

### PS - Personnel Security
**Still not-applicable to the component**, but the overlay profile adds
PS-3(1) and PS-6(2), personnel requirements that the SSP author must
satisfy at the organizational level. The `remarks` pattern for PS controls under
the overlay should direct the SSP author to reference their personnel
security program against the 1253E5 personnel-clearance provisions.

### MP - Media Protection
**Shared, with overlay emphasis.** Use the same scope for encryption at
rest as SC-28 in `sp800-53-high.md`: distributed disks are encrypted,
while local disks and the M.2 boot drives are not, and no erasure or
zeroization of key material may be claimed. The overlay profile adds
MP-5(3) and MP-8 with enhancements (transport custodians and
downgrading); the customer handles classified media marking,
sanitization, downgrading and destruction. For overlay-scoped
implemented-requirements, `remarks` must cite the 1253E5 marking and
sanitization obligations explicitly rather than the generic SP 800-53B
customer-responsibility language.

### SC - System and Communications Protection
**Shared, as in `sp800-53-high.md`, with a cryptographic caveat.** The
overlay profile adds SC-8(3), SC-8(4), SC-12(2), SC-12(3), SC-7(26),
SC-15(3) and SC-42. SC-12(2) and SC-12(3) (symmetric and asymmetric keys)
select among approved key management technologies such as FIPS-validated
or NSA-approved ones. `oxide-architecture.md` lists FIPS validation as
not established and says nothing that supports an NSA-approved or Type 1
claim, so do not make one. The internal control plane traffic and
guest overlay traffic facts in that file also bear on SC-8(3) and
SC-8(4). Where the overlay's expectation exceeds what the fact base
supports, use `implementation-status: partial` and document the gap in
`remarks`.

### IR - Incident Response
**Customer-responsible, with information spillage in scope.** The H-H-H
profile itself includes IR-9, IR-9(2) and IR-9(4); the overlay profile
adds no IR controls. The component's audit log can support a spill
investigation only within its scope (authenticated, state-changing
requests to the external API, and login attempts; no record of reads and
no content of changes), and it does not drive the customer's spill
response process. Use `partial` for IR-9 family controls only where that
audit data supports the investigation; `not-applicable` for purely
organizational IR controls.

### AC - Access Control
**Shared, with additions under the overlay.** The mechanism claims from
`sp800-53-high.md` still apply. The overlay profile adds AC-3(2) (dual
authorization), AC-16(5), AC-19(4) and AC-20(4), and PM-12 (insider
threat program). The fact base documents no dual-authorization mechanism.
Where the overlay tightens access-review cadence or requires supervisory
approval, capture those expectations in `remarks` rather than
`description`: they are customer obligations, not Oxide mechanisms.

---

## Not-Applicable Controls (Component Scope)

The not-applicable list in `sp800-53-high.md` (AT, PE, PL, PM, PS) applies
to this baseline as well. Under the Classified Overlay, the `remarks` for
each not-applicable control must add a pointer to the overlay's additional
requirements for that family so the SSP author does not miss them.

---

## Known Gaps

Populate once an initial pass of implemented-requirements is drafted. The
most likely gap areas, given the overlay, are:

- SC controls requiring specific cryptographic module attestations
  (SC-12(2), SC-12(3), SC-8(3), SC-8(4))
- AC-3(2) dual authorization
- MP controls tied to classified media handling
- IR-9 family (information spillage)
- PE/PS additions introduced by the overlay
- NSS parameter values, which are not yet transcribed into the profiles

---

## Narrative Quality Standards

All standards from `sp800-53-high.md` apply, plus:

1. **Name the objective.** When a control is in the H-H-H baseline because
   of its High allocation on a specific objective (per Appendix D), the
   narrative should be clear about which objective is primarily addressed.
2. **Quote the NSS parameter value, not the SP 800-53B default.** If
   Appendix D specifies a value that differs from SP 800-53B, the
   description must be consistent with the Appendix D value. Do not leave
   the SP 800-53B default in the narrative by accident.
3. **Cite the overlay, not just 1253, when the overlay applies.** For
   implemented-requirements targeting the overlay profile, `remarks`
   should reference "CNSSI 1253E5" where the overlay drives a customer
   obligation. This makes it explicit to SSP authors which document to
   consult.
4. **Do not overclaim against the overlay.** Classified-environment
   controls (TEMPEST, open storage, Type 1 crypto, personnel clearances)
   are overwhelmingly customer-side. Oxide's technical mechanisms may
   support but rarely satisfy overlay requirements on their own. Default
   to `partial` with a precise customer obligation in `remarks`.

---

## Maintenance

- Track the CNSS site for updates to CNSSI 1253 and to individual
  Appendix E overlay attachments. Overlays are versioned independently of
  the base Instruction.
- When an update publishes, bump the `version` of the affected profile and
  update `last-modified`. Do not rotate the document `uuid`.
- When SP 800-53 Revision 6 publishes and CNSS rebases 1253 to it, a new
  profile will be needed rather than an in-place update, because the
  underlying catalog change is breaking.

