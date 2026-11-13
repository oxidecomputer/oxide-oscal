---
name: oxide-oscal-component
description: This is for the development and maintenance of the NIST OSCAL Component Definition for the Oxide cloud computer. It is written for a given software release, and could / should be updated as new releases address known gaps or better support the controls in the component definition.
---

# Oxide Cloud Computer — OSCAL Component Definition Skill

## Purpose

This skill supports authoring and extending the NIST OSCAL Component Definition
for the Oxide Cloud Computer. It is scoped exclusively to the component definition
model — not system security plans, assessment plans, or other OSCAL models.

This document is authored by Oxide Computer Company as the component provider.
There is no customer party in this document. Customer organizations import this
component definition into their own SSPs and document their party information
and customer-side obligations there.

The Oxide Cloud Computer is modeled as a **single component** reflecting its
indivisible procurement and deployment reality. Internal architectural elements
(Hardware RoT, Hubris firmware, control plane, etc.) are surfaced through `props`
and `remarks` within implemented-requirements rather than as separate OSCAL
components.

## Supported Workflows

- **Extend control coverage** — add implemented-requirements for controls not yet
  covered in the existing component definition
- **Add a new baseline** — add a new control-implementation block targeting a
  different source profile (FedRAMP High, CMMC, CNSS 1253)
- **Refine existing narratives** — improve description or remarks content for an
  existing implemented-requirement
- **Validate structure** — check that a proposed addition conforms to OSCAL
  component definition schema conventions
- **Assess shared responsibility** — determine whether a control is
  provider-implemented, customer-responsible, or shared, and express that correctly

## Active Baselines

| Baseline | Status | Source Reference |
|---|---|---|
| SP 800-53B High | Active | `resources/control-narratives/sp800-53-high.md` |
| CNSSI 1253 H-H-H (± Classified Overlay 1253E5) | Profiles authored; no `control-implementations` block yet | `resources/cnssi-1253.md` |
| FedRAMP High | Planned | — |
| CMMC | Planned | — |

The CNSSI 1253 baseline uses Oxide-authored OSCAL profiles because CNSS has not
published official OSCAL profiles for CNSSI 1253. See
`resources/cnssi-1253.md` for the profile locations and the
non-canonicalness handling rules.

## Bundled Resources

Load these only when the task requires them:

- `resources/oxide-architecture.md` — The fact base: Oxide security architecture
  facts for the targeted release, each with its public source, plus
  `Narrative guidance:` blocks that say how to word them. Load when drafting
  or reviewing any implemented-requirement narrative, and read the guidance
  block of every section you draw on. It is a source to select from, not a
  list of things each narrative must say (rule 12).
- `resources/shared-responsibility.md` — Patterns for expressing provider vs.
  customer responsibility. Load when a control involves customer configuration,
  inherited controls, or split responsibility.
- `resources/control-narratives/sp800-53-high.md` — Control family guidance,
  narrative patterns, and implementation status notes for the SP 800-53B High
  baseline. Load when working with that baseline.
- `resources/cnssi-1253.md` — CNSSI 1253 H-H-H baseline
  guidance, the Classified System Overlay (1253E5) additions, and the differences
  from SP 800-53B that matter for narratives. Load when working with the CNSSI
  1253 baseline (with or without the overlay).
- `resources/oscal-schema-reference.md` — Relevant OSCAL component definition
  fields, their semantics, and the description vs. remarks distinction. Load when
  validating structure or when the correct field placement is uncertain.
- `resources/parties-roles.md` — Standard UUID-stable party and role definitions
  for Oxide (this document has no customer party). Load when adding any element that references a
  party-uuid or role-id.
- `scripts/generate-uuid.sh` — Execute to generate a new UUID for any component
  definition element that requires one. Always execute this script rather than
  constructing UUIDs manually.
- `scripts/validate.sh` — Execute to lint the repository's YAML files against
  their declared schemas after making changes.

## Authoring Rules (Always Apply)

These rules apply regardless of which resources are loaded:

1. **Single component model.** Never add a second top-level component. Internal
   architectural detail belongs in `props` and in `remarks` on implemented-requirements.

2. **description is normative, remarks is editorial.** `description` must be
   sufficient for an assessor to evaluate the control without reading `remarks`.
   `remarks` carries caveats, shared responsibility notes, and SSP author guidance.

3. **Customer obligations go in `remarks`, not `responsible-roles`.** This
   document has no customer party. Any control where the customer bears
   configuration or operational responsibility must have that obligation
   documented in `remarks` using the standard template from
   `resources/shared-responsibility.md`. Set `implementation-status` to
   `partial`. Never add a customer party reference to `responsible-roles`.

4. **UUIDs come from the script.** Always run `generate-uuid.sh` for new elements.
   Never construct or guess UUIDs.

5. **source field accuracy.** The SP 800-53 `control-implementations` block
   uses the NIST SP 800-53 Release 5.2.0 catalog (its `back-matter` resource)
   as its `source`, not a baseline profile, because the control selection is
   wider than any single baseline: it covers every High baseline control that
   Oxide's implemented-by-system profile classifies as system-implementable,
   plus further controls at Oxide's discretion. The selection rule is recorded
   in the block's `control-selection` prop. The catalog and all targeted
   baseline profiles must still appear as resources in `back-matter` so
   downstream consumers can resolve control definitions and see which
   baselines were in scope. Pin `source` and resource links to a tagged
   oscal-content release, never to `main`.

