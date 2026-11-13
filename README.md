# oxide-oscal
Oxide NIST OSCAL Component Definition

This repository contains the OSCAL component definition for the Oxide cloud
computer and the Claude skill used to maintain it.

An Oxide RFD rendering of this component definition can be found at
https://rfd.shared.oxide.computer/rfd/0536.

## How this component definition is produced

The control narratives in the component definition are created with the
assistance of Claude, using a skill in the `.claude/skills/` directory. The
`.claude/skills/oxide-oscal-component/resources/oxide-architecture.md` file is
used as a working reference for the narratives, and includes a number of
citable sources for evidence. The component definition is written for a
specific Oxide software release.

The skill and narratives are reviewed by Oxide engineers before being
published, and Oxide is responsible for the accuracy of the content. The
component definition and RFD 536 should be considered the authoritative
sources for statements about the Oxide cloud computer. The RFD is updated
manually and may lag behind this repository. Other files in this repository
should be considered as resources for producing the component definition
and should not be cited directly. Any errors identified, including drift
between RFD 536 and the component definition in this repository, can be
reported to security@oxidecomputer.com.

The component definition itself is `oxide_component_definition.yaml`. The
CNSSI 1253 profiles in `profiles/` are unofficial and made by Oxide from the
CNSS documents publicly available. The files in `assessment-procedures/` are
examples.