6. **implementation-status is required.** Every implemented-requirement must carry
   an `implementation-status` prop using the FedRAMP namespace
   (`https://fedramp.gov/ns/oscal`) with one of: `implemented`, `partial`,
   `planned`, `alternative`, `not-applicable`. Use `not-applicable` only
   when the subject of the control does not exist in the component or the
   control is purely organizational or facility-level. When the component
   has the subject but lacks the capability, use `partial`, say so
   plainly, and put the customer's obligation in `remarks` (see the
   decision guide in `resources/shared-responsibility.md`).

7. **Oxide architecture claims must be sourced.** Any claim about Oxide's security
   architecture in a `description` must be traceable to a fact in
   `resources/oxide-architecture.md`. Do not assert capabilities Oxide has not
   publicly documented, and do not assert anything that file lists under
   "Not Established by This Reference". Facts it lists under "Oxide
   statements without a public source" may be used only when the narrative
   attributes them to Oxide Computer Company. Follow every
   `Narrative guidance:` block in the sections you use; where this file's
   other resources disagree with `oxide-architecture.md`, that file governs.

8. **No em dashes.** Do not use em dashes (—) in any output, including
   both OSCAL content (description, remarks, and other prose fields) and
   explanatory text. Use commas, parentheses, colons, or separate sentences
   instead.

9. **Non-canonical profiles are disclosed.** When a `control-implementations`
   block targets a baseline whose OSCAL profile is authored by Oxide rather than
   by the baseline's publishing body (currently: CNSSI 1253 and 1253E5), the
   profile file itself must carry a `remarks` entry in its metadata that states
   it is a non-authoritative transcription and that conflicts are resolved in
   favor of the published source document. Do not present Oxide-authored
   profiles as official. Track upstream publication of canonical profiles and
   switch the `source` field to the canonical URL as soon as one is available.

10. **Audit-log scope must be precise.** When claiming audit coverage,
    describe it as "authenticated, state-changing requests to the external
    API, and login attempts", and name the exceptions that matter to the control, as documented
    in the Audit Logging section of `resources/oxide-architecture.md`. Do
    not write blanket phrases such as "all API operations," "every API
    call," "all authentication events," or "every control plane operation".
    Read-only (GET) requests, requests rejected at authentication, and the
    technician port paths other than the API proxy are not audited. Do not
    say a record contains a resource identifier or a request body; the
    record fields are listed in that section. If audit coverage changes in a
    later release, update `resources/oxide-architecture.md` first, then
    revise narratives to match.

11. **One targeted Oxide release.** The component definition describes
    exactly one Oxide system release: the one recorded in the component's
    `version` and `release-date` props and in the Targeted Release section
    of `resources/oxide-architecture.md`. Those must agree. Write every
    narrative as a statement about that release. Do not describe earlier
    releases, compare behavior across releases, or say when a capability
    was introduced. Forward-looking statements are limited to "planned for
    a future release" without naming a release number. To retarget, update
    `resources/oxide-architecture.md` first, then the `version` and
    `release-date` props, then re-verify each narrative against the new
    release.

12. **Write for the authorization decision.** The reader is a security
    officer deciding whether to authorize a system that includes the rack.
    Include a detail only if it changes the assessor's determination for
    this control or changes what the customer must do. The fact base holds
    far more than a narrative should carry.
    - **State the property, not the mechanism.** Say what is enforced, by
      what part of the system, and under whose control. Leave out how it
      works: protocol exchanges, algorithm names, key sizes, endpoint and
      operation names, internal service and repository names, numeric
      defaults and limits. Include such a value only when the control
      itself asks for it (for example the lockout threshold in AC-7, the
      idle timeout in AC-11 and AC-12, the algorithms in SC-13, the
      password rules in IA-5(1), the record fields in AU-3).
    - **Never trim a limitation.** A gap, an absent capability, an
      unauthenticated or unaudited path, or a default that is open must
      stay, stated in one plain sentence. Brevity applies to mechanism, not
      to disclosure.
    - **Stay on the control's subject.** Do not add adjacent facts because
      they are true and sourced.
    - **Say each thing once.** A cross-cutting topic is described in full
      only in its home control: technician ports in AC-17, audit scope in
      AU-12 and record content in AU-3, key custody in SC-12, vendor PKI in
      SC-17, boot integrity in SI-7, software update in SI-2, disk
      encryption in SC-28. Any other control states only the part that
      bears on it, in a sentence or two, and may point to the home control
      by its identifier.
    - **`remarks` holds obligations, not a recap.** State what the customer
      must do and what the SSP must document. Do not restate the
      description.
    - **Length.** Most descriptions fit in one or two short paragraphs
      (about 150 words or fewer). A home control may run to about 300.
      Mechanism detail belongs in the linked public documentation, which is
      maintained per release.
    Fewer specifics also means fewer statements to re-verify when the
    targeted release changes (rule 11).

## Output Format

Always produce output as valid YAML conforming to OSCAL component definition
schema v1.2.3. When producing a partial addition (e.g., a single
implemented-requirement), produce only the new element with a comment indicating
its insertion point in the existing document. Do not reproduce the entire
component definition unless explicitly asked.
