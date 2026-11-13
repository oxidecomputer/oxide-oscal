# Oxide Cloud Computer: Security Architecture Reference

This file is the fact base for OSCAL control narrative authoring. Every
claim in an implemented-requirement description must be traceable to an
entry here.

How to read it:

- Facts describe **Oxide system release 23** only (see Targeted Release).
- `Source:` lines give the public source for the facts above them. Omicron
  links are pinned to the `rel/v23` branch; other repositories are cited at
  the tag or revision that was read.
- `Narrative guidance:` blocks are instructions to the narrative author.
  They are not facts to cite.
- Lists headed "Oxide statements without a public source" are Oxide
  Computer Company's own statements about its practice. Narratives may use
  them only when attributed to Oxide Computer Company.

**Do not assert capabilities not listed in this file.** If a control
narrative needs a capability that is not documented here, or that is listed
under "Not Established by This Reference", flag it for human review rather
than inferring it.

## Targeted Release

The component definition targets **Oxide system release 23** (release notes
dated 2026-09-18), at patch level 23.3. This is the release recorded in the
component's `version` and `release-date` props, and the two must always
agree. Every fact in this file describes release 23 behavior, and
narratives describe release 23 behavior only. Do not describe earlier
releases, compare against them, or say when a capability was introduced.
When the component definition is retargeted to a new release, update this
file first (replacing facts in place rather than appending history), then
the component's `version` and `release-date` props, then the narratives.

Patch contents (all part of the targeted release):

- 23.1: six upstream illumos security fixes, including a bhyve
  instruction-emulation flaw that could panic the host (CVE-2026-102916).
- 23.2: rustls 0.23.45, rustls-webpki 0.103.16 and webpki-root-certs
  1.0.10 for Security Advisory 20261105-1 (eMudhra intermediate CAs with
  weak private keys; affects Nexus as a TLS client of `https://` webhook
  receivers and SAML metadata URLs); service processor firmware 1.81.1.

Source: https://docs.oxide.computer/release-notes/system/23
Source: https://docs.oxide.computer/security/advisories/20261105-1

## System Overview

The Oxide cloud computer is a rack-scale system of co-designed hardware and
software. The unit of purchase is a fully integrated rack; compute sleds
can be added to a partially populated rack.

- **Compute sleds:** up to 32 first-generation sleds (Gimlet, one AMD EPYC
  7713P "Milan") or up to 24 second-generation sleds (Cosmo, one AMD EPYC
  9005 series "Turin"). Release 23 recognizes three sled CPU families:
  Milan, Turin, and Turin Dense. Each sled has 10 U.2 NVMe bays, 2
  internal M.2 devices, 2 ports of 100 GbE, a root of trust (RoT), and a
  service processor (SP).
- **Switching:** two integrated "Sidecar" rack switches, each with its own
  SP and RoT and a separate management network switch.
- **Power:** integrated AC to DC power shelves (the specifications page
  lists two per rack) feed a DC bus bar. The power shelf controller (PSC)
  has its own SP and RoT.

Components and the section that covers each:

- RoT, an NXP LPC55S69 microcontroller on every sled, switch, and PSC:
  Hardware Root of Trust.
- Hubris, Oxide's Rust OS for the RoT and SP microcontrollers: Hubris.
- SP, which manages power, thermals, and the host serial console: Service
  Processor.
- Helios, the illumos-based host OS on each sled: Host Operating System.
- bhyve and Propolis, the hypervisor: Hypervisor and Instance Attestation.
- Omicron, the control plane (Nexus, sled agent, supporting services):
  Control Plane, API Identity and Access, Audit Logging.
- OPTE, the switch data plane, and the management network: Network
  Isolation.
- Crucible distributed block storage and ZFS: Storage and Encryption.
- Rack-level secret sharing that unlocks storage: Trust Quorum.
- Switch technician ports: Technician Port and Maintenance Access.
- Signing keys, release builds, third-party content: Code Signing and
  Supply Chain.
- TUF-based system update: Software Update.

Oxide statements without a public source:

- The rack has no wireless network interfaces. All network connectivity
  is wired.

Narrative guidance: do not call the rack "indivisible", state fixed
16/24/32 sled configurations, or say the software cannot be obtained
separately from the hardware.

Source: https://docs.oxide.computer/guides/introduction
Source: https://oxide.computer/product/specifications
Source: https://docs.oxide.computer/guides/architecture/rack-components
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/db-model/src/sled_cpu_family.rs

## Hardware Root of Trust

Each compute sled has a dedicated hardware root of trust (RoT): an NXP
LPC55S69 microcontroller, separate from the host CPU and the service
processor (SP), running its own Hubris image. Switch and power shelf
controller boards also carry an RoT. Release 23 ships RoT Hubris 1.0.38,
RoT bootloader (bootleby) 1.4.1 and SP Hubris 1.81.1. The RoT provides
verified boot of its own firmware, a DICE measurement of its own Hubris
image carried in its certificate chain, and measured boot of the SP. The
host has no direct interface to the RoT: requests go from host to SP
(IPCC), then SP to RoT (SPI).

### Verified boot of the RoT's own firmware

- The LPC55 boot ROM verifies bootleby. Bootleby verifies both Hubris
  slots (A and B, kept for in-system update) and boots one that passes.
- Bootleby reuses the ROM's signature-check routine, after first rejecting
  an image that is not fully programmed, has an out-of-bounds length or
  header offset, or has a reset vector outside the image.
- A slot that fails is skipped and the other slot is booted. If neither
  passes, bootleby stops in a fault state and the RoT does not boot.
- Bootleby's unsigned, CRC-only image mode is an opt-in build feature that
  the release build does not enable.
- RoT Hubris start-up code re-checks both Hubris slots and both bootloader
  slots with the same ROM routine and reports the results to its update
  task.
- A sled whose RoT is not running cannot present the RoT-held certificates
  and attestation that peers require for a sprockets connection (see Trust
  Quorum).

Narrative guidance: name the mechanism and the firmware it covers. Do not
write that the RoT "attests firmware integrity before execution is
transferred", that a failure "halts boot and excludes the sled from the
rack", or what the ROM does when bootleby fails verification (no public
source).

Source: https://github.com/oxidecomputer/bootleby (`README.mkdn`, `src/lib.rs`, `src/bin/bootleby.rs`, `xtask/src/main.rs`; revision `e09fdc1`)
Source: https://github.com/oxidecomputer/hubris/blob/oxide-rot-1-v1.0.38/lib/lpc55-rot-startup/src/lib.rs (also `src/images.rs`)
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/tools/permslip_production
Source: https://docs.oxide.computer/release-notes/system/23

### Trust anchor: root key table, CMPA and CFPA

- Oxide uses the LPC55's own secure boot: RSA PKCS#1 v1.5 signatures over
  a SHA-256 digest of the image. Bootleby and RoT Hubris are signed with
  the same key.
- The Customer Manufacturing Programmable Area (CMPA) holds one root key
  table hash (ROTKH, also written RKTH): the SHA-256 of four entries, each
  the SHA-256 of a root public key (zeros for an empty entry).
- Every signed image carries its certificate chain and the four root key
  hashes. Oxide's `lpc55_sign` verifier, which models the ROM, requires
  that the four hashes hash to the ROTKH; that the chain's root is one of
  the four and its slot is enabled in the Customer Field Programmable Area
  (CFPA); that the signing certificate is not revoked by the CFPA
  image-key-revoke counter; and that the image signature verifies under
  the signing (leaf) certificate's key.
- Slot state (invalid, enabled or revoked) is the CFPA field RKTH_REVOKE,
  not part of the CMPA. Oxide's tooling documents that the ROM rejects a
  CFPA update that changes an RKTH_REVOKE bit from 1 to 0, and CFPA pages
  carry an increasing version, so a revoked slot cannot be re-enabled.
- The CMPA can be locked; Oxide's tooling calls this irreversible.
- Each platform has its own RoT code-signing PKI with four self-signed
  RSA-4096 roots: Release A and B, Development A and B. Published key
  specifications cover Gimlet, PSC and Sidecar. Roots are held in an
  offline, HSM-backed keystore and certify online signing certificates
  (see Code Signing and Supply Chain).
- RoT debug access is disabled without a credential signed by one of
  those roots.
- Cosmo has its own set of four RSA-4096 roots, one for each trust anchor
  its RoT supports, created by a scripted signing ceremony (RFD 585).
- The control plane selects RoT and bootloader update images by matching
  the device's root key table hash to the image's caboose `SIGN` value.

Oxide statements without a public source:

- Production bootleby and RoT Hubris are signed by an online signer
  certificate under a Release root.
- Production CFPAs mark the two Release root slots enabled and the two
  Development root slots invalid, so production RoTs reject images signed
  under a Development root. The
  Development roots let development units boot development-signed
  firmware under the same CMPA.
- The CMPA is locked at the end of manufacturing.

Narrative guidance: say the trust anchor commits to four roots, two
Release and two Development, and that production hardware enables only
the two Release roots. Attribute items in the list above to Oxide, not to
a public source. `embootleby` is a bench tool for development keys: cite
it for CMPA and CFPA semantics only. Cite RFD 585 only for the structure
of the PKI.

Source: https://github.com/oxidecomputer/lpc55_support (`lpc55_sign/src/signed_image.rs`, `lpc55_sign/src/verify.rs`, `lpc55_areas/src/lib.rs`; revision `1710b53`)
Source: https://github.com/oxidecomputer/offline-keystore (`specs/README.md`, `specs/production/`, `docs/debug-credentials.md`; revision `a5724b3`)
Source: https://github.com/oxidecomputer/embootleby (`src/main.rs`; revision `9e365fe`)
Source: https://rfd.shared.oxide.computer/rfd/0585
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/reconfigurator/planning/src/mgs_updates/rot.rs (also `rot_bootloader.rs`)

### Measured boot of the service processor

The SP is a separate microcontroller with its own reset line. The RoT
never transfers execution to it; it measures it from outside.

- The RoT measures SP firmware when the SP resets: it obtains a SHA3-256
  digest of the active SP firmware image and records it in its
  measurement log for attestation.
- The RoT holds no expected value, makes no comparison and never prevents
  the SP from booting. If measurement does not occur the SP still boots,
  and the absence shows in the attested log.
- The log exists only in RoT memory.

Narrative guidance: the RoT measures; the SP is measured. Do not write
that the SP "performs measured boot", that the RoT "hands off" to the SP,
or that boot halts "on mismatch". For SI-7, SP firmware integrity depends
on a verifier appraising the attested measurement (see Attestation scope).

Source: https://github.com/oxidecomputer/hubris/blob/oxide-rot-1-v1.0.38/drv/lpc55-swd/src/main.rs (also `lib/endoscope/src/main.rs`, `task/attest/src/main.rs`)
Source: https://github.com/oxidecomputer/hubris/blob/all-sp-v1.81.1/lib/measurement-handoff/src/lib.rs (also `app/gimlet/base.toml`, `app/cosmo/base.toml`)

### Sled identity

- The RoT's Unique Device Secret derives from a Physically Unclonable
  Function (PUF) in the LPC55 silicon.
- A long-lived Ed25519 identity keypair (RFD 238: the PlatformId key) is
  generated in the RoT from the PUF during manufacturing. The private key
  never leaves the RoT, and start-up code blocks and locks the PUF key
  index before Hubris tasks start.
- Its certificate is issued during manufacturing by an Oxide intermediate
  manufacturing key under the platform identity root (ECDSA P-384). The
  subject carries the sled's part and serial number: the PlatformId. RFD
  238 treats it as valid for the lifetime of the device.
- DICE layering at each RoT boot: a DeviceId key is derived from the ROM's
  DICE secret and certified by the identity key. That secret is mixed with
  the SHA3-256 digest of the active RoT Hubris slot, and three leaf keys
  are derived from the result and certified by DeviceId: the Alias key
  (signs attestations), the trust quorum key (authenticates sprockets TLS
  sessions) and an SP-measure key. Each leaf certificate carries the RoT
  image digest.
- Chain: leaf, DeviceId, identity certificate, manufacturing intermediate,
  verified against the platform identity root.
- Sleds authenticate each other with this identity in sprockets sessions,
  and trust quorum identifies a peer by the PlatformId in its verified
  chain (see Trust Quorum).

Narrative guidance: do not write that device identity "prevents" rogue
sleds from joining; say what peers verify and what trust quorum checks.

Source: https://rfd.shared.oxide.computer/rfd/0238
Source: https://github.com/oxidecomputer/hubris/blob/oxide-rot-1-v1.0.38/lib/lpc55-rot-startup/src/dice.rs (also `src/lib.rs`, `src/dice_mfg_usart.rs`, `task/attest/src/main.rs`)
Source: https://github.com/oxidecomputer/offline-keystore (`specs/production/`; revision `a5724b3`)

### Attestation scope

- The RoT is the root of trust for both measurement and reporting.
- Two measurements exist: the RoT Hubris image digest, in the leaf
  certificates above, and the SP firmware digest, in the measurement log.
- An attestation is an Ed25519 signature by the Alias key over the
  SHA3-256 digest of the serialized log and a caller-supplied nonce (32 to
  128 bytes), returned with the certificate chain.
- A verifier checks the chain, then the signature, then appraises the
  measurements against reference measurements (CoRIM documents) that
  Oxide generates in its release process. In release 23 sled agent's
  sprockets configuration enforces this between sleds (see Trust Quorum).
- Coverage is RoT and SP firmware only. RFD 605 describes measurement of
  host-side components as future work.
- The boot ROM is immutable and is where verified boot and the DICE
  derivation begin. Nothing verifies it and it is not measured.

Narrative guidance: limit attestation and measured-boot claims to RoT and
SP firmware. Do not imply coverage of host boot software, AMD PSP
firmware, the host OS, control plane software or guests, and do not call
the boot ROM measured, verified or attested. For attestation scope cite
RFD 605 and the code.

Source: https://rfd.shared.oxide.computer/rfd/0605
Source: https://github.com/oxidecomputer/hubris/blob/oxide-rot-1-v1.0.38/task/attest/src/main.rs (also `task/attest-api/src/lib.rs`)
Source: https://github.com/oxidecomputer/sprockets (`tls/src/server.rs`, `tls/src/client.rs`; revision `a233079`)

## Hubris

- Hubris is Oxide's open-source operating system for microcontrollers,
  written in Rust. It runs on the RoT and the SP of each sled, switch and
  power shelf controller.
- Every task, including device drivers, is a separately compiled program
  running in the processor's unprivileged mode. Memory protection hardware
  confines each task to the regions assigned to it at build time; a task
  cannot directly access kernel memory or another task's memory.
- Tasks interact through kernel-mediated IPC: synchronous messages, in
  which the caller may lend specific buffers to the callee until the call
  ends (the kernel then revokes the loan), and notification bits.
- An image contains the kernel and a fixed set of tasks. Tasks cannot be
  created or individually updated at run time.
- A faulting task is stopped by the kernel and restarted at the request of
  the supervisor task. Other tasks keep running; a task waiting on the
  failed one receives an error.
- Source is public; release 23 tags are `oxide-rot-1-v1.0.38` and
  `all-sp-v1.81.1`. Production signing keys and certificates are not in
  it.
- The control plane updates RoT, bootloader and SP images remotely (Nexus
  through MGS to the SP; see Software Update); no physical access needed.

Narrative guidance: do not write "no shared mutable memory" or that tasks
communicate "only" by synchronous IPC. Say each task runs in its own
memory-protected regions and interacts through kernel-mediated IPC.

Source: https://hubris.oxide.computer/reference/
Source: https://github.com/oxidecomputer/hubris (`doc/intro.adoc`, `doc/tasks.adoc`, `doc/ipc.adoc`, `task/jefe/src/main.rs`; revision `4a7567b`)
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/mgs-updates/src/lib.rs

## Service Processor

- Each compute sled has a service processor: an STM32H753 microcontroller,
  separate from the host CPU and the RoT, running its own Hubris image.
- It manages sled hardware (power sequencing, thermal and fan control,
  sensors) and gives the control plane, over the management network, host
  power control, host serial console access and firmware update. It also
  relays host requests to the RoT.
- The RoT measures SP firmware when the SP resets and does not
  gate SP boot (see Measured boot of the service processor). The SP makes
  no integrity decision about its own firmware.
- The RoT also runs an SP update watchdog, which can switch the SP to
  its alternate flash bank.
- The SP performs the chassis-management functions of a baseboard
  management controller (BMC) on a conventional server, but Oxide
  distinguishes it from a BMC: it is a microcontroller running Hubris, not
  a general-purpose BMC software stack.

Narrative guidance: do not write that the SP "is a BMC", that it enforces
its own firmware integrity, or that Hubris or the SP "replaces BIOS/UEFI";
the absence of BIOS and UEFI belongs to the host boot path (see Host
Operating System).

Source: https://docs.oxide.computer/guides/architecture/rack-components
Source: https://rfd.shared.oxide.computer/rfd/0020
Source: https://github.com/oxidecomputer/hubris/blob/all-sp-v1.81.1/app/gimlet/base.toml (also `app/cosmo/base.toml`)

## Host Operating System

Helios is Oxide's distribution of illumos and the operating system for the
host x86 CPU in every compute sled. Oxide's platform support is in the
`stlouis` branch of its illumos-gate fork, which adds an `oxide` machine
architecture and platform drivers. Release 23 pins Helios commit `4e9eabf`
(omicron `tools/pins.toml`).

### Boot Path

- **AMD firmware runs before any Oxide code on the host CPU.** The AMD
  Platform Security Processor (PSP), an ARM core in the CPU package, is
  the first core out of reset. It runs AMD-supplied binary firmware that
  trains memory, copies the host boot image from SPI flash into memory,
  and releases the x86 boot core. RFD 241 calls this "AMD-supplied
  firmware executing on in-package cores outside our control"; RFD 20
  notes its source is closed and it can be signed only by AMD's key. The
  blobs (PSP boot loaders and OS, AGESA boot loader, SMU and
  memory-training firmware) are listed in Helios under `image/amd/`.
- **phbl** (Pico Host Boot Loader) is the first x86 code, at the reset
  vector: a small Rust program with an assembly start-up stub. It takes
  the boot core from 16-bit real mode to 64-bit long mode, inflates a
  compressed cpio archive (phase 1) that is compiled into phbl itself,
  loads the illumos kernel ELF from it, and calls its entry point. phbl
  reads nothing from disk, flash, or network.
- **The host boot image is the update system's "host phase 1" image.**
  It is held in the sled's host boot flash (SPI flash), which has two
  slots, and is written by the control plane through the service
  processor.
- **phbl does not verify the kernel or the archive.** It has no hash or
  signature check. RFD 284 defers verification to the SP as a design
  assumption; this file does not establish that release 23 verifies or
  measures the host image at boot.
- **The kernel does the rest.** It performs the platform initialization
  that BIOS or UEFI firmware performs on conventional servers and stays
  resident, with no handoff to a second kernel (RFD 241). No BIOS or UEFI
  firmware runs on the x86 cores or remains resident for runtime calls.

Narrative guidance: say Oxide-authored software runs from the first x86
instruction, never "the processor's first instruction", and never imply
no vendor firmware is involved or that the host OS replaces "all" UEFI
functions. Make no statement about ACPI. Do not say phbl, the SP, or the
RoT verifies or measures the host OS at boot.

Source: https://rfd.shared.oxide.computer/rfd/0020
Source: https://rfd.shared.oxide.computer/rfd/0241
Source: https://rfd.shared.oxide.computer/rfd/0284
Source: https://github.com/oxidecomputer/phbl (README, `src/`; rev `3a4905b`)
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/gateway-api/src/lib.rs (host phase 1 image and host boot flash)
Source: https://github.com/oxidecomputer/amd-host-image-builder (README; rev `dd68404`)
Source: https://github.com/oxidecomputer/helios/tree/4e9eabf1589b06a32a68fcf4f7f5297fe6714944/image/amd
Source: https://github.com/oxidecomputer/illumos-gate/blob/stlouis/usr/src/uts/oxide/os/mp_startup.c (read at the head of `stlouis`, not at a commit pinned to release 23)

### Source Availability

- Helios is open source. Its README lists the repositories it is built
  from; illumos-gate (`stlouis`), phbl, boot-image-tools,
  amd-host-image-builder, and the package build scripts are public.
- At the pinned commit the README marks a small number of non-public
  build inputs, including third-party firmware.
- The AMD firmware and the Chelsio T6 ROM are vendor binaries that the
  build installs into the host image.

Narrative guidance: say Helios and the Oxide components named in this file
are published as open source, and that the host image build also draws on
a small number of non-public inputs listed in the Helios README, including
third-party binary firmware. Never write that "all" Oxide-authored
software or firmware is open source, nor that the only non-public content
is third-party firmware.

Source: https://github.com/oxidecomputer/helios/blob/4e9eabf1589b06a32a68fcf4f7f5297fe6714944/README.md
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/.github/buildomat/jobs/tuf-repo.sh

### DTrace

illumos provides DTrace, a dynamic tracing framework for kernel and
user-level software, used for debugging and performance analysis,
including post-mortem analysis of crash dumps.

Narrative guidance: DTrace is not an audit mechanism. RFD 26 says a
reliable auditing system cannot be built on it because the system does not
guarantee that a tracing enabling stays active. Do not cite it for AU
controls or as a forensic record.

Source: https://rfd.shared.oxide.computer/rfd/0026

## Hypervisor and Instance Attestation

- bhyve is the open-source virtual machine monitor in the illumos kernel.
  Propolis is Oxide's open-source Rust userspace VMM for bhyve and the
  only VMM the sled agent launches.
- bhyve refuses to operate without hardware virtualization (AMD-V, also
  called SVM) with nested paging, so it has no shadow-page-table code;
  RFD 26 cites this as keeping its codebase smaller than KVM's.
- Each VM has its own nested page table root, which the processor uses to
  confine the guest to its own memory. This isolates each VM from every
  other VM and from the host, regardless of tenant.
- Nested virtualization is unsupported: SVM instructions executed by a
  guest raise an undefined-instruction exception.
- Each running VM has its own `propolis-server` process in its own
  non-global zone, created by the sled agent per Propolis VMM ID (during
  live migration the destination sled has a second zone for the same
  instance). The zone is delegated only the bhyve and viona device nodes
  and that instance's local disk volumes.
- The bhyve driver enforces zone boundaries: a non-global zone may create
  at most one VM, sees only its own VM's device node, and cannot destroy
  another zone's VM.
- Legacy PC devices are emulated: interrupt controllers and timers in the
  kernel; an i440FX chipset, PS/2, and UARTs in Propolis.
- Guest images must boot with UEFI; Windows versions that require a TPM
  are not supported.
- The bhyve facts above (the hardware virtualization requirement, nested
  page tables, nested virtualization and zone enforcement) were read from
  the illumos source at the head of the `stlouis` branch, not at a commit
  pinned to release 23.

Narrative guidance: use AMD terms (AMD-V or SVM, nested page tables), not
Intel VT-x or EPT. Say "other VMs", not "other tenants". The process and
zone boundaries confine the VMM, not the guest directly. Do not say there
is "no legacy emulation". Cite the illumos files below by file, not line.

Source: https://docs.oxide.computer/guides/architecture/os-hypervisor-storage
Source: https://rfd.shared.oxide.computer/rfd/0026
Source: https://github.com/oxidecomputer/illumos-gate/blob/stlouis/usr/src/uts/intel/io/vmm/amd/svm.c
Source: https://github.com/oxidecomputer/illumos-gate/blob/stlouis/usr/src/uts/intel/io/vmm/vmm_sol_dev.c
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/sled-agent/src/instance.rs
Source: https://github.com/oxidecomputer/propolis/tree/93e04e1/lib/propolis/src/hw

### Instance Attestation

A guest can obtain an attestation signed by the RoT of the sled it runs
on, bound to the instance's identity (RFD 605).

- **Transport.** Every instance gets a virtio socket (vsock) device.
  Propolis serves attestation requests on a well-known vsock port, one
  JSON document per line; no guest network configuration is involved.
- **Request.** Exactly 32 bytes of qualifying data, opaque to the
  platform. The request has no other field.
- **Binding.** Propolis computes SHA-256 over the instance identity data
  (as JSON) followed by those 32 bytes and requests an RoT attestation
  over that digest through the sled agent. It returns the RoT's signed
  attestation, measurement log, and certificate chain, plus the identity
  data it used.
- **Identity data.** The instance, project, and silo UUIDs. A boot disk
  digest is added only when the designated boot disk is a read-only
  distributed (Crucible) disk; local, writable, or absent boot disks are
  not measured. The digest is SHA-256 over every block of the disk, in
  order, not over an image file, partition, or kernel.
- **Availability.** Until boot disk hashing finishes, requests fail and
  the guest must retry; the wait grows with disk size. A disk read
  failure during hashing terminates that instance's Propolis process.
- **Any process in the guest can request an attestation.** Propolis
  checks only that the request comes from the instance's vsock device on
  the expected port; the guest OS must impose any further restriction.
- **Sled agent endpoint.** The sled agent serves RoT attestation requests
  only to that sled's own zones.
- **What is attested.** The signed measurements cover RoT and SP firmware
  only (see Hardware Root of Trust). Propolis holds no signing key: the
  identity data is asserted by Propolis and bound through the digest, so
  its accuracy rests on the host OS and Propolis, which are not measured.
- **Verification is outside the platform.** A verifier checks the
  certificate chain to Oxide's platform identity PKI, recomputes the
  digest, verifies the signature, and appraises the measurements against
  Oxide's reference measurements. RFD 605 gives the guest interface no
  backward-compatibility guarantee.

Narrative guidance: requesting, verifying, and appraising attestations are
customer responsibilities. Key binding is a guest convention: a guest may
set its 32 bytes to a digest of a challenger's nonce and a public key, but
the platform never sees or validates a key. Narratives may say a guest can
bind caller-chosen data to an attestation. They must not say the platform
binds, certifies, or verifies instance keys, call the result mutual
authentication, or say it covers the host OS, hypervisor, or guest
software. Cite RFD 605 and the code for the wire format.

Source: https://rfd.shared.oxide.computer/rfd/0605
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/src/app/instance_platform/mod.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/sled-agent/src/sled_agent.rs
Source: https://github.com/oxidecomputer/propolis/tree/93e04e1/lib/propolis/src/attestation
Source: https://github.com/oxidecomputer/propolis/blob/93e04e1/bin/propolis-server/src/lib/initializer.rs
Source: https://github.com/oxidecomputer/vm-attest/blob/deaf020/src/lib.rs
Source: https://github.com/oxidecomputer/vm-attest/blob/deaf020/src/rot.rs

## Memory Safety

- The software Oxide wrote for the product is predominantly Rust: Hubris
  (RoT and SP firmware), bootleby (RoT bootloader), phbl, Propolis,
  Omicron, Crucible, and OPTE.
- Not Rust: the illumos kernel (including bhyve) and userland, CockroachDB
  and ClickHouse, and AMD and other vendor firmware.
- Safe Rust prevents memory-safety errors such as out-of-bounds access and
  use-after-free, and data races. Code in `unsafe` blocks (present in the
  firmware and boot code), the compiler, and non-Rust components are
  outside that guarantee, and logic errors are not prevented.

Narrative guidance: for SI-16 and SA-11, say safe Rust avoids these defect
classes by construction; do not say it "eliminates" them or that "the
majority of the stack" is Rust. Host memory protection also depends on the
C kernel.

Source: https://rfd.shared.oxide.computer/rfd/0026
Source: https://oxide.computer/faq-friday/why-does-oxide-use-rust

## Control Plane

- Omicron is Oxide's control plane, running in illumos zones on Helios. One
  control plane manages compute, networking and storage for the rack.
- Components: Nexus (API server and orchestration), sled agent (per-sled
  instances, storage and networking; reports hardware to Nexus), bootstrap
  agent (rack-level trust and storage unlock), MGS (Management Gateway
  Service, talks to service processors), Dendrite (switch management),
  Oximeter (metrics), NTP, internal and external DNS, Crucible (distributed
  block storage) and its Pantry, OPTE (packet processing on each sled).
- Nexus, sled agent and MGS are in the omicron repository. Crucible, OPTE,
  Propolis, Maghemite (routing) and Dendrite are separate Oxide
  repositories that omicron pins by git revision.
- Languages: the Oxide-authored control plane services are written in Rust
  and are open source. Exceptions: the web console front end served by
  Nexus is TypeScript, and the switch data-plane program managed by
  Dendrite is P4.
- Third-party components: CockroachDB (Go) is the control plane database;
  ClickHouse and ClickHouse Keeper (C++) store telemetry, which, per the
  release 23 schema, is kept for 30 days with no customer setting to
  change that.

Narrative guidance: do not say "all control plane software is written in
Rust"; say the Oxide-authored services are, and name the exceptions and
third-party components where relevant.

Source: https://docs.oxide.computer/guides/architecture/control-plane
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/docs/control-plane-architecture.adoc
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/Cargo.toml
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/package-manifest.toml
Source: https://github.com/oxidecomputer/omicron/tree/rel/v23/oximeter/db/schema
Source: https://github.com/oxidecomputer/console

### DNS and time services

- External DNS: the control plane runs an authoritative DNS service for a
  domain the customer delegates to the rack. It serves the API and
  console hostname of each silo (`$silo.sys.<delegated domain>`).
- It is authoritative only. The rack does not provide a recursive or
  caching resolver: the customer names upstream recursive DNS servers at
  rack setup, which rack infrastructure uses and which are given to guest
  instances by DHCP.
- Time: the customer names upstream NTP servers (IP addresses or DNS
  names) at rack setup, and the control plane's NTP service uses them.
  How closely clocks are synchronized is not established here.

Oxide statements without a public source:

- The external DNS service does not implement DNSSEC.
- The external DNS service runs as multiple replicas on different sleds.

Source: https://docs.oxide.computer/guides/system/initial-rack-setup
Source: https://docs.oxide.computer/guides/architecture/networking#_integration_with_on_premises_domain_name_service

## API, Identity and Access

### API surface and TLS

- Customer and operator functions are exposed through one versioned HTTP
  API served by Nexus; the CLI, SDKs, Terraform provider and web console
  are its clients. Some maintenance actions are done only by Oxide Support.
- The API and console listen only on HTTPS (port 443). There is no
  plaintext HTTP listener and no redirect.
- Nexus terminates TLS with rustls and sets no protocol-version
  restriction, so the rustls defaults apply (TLS 1.3 and TLS 1.2); Oxide
  Computer Company confirms these are the versions in use. The
  certificate is chosen per silo hostname by SNI. There is no
  client-certificate authentication.
- Operations on resources require an authenticated principal. Reachable
  without authentication: login pages and login requests, the device
  authorization bootstrap endpoints, `/v1/ping`, static console assets.
- Where Nexus is a TLS client (`https://` webhook receivers and SAML
  metadata URLs), it validates the server against the root certificate
  set shipped in the system release (the `webpki-root-certs` package),
  not a set the customer defines.

Source: https://docs.oxide.computer/security/advisories/20261105-1 (Nexus as a TLS client)
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/src/app/mod.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/sled-agent/src/services.rs

### Authentication, sessions and tokens

- Credentials accepted: console session cookie, device access token (CLI
  and SDKs, OAuth 2.0 device flow), SCIM bearer token.
- A silo's identity mode is fixed at creation and cannot be changed: SAML
  with just-in-time (JIT) user creation, SAML with SCIM provisioning, or
  local-only. Any SAML 2.0 identity provider (IdP) can be used.
- SAML response checks: the assertion must be signed with an allow-listed
  algorithm, and the signature must meet SAML core section 5.4 (one
  reference, to the root element of the same document; only the
  enveloped-signature and exclusive-canonicalization transforms).
- The assertion signature is verified against a signing certificate in
  the IdP metadata configured for the silo. An IdP whose metadata contains
  no signing certificate is rejected when it is created.
- A console session token is 20 random bytes (160 bits), hex-encoded.
- With a metadata URL, Nexus fetches IdP metadata once, at IdP creation,
  using its standard outbound HTTP client configuration.
- Local-only silos, including the built-in `recovery` silo and its fleet
  admin user, use username and password only. Passwords are hashed with
  Argon2id; the only length rule is a 512-byte maximum. A silo or fleet
  admin sets passwords and can disable password login for a user; there is
  no self-service change.
- MFA: none built in. For SAML silos it is whatever the customer's IdP
  enforces.
- Console sessions end after 8 hours idle or 24 hours in total (the public
  API guide says eight hours). The values ship in the Nexus configuration;
  there is no setting. The cookie is `HttpOnly; SameSite=Lax; Secure`.
- Device tokens do not expire by default. A silo admin can set a maximum
  lifetime (`/v1/auth-settings`); it applies only to tokens created later.
- A user can list their own sessions and device tokens, delete a single
  device token, end the current session (`POST /v1/logout`), and
  invalidate all their sessions and tokens at once
  (`POST /v1/users/{user_id}/logout`). A silo admin can list and
  invalidate-all for any user in the silo.
- JIT-created users are not removed or deactivated when removed at the
  IdP; an admin must use the logout endpoint to end their access.

Narrative guidance: attribute MFA to the customer's IdP, never to Oxide.

Source: https://docs.oxide.computer/guides/operator/identity-providers
Source: https://docs.oxide.computer/guides/operator/silo-management
Source: https://docs.oxide.computer/guides/operator/faq
Source: https://docs.oxide.computer/api/guides/authentication
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/auth/src/authn/silos.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/passwords/src/lib.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/smf/nexus/multi-sled/config-partial.toml
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/auth/src/authn/external/session_cookie.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/auth/src/authz/omicron.polar
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/src/app/silo.rs (IdP signing certificate required)
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/src/app/session.rs (session token generation)

### Roles, provisioning and tenancy

- Roles are assigned to users or groups on the fleet, a silo or a project.
  The effective role is the strongest held at that level or above.
- Fleet: `admin` (all system resources, including silos), `collaborator`
  (create and manage silos), `viewer` (read-only). Only a fleet admin can
  assign fleet roles, run system updates, or manage alert receivers.
- Silo: `admin` (the silo and everything in it), `collaborator` (create
  and manage projects; grants project `admin` on every project),
  `limited_collaborator` and `viewer` (the same role on every project).
- Project: `admin` (full control, including role assignment),
  `collaborator` (all project resources, including VPC networking),
  `limited_collaborator` (instances, disks, snapshots, images and
  instance-level networking such as floating IPs; not subnets, routers,
  internet gateways or firewall rules), `viewer` (read-only).
- Silos are the tenancy boundary: each is isolated, with its own users,
  identity configuration, projects, quotas and TLS certificate. Fleet
  roles do not cascade into silos, except that a fleet admin can view and
  change any silo's role policy, quotas, IdP configuration and SCIM
  tokens. A silo can be created with a mapping that gives holders of its
  silo roles a fleet role.
- Quotas: each silo has vCPU, memory and storage quotas, set at creation
  and changeable by a fleet admin; requests over quota are refused.
  Projects have no quotas of their own.
- SCIM: in a SAML with SCIM silo the IdP creates, updates and deletes
  users and groups at `/scim/v2/Users` and `/scim/v2/Groups`, using bearer
  tokens managed by silo admins (or fleet admins for any silo). Setting
  `active: false` deletes the user's sessions and tokens and blocks login.
- SCIM limits: no `startIndex` or `count` pagination; `filter` only as
  exact match on `userName` or group `displayName`; group names unique per
  silo; no nested groups. Deactivated or deleted users (SCIM or JIT) keep
  SSH access to instances that already hold their keys.
- IP allow-list: one fleet-wide source-address allow-list for the API and
  console, default "any", not per silo. An update is rejected unless the
  caller's address is in the new list. The documented recovery from a
  lockout is the technician port API proxy, which remains reachable when
  the allow-list blocks access (see "Technician Port and Maintenance
  Access").

Source: https://docs.oxide.computer/guides/configuring-access
Source: https://docs.oxide.computer/guides/operator/resource-management
Source: https://docs.oxide.computer/guides/operator/identity-providers#scim
Source: https://docs.oxide.computer/guides/operator/faq
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/src/app/allow_list.rs

### Open gaps

- Per-session revocation (omicron#7816): one console session cannot be
  revoked on its own, only all of a user's sessions and tokens together.
- SAML assertion IDs are not tracked (omicron#7820).
- Local password policy (omicron#2307, omicron#2184): no minimum length or
  complexity, no expiry, no lockout or login rate limiting.
- Login banner: the API has no setting for a system use notification.
- MFA: none built in; delegated to the identity provider.

Narrative guidance: use this wording. Do not say users cannot list their
sessions, and do not describe omicron#2307 as a password rotation issue.

Source: https://github.com/oxidecomputer/omicron/issues/7816
Source: https://github.com/oxidecomputer/omicron/issues/7820
Source: https://github.com/oxidecomputer/omicron/issues/2307
Source: https://github.com/oxidecomputer/omicron/issues/2184

## Audit Logging

### Scope

Audited, one entry per request, for both success and failure (including
authorization denials):

- Every authenticated non-GET request to the external API, except those
  listed below. This includes resource changes, role and policy changes,
  silo authentication settings, quotas, IdP and local user management,
  certificates, the allow-list, update operations, support bundles, alert
  receivers, SCIM writes, device token issuance, token deletion and
  admin-forced logout.
- Local and SAML login attempts, successful and failed. These entries
  identify neither the user nor the session created.

Not audited:

- GET requests: all reads, including denied reads, reads of the audit log
  itself, serial console access and support bundle downloads.
- Named in the public guide: chunk uploads during disk import
  (`disk_bulk_write_import`; the surrounding start, stop and finalize
  calls are audited) and read-only timeseries queries sent by POST.
- Per the release 23 source: self-logout (`POST /v1/logout`); the
  unauthenticated device-authorization steps (`POST /device/auth`,
  `POST /device/token`); requests rejected at authentication (missing,
  invalid or expired credentials, other than login attempts).
- Session and token expiry, and the internal APIs between control plane
  services.
- Technician port unlock, switch zone SSH sessions and wicket sessions,
  which do not pass through the API (see "Technician Port and Maintenance
  Access"). API requests proxied through the technician port reach the
  same handlers and are audited like any other API request.

Narrative guidance: describe coverage as "authenticated, state-changing
requests to the external API, and login attempts, with the exceptions
listed here", naming the exceptions that matter to the control. Do not write "all API requests",
"all non-GET requests", "all authentication events" or "session and token
lifecycle events". Where a control covers privileged or maintenance
access, acknowledge the technician port paths.

Source: https://docs.oxide.computer/guides/operator/audit-log
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/tests/integration_tests/audit_log.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/src/context.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/src/lib.rs

### Records, retention and access

- Fields: entry ID, `time_started`, `time_completed`, `request_id`,
  `request_uri`, `operation_id`, `source_ip`, `user_agent`, `actor` (silo
  user ID and silo ID; SCIM client with silo ID; built-in user; or
  unauthenticated), `auth_method` (`session_cookie`, `access_token`,
  `scim_token`, or none), `credential_id`, and `result` (`success` with
  HTTP status; `error` with HTTP status, error code and message; or
  `unknown`).
- There is no resource identifier field and no request or response body.
  The affected resource appears only in the request URI and operation ID.
- Time stamps: `time_started` and `time_completed` are generated by the
  control plane (Nexus) from its system clock, are in UTC, and are
  returned by the API as RFC 3339 date-time strings with fractional
  seconds (the public guide's example shows `2025-08-12T00:03:45.439Z`).
  They are stored in a time-zone-aware database column. How closely
  control plane clocks are synchronized is not established here.
- Fail-closed creation: the entry is created before the operation runs; if
  it cannot be created, the request fails.
- If the outcome cannot be recorded, the operation still completes and a
  background task closes the entry with result `unknown` after four hours.
  Entries are visible only once complete and are immutable from then on.
  There is no API to modify or delete entries.
- Retention: 90 days from completion, then a background task permanently
  deletes the entry. The period ships in the Nexus configuration; there is
  no API, CLI or console setting.
- Access: the fleet `viewer` role, through the `audit_log_list` endpoint,
  the CLI, or the console's Audit Log page. There is no silo-scoped view
  and no filtering other than by time range.
- Export: the rack does not push audit records. The public guide directs
  customers who need longer retention to fetch the log at a regular
  interval and store it externally. Oxide publishes OpenTelemetry
  Collector receivers that collect audit logs from the API and export them
  to OpenTelemetry-compatible destinations.

Narrative guidance: narratives must not claim that a resource identifier
(UUID), a request body, or the content of a change is recorded. Retention
beyond 90 days, off-rack storage, review and correlation are customer
responsibilities that the API and the OpenTelemetry receivers support.

Source: https://docs.oxide.computer/guides/operator/audit-log
Source: https://docs.oxide.computer/api/audit_log_list
Source: https://docs.oxide.computer/guides/integrations/opentelemetry
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/smf/nexus/multi-sled/config-partial.toml
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/db-model/src/audit_log.rs (time stamps)

### Alerts and webhooks

- Webhooks are the only alert delivery mechanism; payloads carry an HMAC
  computed with a secret shared with the receiver.
- Alert classes: `probe` (liveness), `hardware.power_shelf.psu.insert`,
  `hardware.power_shelf.psu.remove`, and internal `test.*` classes. No
  audit, account, authentication, integrity or attestation events are
  delivered as alerts.

Narrative guidance: where a control expects automated notification of such
events, state the alert mechanism's actual scope rather than deny that it
exists; notification depends on customer tooling reading the audit log.

Source: https://docs.oxide.computer/guides/alerts/overview
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/types/src/alert.rs

## Network Isolation

- OPTE (Oxide Packet Transformation Engine) runs in the host OS on every
  sled, between instances and the physical network interfaces. It does
  firewalling, routing, NAT, and encapsulation and decapsulation, so VPC
  boundaries are enforced outside the guest.
- Traffic between VPCs must go through external IP addresses.
- Every instance network interface has a dedicated stateful firewall that
  by default denies inbound and allows outbound traffic.
- A new VPC starts with three inbound allow rules at priority 65534:
  `allow-internal-inbound` (from within the VPC), `allow-ssh` (TCP port 22
  from anywhere) and `allow-icmp` (ICMP from anywhere).
- VPC traffic between sleds is encapsulated (Geneve) but not encrypted;
  OPTE implements no encryption of overlay traffic. For control plane
  traffic on the underlay, see "Storage and Encryption".

Narrative guidance: say "in the host OS on each sled", not "at the
hypervisor layer". Do not claim the platform encrypts traffic between
guests; that is a customer responsibility. For boundary protection, note
that the default rules admit SSH and ICMP from any source.

Source: https://docs.oxide.computer/guides/architecture/networking
Source: https://docs.oxide.computer/guides/configuring-guest-networking
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/defaults/src/lib.rs
Source: https://github.com/oxidecomputer/opte

## Storage and Encryption

Two separate mechanisms protect data at rest and they cover different
data. Crucible encrypts distributed-disk blocks in the application layer.
ZFS native encryption protects control plane datasets. Local disks are
covered by neither.

### Distributed disks

- Crucible is Oxide's distributed block storage service. A distributed
  disk is kept as three copies, one on each of three different sleds. Each
  copy (a region) is served by a Crucible "downstairs" from an OpenZFS
  dataset on a U.2 drive.
- Encryption is always on and cannot be disabled. Nexus marks every region
  as encrypted, and a downstairs refuses a client whose encryption setting
  does not match.
- Cipher: AES-256-GCM-SIV, applied to each block separately with a fresh
  random 96-bit nonce per write. The nonce and authentication tag are
  stored with the block. No associated data is supplied, so the cipher
  authenticates block contents but not block position or freshness.
- Where: the Crucible "upstairs" runs inside the instance's Propolis
  process and encrypts each block before it leaves the instance's sled.
  The downstairs are never given the key. They store ciphertext plus, in
  plaintext, each block's nonce, tag, and integrity hash and the region
  metadata. Omicron excludes Crucible datasets from ZFS encryption to
  avoid double encryption.
- Plaintext exists in the guest, in Propolis, and in the Crucible Pantry
  when the control plane performs an upstairs operation (for example a
  snapshot of a detached disk, or an import). During disk import the
  plaintext also passes through Nexus and travels from Nexus to the Pantry
  over unencrypted HTTP on the underlay.
- Keys: Nexus generates a random 256-bit key when a disk is created. The
  key is stored unwrapped in the control plane database and passed
  between control plane services on the underlay without transport
  encryption. At rest it is protected only by ZFS encryption of the
  database datasets.
- Key sharing: a snapshot's volume record is a copy of the disk's and
  holds the same key. Images are created from snapshots. A disk created
  from a snapshot or image gets a new key for newly written blocks but
  embeds the source volume, with the source key, as its read-only parent.
- In the release 23 source there is no key rotation or rekey operation
  for distributed disks.
- In transit between the instance's sled and the replica sleds the data
  is protected by the block encryption only. Crucible does not use TLS:
  the connection is plain TCP, unauthenticated, and protocol metadata is
  visible on the underlay.
- Snapshots are point-in-time and copy-on-write, implemented as ZFS
  snapshots of each replica's region dataset.

Narrative guidance: scope storage-encryption claims to distributed disks.
Say the data is encrypted in transit, not that the channel is. Do not say
"encrypted at the ZFS layer" for customer disks, do not say "a unique key
per disk" without the snapshot and derived-disk sharing, and do not claim
key rotation.

Source: https://docs.oxide.computer/guides/architecture/os-hypervisor-storage
Source: https://docs.oxide.computer/guides/managing-disks-and-snapshots
Source: https://rfd.shared.oxide.computer/rfd/0177 (cipher choice and upstairs encryption only)
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/src/app/sagas/disk_create.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/src/app/sagas/snapshot_create.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/src/app/crucible.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/src/app/disk.rs
Source: https://github.com/oxidecomputer/crucible (rev ad8a317: upstairs/src/lib.rs, downstairs/src/lib.rs)
Source: https://github.com/oxidecomputer/propolis (rev 93e04e1: lib/propolis/src/block/crucible.rs)

### Local disks

- A local disk is a single copy on the sled where the instance runs. It is
  not served through Crucible and does not support snapshots.
- Local disks have no built-in encryption. They are raw ZFS volumes in a
  dataset outside the encrypted hierarchy, so the trust quorum does not
  protect them either. Customers must encrypt in the guest or application.

Narrative guidance: every statement that storage is encrypted at rest
must state the local-disk exception and assign it to the customer.

Source: https://docs.oxide.computer/guides/managing-disks-and-snapshots
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/common/src/api/internal/shared/mod.rs

### Integrity and repair

- Each U.2 drive is its own single-device ZFS pool. ZFS checksums detect
  corruption of data at rest, but ZFS holds no redundant copy from which
  to repair it.
- Redundancy and repair come from Crucible, which keeps three replicas and
  reconciles and repairs them. The upstairs also verifies the
  authentication tag of every block it reads and does not return data
  that fails verification.
- In the release 23 source the control plane does not schedule ZFS
  scrubs. In Crucible, "scrub"
  means copying blocks from a read-only parent into a derived disk.

Narrative guidance: do not claim periodic or continuous scrubbing, and do
not attribute repair to ZFS.

Source: https://rfd.shared.oxide.computer/rfd/0177
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/illumos-utils/src/zpool.rs
Source: https://github.com/oxidecomputer/crucible (rev ad8a317: upstairs/src/client.rs)

### Control plane data at rest

- Every U.2 drive has an encrypted root dataset using ZFS native
  encryption (AES-256-GCM). Datasets beneath it inherit encryption: zone
  root filesystems, the control plane database (CockroachDB, five
  replicas), ClickHouse telemetry, internal and external DNS, and debug
  data. A zone checks that a dataset is encrypted when mounting it and
  errors if it is not.
- Keys: each sled derives one 256-bit key per U.2 drive per trust quorum
  epoch, with HKDF-SHA3-256, from the rack secret and rack- and
  drive-specific inputs. The derived key is not stored persistently. When
  a new epoch commits, the sled rekeys each encrypted root dataset.
  For the rack secret itself see "Trust Quorum".
- Not ZFS-encrypted on U.2 drives: Crucible regions (already ciphertext)
  and local-disk storage.
- Not encrypted at all: the M.2 boot drives. They hold boot images, sled
  and service configuration, the trust quorum share store, and staged
  crash dumps.

Source: https://rfd.shared.oxide.computer/rfd/0301
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/key-manager/src/lib.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/illumos-utils/src/zfs.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/sled-storage/src/dataset.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/common/src/api/internal/shared/mod.rs

### External interfaces

- The API and web console are HTTPS only; for the listener and protocol
  details see "API, Identity and Access".
- Certificates are customer-supplied and per silo; Nexus selects one by
  the requested hostname. The first certificate and private key are
  uploaded at rack setup, which cannot proceed without one. Later
  certificates are managed through the API by silo administrators. The
  customer is responsible for issuance, renewal, and replacement.
- The private key is uploaded to the rack and stored in the control plane
  database, where Nexus reads it.

Source: https://docs.oxide.computer/guides/system/initial-rack-setup
Source: https://docs.oxide.computer/guides/operator/faq
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/src/app/mod.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/sled-agent/src/services.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/schema/crdb/dbinit.sql

### Internal communications

- Control plane services talk to each other on the underlay over HTTP
  without TLS and without authentication. This covers the Nexus internal
  API and Nexus calls to sled agents, the management gateway, Crucible
  agents, the Crucible Pantry, and Propolis.
- The control plane database (CockroachDB) runs in insecure mode: no TLS
  and no client authentication.
- These channels are not protected by cryptography. They rely on the
  underlay being separate from customer and guest networks; this file
  does not document how that separation is enforced (see "Not
  Established by This Reference").
- Trust quorum share exchange and sled-agent bootstrap requests between
  sleds use sprockets: mutually authenticated TLS 1.3 with attestation.
  See "Trust Quorum".
- Guest overlay traffic between sleds is not encrypted by the rack. See
  "Network Isolation".
- The external API is also reachable through the technician port, using
  the same TLS configuration. See "Technician Port and Maintenance
  Access".

Narrative guidance: do not claim encryption or mutual authentication of
internal control plane traffic. Describe the protection as network
isolation plus the specific exceptions above.

Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/src/lib.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/networking/src/sled_client.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/src/app/sagas/common_storage.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/smf/cockroachdb/method_script.sh
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/trust-quorum/src/established_conn.rs

### Key custody

- Distributed-disk keys: generated by Nexus; stored unwrapped in the
  control plane database; used by Propolis and the Pantry. Held by the
  rack, not by the customer and not by the trust quorum. Their only
  protection at rest is the ZFS encryption of the database datasets,
  whose keys derive from the rack secret.
- ZFS dataset keys: derived on each sled from the rack secret; not stored
  persistently. Held by the rack through the trust quorum.
- Rack secret: see "Trust Quorum".
- External TLS private keys: generated by the customer outside the rack;
  uploaded and stored in the control plane database; used by Nexus. The
  customer controls issuance and replacement, but the rack holds a copy.
- Local disks: no rack-managed key. Any encryption key is the customer's.

Narrative guidance: say where each key is generated and stored, and
nothing more. Do not claim that keys never leave the rack, that disk keys
are managed by the trust quorum, or that the customer has sole custody of
any key the rack stores.

Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/schema/crdb/dbinit.sql

## Trust Quorum

### Purpose and threat model

The trust quorum protects data at rest on the U.2 drives against physical
theft, without passwords or any other human intervention when a sled starts
or the rack cold boots. It does this by splitting a rack secret across the
sleds so that storage unlocks only when a threshold (K) of them cooperate.

- Protects against: theft of U.2 drives from any number of sleds, or of
  whole sleds, where the attacker obtains fewer than K members' key shares.
- Theft threshold: each sled's shares are stored unencrypted on its M.2
  drives and are not sealed to the RoT. Protection holds only while fewer
  than K members' M.2 drives (shares of the same epoch) are obtained. The
  threshold is K shares, not possession of K working sleds.
- Not covered: data outside ZFS encryption on the U.2 drives. Crucible
  regions rely on Crucible's own encryption, and local disks are not
  encrypted at rest (see "Storage and Encryption").
- Availability: if fewer than K shares survive, everything encrypted under
  the rack secret is lost (RFD 238).

Narrative guidance: state the threshold as "the M.2 drives of K or more
members". Do not write "a majority of sleds", and do not say shares are
encrypted, wrapped, or hardware-sealed.

Source: https://rfd.shared.oxide.computer/rfd/0238
Source: https://rfd.shared.oxide.computer/rfd/0301

### Mechanism

- The rack secret is 32 random bytes, split with Shamir secret sharing
  over GF(2^8) into N shares, one per member sled (3 to 32 members).
- Threshold K = N/2 + 1 with integer division. K is recomputed whenever
  membership changes. A threshold below 2 is rejected, so no single sled can
  reconstruct the secret.
- Each configuration of the quorum has an epoch number and its own freshly
  generated rack secret.
- Stored on each sled, unencrypted, on both M.2 drives: the sled's share
  for each epoch it has prepared, and the configurations it knows. A
  configuration holds the member list, the threshold, and SHA3-256
  digests used to check received shares.
- There is no wrapped disk key on the M.2 drives. Each sled derives the
  ZFS keys for its U.2 drives from the rack secret on demand with
  HKDF-SHA3-256, one key per drive per epoch (see "Storage and
  Encryption").

Source: https://rfd.shared.oxide.computer/rfd/0238
Source: https://rfd.shared.oxide.computer/rfd/0301
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/trust-quorum/gfss/src/shamir.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/key-manager/src/lib.rs

### Rack unlock

- On boot a sled starts with its own share and requests shares from the
  other members of the latest committed configuration over sprockets
  connections on the bootstrap network. It needs K-1 more.
- Each received share is checked against the digest recorded in the
  configuration. At K shares the sled reconstructs the rack secret,
  derives its drive keys, and unlocks its encrypted U.2 datasets.
- Below threshold the sled cannot decrypt those datasets. No control plane
  zones start on it and it does not configure or join the underlay
  network. Sled agent keeps retrying; nothing is unlocked in the meantime.

Narrative guidance: narratives must not claim erasure or zeroization of
key material.

Source: https://rfd.shared.oxide.computer/rfd/0238
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/trust-quorum/protocol/src/rack_secret_loader.rs

### Sprockets

All trust quorum messages, including share exchange, travel over sprockets
connections between sled agents. See "Hardware Root of Trust" for sled
identity and attestation mechanics.

- Mutual TLS 1.3 only (X25519, ChaCha20-Poly1305, Ed25519 certificates);
  a client certificate is mandatory. Each side's chain must verify to a
  root certificate configured in sled agent. The TLS private key stays in
  the RoT, which signs on the host's request.
- Attestation exchange: each side sends a fresh 32-byte nonce; the peer
  returns its attestation certificate chain, its measurement log, and an
  RoT signature over the log and nonce. The chain and signature are
  verified, and the platform identity in the attestation chain must match
  the one in the TLS chain.
- Measurement appraisal: the measurements the peer reports (from its
  attestation chain and measurement log) are compared with the appraising
  sled's own reference measurements shipped with the release. Every
  reported measurement must be in the reference set.
- What is appraised: RoT and SP firmware only. Host OS and control plane
  software are not measured and are not part of this appraisal.
- Enforcement: release 23 sled agent configurations enforce appraisal.
  Any failed step aborts the handshake.
- A refused peer has no connection, so it cannot exchange trust quorum
  messages or obtain shares. A connected peer's identity (part and serial
  number) is taken from its verified chain, not from what it asserts.

Narrative guidance: narratives may say that a sled reporting RoT or SP
firmware measurements outside the reference set is refused and receives no
key shares. Do not say the host OS or control plane software is attested.

Source: https://rfd.shared.oxide.computer/rfd/0238
Source: https://rfd.shared.oxide.computer/rfd/0605
Source: https://github.com/oxidecomputer/sprockets/blob/a233079/tls/src/client.rs
Source: https://github.com/oxidecomputer/sprockets/blob/a233079/tls/src/server.rs
Source: https://github.com/oxidecomputer/dice-util/blob/4a39ef08/verifier/src/lib.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/smf/sled-agent/gimlet/config.toml
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/sled-agent/measurements/src/lib.rs

### Membership and reconfiguration

- Passing sprockets does not entitle a sled to shares. On every share
  request the responder checks the requester's attested identity against
  the member list. A non-member gets an `Expunged` reply and no share. A
  member asking for a superseded epoch gets the newer configuration and no
  share. A responder answers from the configurations it has learned so far.
- Initial setup commits the first configuration only after every member
  has stored its share.
- Adding or removing a sled is an explicit reconfiguration coordinated by
  Nexus: a new epoch, a new rack secret, new shares for the new member
  set, and K recomputed. Nexus commits once at least K members have
  acknowledged. Sleds then rekey
  their U.2 datasets to the new epoch.
- Removed sleds receive no share of the new secret. A sled that learns it
  was expunged records that permanently and ignores further trust quorum
  messages; its storage must be wiped before it can be used again.
- Adding sleds: operator API `POST
  /v1/system/hardware/racks/{rack_id}/membership/add`, with `.../abort`
  and a `GET .../membership` status view. These endpoints are tagged
  experimental. Add and abort calls are recorded in the audit log.
- In the release 23 source, removing a sled from the quorum is not in the
  operator API, so it does not produce an audit log entry.
- Sled agent writes connection, appraisal-failure, share-request, and
  expungement events to its service log. Protocol alarms (for example
  failed rack secret reconstruction) are not surfaced through the
  operator API.
- A removed sled's M.2 drives still hold its shares for earlier epochs.
  RFD 238 says they "should" be completely wiped before the drives or the
  sled are reused. That is RFD guidance, not an enforced mechanism.
- The reconfiguration protocol has a TLA+ specification in the omicron
  repository; RFD 238 gives it precedence over the RFD prose.

Narrative guidance: treat trust quorum logs and alarms as internal
diagnostics, not customer-facing audit records or alerts, and treat M.2
wiping at decommission as a procedure, not a system function.

Source: https://rfd.shared.oxide.computer/rfd/0238
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/external-api/src/lib.rs
Source: https://docs.oxide.computer/api/rack_membership_add_sleds

### Review status

RFD 238 recommends independent review of the secret sharing
implementation and of the trust quorum protocol; this reference does not
establish that either has been done.

Narrative guidance: do not state that the trust quorum or its secret
sharing code has been independently audited or validated.

Source: https://rfd.shared.oxide.computer/rfd/0238
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/trust-quorum/gfss/src/lib.rs

## Technician Port and Maintenance Access

Each switch has two technician ports on its front panel. They are used for
initial rack setup, Oxide support access, offline update, and customer
recovery from an allow-list lockout. A host on a technician port reaches
several services with different authentication requirements, set out
below.

### Physical and remote access

- The rack is installed on premises in a facility the customer controls
  (its own data center or a colocation site).
- Not requiring physical access: normal system update (uploaded and
  driven through the API and CLI) and storage unlock at cold boot, which
  needs no human intervention (see Trust Quorum).
- Requiring physical access: hardware replacement (sleds, storage
  devices, optical transceivers) and cabling a host to a technician port.
- The technician ports need not be connected for the rack to operate. At
  least one connection per switch is needed for initial rack setup.
- The host on a technician port is a laptop on site or a
  customer-provided jumpbox cabled to one technician port on each switch.
  Public docs call for the jumpbox for initial setup and for remote
  support access. In a customer-initiated support engagement the
  customer provisions access and jumpbox accounts, Oxide staff SSH from
  the jumpbox to the rack, and the customer revokes the access
  afterwards. Use of a technician port can therefore be remote.
- Public docs state that no phone-home feature or background process
  exports data outside the rack. The rack makes no connection back to
  Oxide Computer Company.

Oxide statements without a public source:

- Oxide Computer Company has no standing access to customer
  environments. It can reach a rack only through access the customer
  provides.
- Oxide Computer Company does not perform maintenance without a
  customer-initiated support engagement.
- The component has no customer setting that disables the technician
  ports.

Narrative guidance: these points matter to customers; state them wherever
remote access, non-local maintenance or external connections are in scope
(AC-17, MA-4, SC-7, CA-3). State the absence of phone-home as a documented
fact, and attribute the statements in the list above to Oxide Computer
Company. Do
not say technician port use always requires physical presence. Say it
requires a host attached to a technician port, and that the customer
controls physical access to the ports and network access to any jumpbox
cabled to them.

Source: https://docs.oxide.computer/guides/system/system-setup
Source: https://docs.oxide.computer/guides/system/rack-installation
Source: https://docs.oxide.computer/guides/operator/hardware-maintenance
Source: https://docs.oxide.computer/guides/operator/system-update
Source: https://docs.oxide.computer/guides/facilities/physical-installation
Source: https://rfd.shared.oxide.computer/rfd/0238

### What a technician port can reach

- The technician ports attach to the management network switch in each
  Sidecar. The switch's service processor (SP) puts them in a locked
  VLAN configuration every time it starts.
- Locked, a technician port can reach only the switch zone (through the
  Tofino) and that switch's own SP. It cannot reach any other SP (sleds,
  the peer switch, power shelf controllers). The SP enforces the lock in
  the VLAN configuration and by refusing management messages from the
  technician port VLANs.
- Services reachable on a locked port, with their authentication:
  - Wicket, over SSH: no authentication (see Wicket).
  - Administrative shell for Oxide support, over SSH: Oxide support
    hardware token key (see Support SSH).
  - Control plane API proxy over HTTPS: ordinary API credentials (see
    API proxy).
  - The switch's own SP: accepts only discovery and the unlock exchange,
    plus a narrow update-support message.
- Per the release 23 source, no other account can log in to the switch
  zone over SSH; root login, forwarding and tunnels are disabled.
- Unlocking (see Management network unlock) adds direct reachability to
  the other SPs. It does not gate the three switch zone services above.

Narrative guidance: describe the lock as protecting direct access to the
management network, not as gating all technician port services. Do not
describe the technician port as having only authenticated paths.

Source: https://docs.oxide.computer/guides/architecture/networking
Source: https://github.com/oxidecomputer/hubris/blob/all-sp-v1.81.1/drv/vsc7448/src/lib.rs
Source: https://github.com/oxidecomputer/hubris/blob/all-sp-v1.81.1/task/monorail-server/src/bsp/sidecar_bcd.rs
Source: https://github.com/oxidecomputer/hubris/blob/all-sp-v1.81.1/task/control-plane-agent/src/mgs_sidecar.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/wicket/zone-etc/ssh/sshd_config

### Wicket

- Wicket is the text interface for rack setup and recovery. It is reached
  over SSH from a host on a technician port and requires no credential;
  the session is confined to the wicket tool and does not give a shell.
- Wicket works on a locked port and without API credentials. It acts
  through services inside the switch zone, which reach every SP over the
  management network independently of the technician port lock.
- Without any credential, a wicket session can:
  - view rack inventory: the identity, state and firmware versions of
    every sled, switch and power shelf controller;
  - upload an update repository and start, abort or clear an offline
    update of any sled, switch or power shelf controller (SP, root of
    trust and host OS);
  - power on, power off or power-reset any sled, switch or power shelf
    controller;
  - before the rack is initialized only: enter the rack setup
    configuration (network settings, TLS certificate and private key,
    recovery user password) and start rack setup;
  - run uplink preflight checks.
- Once the rack is initialized, rack setup cannot be run again, and in
  the release 23 source wicket exposes no rack reset operation.
- The offline update path does not check the uploaded repository against
  the trust root used for API-driven updates. See Software Update for
  what it does verify.
- Public docs describe offline update as performed by Oxide Support, on
  site or remotely through the customer's jumpbox, and describe operator
  use of the technician ports as under close supervision of Oxide. The
  allow-list recovery procedure (see API proxy) is the documented
  customer-run exception.

Narrative guidance: the wicket path has no logical access control. Its
safeguard is the customer's physical control of the technician ports and
network control of anything cabled to them; say so wherever technician
port access, maintenance tools, or update integrity is discussed. Do not
credit support tokens, the unlock protocol, or API authentication as
protecting it.

Source: https://docs.oxide.computer/guides/system/initial-rack-setup
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/wicket/zone-etc/ssh/sshd_config
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/zone-setup/src/switch_zone_user.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/wicket/src/cli/command.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/wicketd-api/src/lib.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/wicketd/src/update_tracker.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/sled-agent/src/bootstrap/rack_ops.rs

### Management network unlock

- Unlocking is a challenge-response exchange between the client on the
  technician port and that switch's SP. When the switch's root of trust
  is in the release lifecycle state, the client must sign the challenge
  with a key in the SP's trusted set, which holds the Oxide support
  hardware-token keys (see Support credentials).
- Unlock is per switch, is limited to one hour, and reverts to locked
  without operator action when the duration elapses or the SP restarts. A
  trusted client can also re-lock explicitly.
- Unlocked, that switch's technician ports can reach every SP on that
  switch's management network and send them the full management protocol
  (power control, firmware update, host serial console).
- Trusted keys: the support token public keys are built into the switch
  SP firmware image.

Oxide statements without a public source:

- Every customer rack ships with its roots of trust in the release
  lifecycle state, so unlock on a customer rack requires the signature.

Narrative guidance: describe unlock on a customer rack as requiring a
signature from a trusted key, and attribute the shipped lifecycle state
to Oxide. Do not present the signature requirement as unconditional in
the firmware.

Source: https://github.com/oxidecomputer/hubris/blob/all-sp-v1.81.1/task/control-plane-agent/src/mgs_sidecar.rs
Source: https://github.com/oxidecomputer/hubris/blob/all-sp-v1.81.1/task/control-plane-agent/build.rs
Source: https://github.com/oxidecomputer/hubris/blob/all-sp-v1.81.1/app/sidecar/base.toml
Source: https://github.com/oxidecomputer/hubris/blob/all-sp-v1.81.1/drv/vsc7448/src/lib.rs
Source: https://docs.oxide.computer/release-notes/system/23 (SP firmware version 1.81.1)

### Support SSH

- An administrative shell for Oxide support in the switch zone accepts
  only public-key authentication with Oxide hardware-token keys; password
  login is disabled.
- The shell is fully privileged in the switch zone. Oxide support uses it
  to run diagnostic and recovery tooling.
- The authorized keys ship in the system release and cannot be changed at
  run time. Every key authorized for support SSH in release 23 is also
  trusted by the SP for unlock.

Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/wicket/zone-etc/ssh/sshd_config
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/zone-setup/src/bin/zone-setup.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/package-manifest.toml
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/smf/switch_zone_setup/README.md
Source: https://github.com/oxidecomputer/hubris/blob/all-sp-v1.81.1/support/support_tokens/README.md

### API proxy

- A service in the switch zone relays TCP connections arriving on the
  technician port interfaces to a dedicated control plane listener that
  serves the external API. The relay does not terminate TLS.
- It is the same API: HTTPS with the customer's external TLS
  certificate, the same API tokens and sessions, the same authorization.
- The operator FAQ documents it for recovery from an IP allow-list
  lockout: a fleet administrator on a technician port can reach the API
  with existing credentials to correct the allow-list.
- Requests through the proxy are audit-logged like any other API request
  (see Audit Logging for coverage).

Narrative guidance: this path uses customer credentials and is
documented for customer use; do not describe the technician port as
SSH-only or reserved to Oxide support.

Source: https://docs.oxide.computer/guides/operator/faq
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/wicketd/src/nexus_proxy.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/src/lib.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/src/app/allow_list.rs

### Support credentials

Supported by public sources:

- Private keys for support access are held on hardware tokens. Oxide
  staff cannot extract them and use them through SSH agent forwarding.
- The matching public keys are preloaded on the rack and managed by
  Oxide; they are usable only from a host the customer has attached to a
  technician port.
- The key set is fixed in the switch SP firmware image (unlock) and the
  switch zone image (support SSH). There is no runtime interface to
  change it; adding or revoking a key requires a software update.

Oxide statements without a public source:

- A PIN is required to use a key on a token.
- Each token is individually assigned to a named support person and
  tracked.

Narrative guidance: do not say every technician port access involves a
hardware token. Tokens protect support SSH and unlock only; wicket
needs no credential and the API proxy uses customer API credentials.
Attribute the second list to Oxide, not to public documentation.

Source: https://docs.oxide.computer/guides/system/system-setup
Source: https://github.com/oxidecomputer/hubris/blob/all-sp-v1.81.1/support/support_tokens/README.md
Source: https://github.com/oxidecomputer/hubris/blob/all-sp-v1.81.1/task/control-plane-agent/build.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/package-manifest.toml

### Audit and monitoring

- Recorded in the audit log: API requests through the technician port
  proxy, on the same terms as any other external API request.
- Not recorded in the audit log: wicket sessions and the actions taken in
  them (offline update, power control, rack setup), support SSH
  sessions, and management network unlock and re-lock. The audit log is
  written only by external API request handlers.
- The switch SP keeps no audit record of unlock and re-lock events.

Narrative guidance: scope "bypasses the audit log" to wicket, `support`
SSH and unlock; never apply it to the API proxy. Narratives for AC-6(9),
AC-17, AU-12, AU-14, MA-4 and SI-4 must state this gap. Safeguards that
may be cited: customer control of physical and network access to the
ports (the only one covering wicket), hardware-token keys for `support`
SSH and unlock, and time-bounded unlock that fails locked.

Source: https://docs.oxide.computer/guides/operator/audit-log
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/src/context.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/src/lib.rs
Source: https://github.com/oxidecomputer/hubris/blob/all-sp-v1.81.1/task/control-plane-agent/src/mgs_sidecar.rs

## Code Signing and Supply Chain

### Signing hierarchy

Oxide keeps persistent signing keys for two purposes: RoT code signing and
platform identity. Both are distinct from the per-build TUF metadata key
(see "Software Update").

- **RoT code-signing roots.** For each platform there are four
  self-signed RSA-4096 root CAs: Release A, Release B, Development A,
  Development B. The offline keystore's published specifications cover
  the Gimlet sled, Sidecar switch and PSC; Cosmo has its own set of four
  (RFD 585). For how the
  RoT uses the root key table, see "Hardware Root of Trust".
- **Online signers.** Each root issues certificates for online signing
  keys. These are end-entity code-signing certificates (not CAs), and a
  certificate policy identifier distinguishes release from development
  code signing.
- **What is signed.** RoT Hubris images and the bootleby stage0 bootloader.
  The release 23 production signing manifest lists `oxide-rot-1-1.0.38`
  and `bootleby-production-1.4.1`. The control plane offers a device only
  RoT and bootloader images whose root key table hash matches its own.
- **Platform identity.** A single ECDSA P-384 root CA. It certifies an
  intermediate CA, which certifies each device's platform identity key
  during manufacturing; the RoT's attestation key chain is certified by
  this PKI.
- **Signed directly by the offline roots:** each root's own certificate,
  the online signer certificates, the platform identity intermediate, and
  RoT debug credentials. RoT debug access is disabled without a
  credential signed by one of the roots.
- **SP firmware is outside this hierarchy.** The keystore defines no SP
  signing purpose; in Hubris only RoT (LPC55) applications have a signing
  configuration; the production signing manifest lists only the RoT image
  and bootleby. No signature on an SP image is verified at update (the
  control plane's SP update path and the SP's update server check none) or
  at boot (the RoT measures the SP and does not gate its boot); Oxide
  Computer Company confirms this. SP image
  integrity rests on the SHA-256 in the TUF metadata and on RoT
  measurement.

Narrative guidance: do not claim that an Oxide signature protects SP
firmware. Write "no signature on SP firmware is verified at update or
boot" and rely on TUF hashes and RoT measurement.

Source: https://github.com/oxidecomputer/offline-keystore (`specs/README.md`, `specs/production/`, `data/`, `src/ca.rs`, `docs/debug-credentials.md`; a5724b30)
Source: https://rfd.shared.oxide.computer/rfd/0605
Source: https://github.com/oxidecomputer/dice-util (`README.md`; 22178824)
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/tools/permslip_production
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/dev-tools/releng/src/hubris.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/reconfigurator/planning/src/mgs_updates/rot.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/mgs-updates/src/sp_updater.rs
Source: https://github.com/oxidecomputer/hubris (`app/oxide-rot-1/app.toml`, `drv/stm32h7-update-server/src/main.rs`; 4a7567b4)

### Offline roots and ceremonies

Supported by public sources:

- The root keys of both hierarchies are generated and held in hardware
  security modules managed by an offline keystore.
- Root keys are backed up in wrapped form. Root key backups cannot be
  restored by a single person.
- The keystore collects the module's attestation certificate for each
  generated key, as evidence that the key was generated inside it.
- Operations on the roots are performed in key ceremonies using public
  tooling. A fixed script and declarative specification files determine
  which keys are generated and which requests are signed.
- The tooling records the full terminal session and computes digests of
  ceremony inputs and outputs.

Oxide statements without a public source:

- The offline keystore is physically protected.
- Root keys never come online and are used only during ceremonies.
- Multiple human witnesses observe each ceremony and sign attestations to
  the actions performed.
- Ceremony inputs, outputs, scripts and machine logs are retained
  permanently.
- Ceremony records are available to customers and assessors through Oxide
  support under confidentiality arrangements.
- Customers cannot replace the RoT code-signing roots or the platform
  identity root.

Narrative guidance: cite the first list as fact. Present the second list
as Oxide Computer Company's statements about its own practice. Say
"physically protected offline keystore" and nothing more specific: do not
state or hint at where it is kept, what kind of facility holds it, who has
access, when or how often ceremonies take place, or who attends. Do not
name the module make or model, share counts, or media handling. Do not
compare the ceremonies to any other organisation's.

Source: https://github.com/oxidecomputer/offline-keystore (a5724b30)

### Online signing service

- An online signing service holds the online signing keys certified by the
  offline roots and performs routine signing. The roots are held
  in the offline keystore, not in the service.
- The release build downloads the images named in the signing manifests
  from the service, pinned by the SHA-256 of each manifest.
- Public manufacturing tooling can submit platform identity certificate
  requests to the service, where signing is "governed by a batch of
  approvals".
- Oxide's incident response plan places signing and trust infrastructure,
  including the online signing service, within its supply chain scope.
- The service, its key storage and its approval rules are not public.

Narrative guidance: do not describe approval requirements for RoT image
signing, how the service protects keys, or recovery after a compromise.

Source: https://rfd.shared.oxide.computer/rfd/0733
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/docs/releng.adoc
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/dev-tools/releng/src/hubris.rs
Source: https://github.com/oxidecomputer/dice-util (`dice-mfg/src/main.rs`; 22178824)

### Open source scope

- Public repositories: bootleby (RoT stage0), Hubris (RoT and SP
  firmware), phbl (host boot loader), Helios (host OS), Propolis (VMM),
  Omicron (control plane), Crucible (storage), OPTE (network fabric).
- Not all build inputs are public. At the Helios commit pinned by release
  23, the Helios README marks a small number of non-public build inputs,
  including third-party firmware. The online signing service is not
  public.
- Proprietary third-party firmware is present: AMD CPU firmware (RFD 605
  calls the PSP code "AMD proprietary" and says its measurements cannot be
  verified back to source) and Chelsio T6 NIC firmware in the host image.
  The switch data-plane program is compiled with the vendor's Tofino SDE.
  No public source gives a complete list.

Narrative guidance: never write "all software is open source". Write that
the principal Oxide-authored components are open source, and name the
third-party firmware exceptions when the control concerns firmware.

Source: https://github.com/oxidecomputer/helios (`README.md`, `image/templates/sled/zfs.json`; 4e9eabf1)
Source: https://rfd.shared.oxide.computer/rfd/0605
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/.github/buildomat/jobs/tuf-repo.sh
Source: https://github.com/oxidecomputer/dendrite (`README.md`; 24750281)

### Build provenance

- Build inputs are pinned in the public Omicron repository:
  `tools/*_version` and `tools/*_checksums` (downloaded components),
  `tools/pins.toml` (Helios commit), `package-manifest.toml` (commit and
  SHA-256 of separately built components), `tools/permslip_production`
  (SHA-256 of the production signing manifest), and `Cargo.lock` (checked with `--locked`).
- The release engineering document says the process is scripted, runs on
  each commit, and can be run locally with `cargo xtask releng`. It does
  not claim reproducible builds. A party outside Oxide cannot complete a
  release build: it needs the signing service and non-public repositories,
  and the TUF metadata is signed with a key generated during the build.
- Release builds run on Oxide's buildomat CI, which publishes the
  repository archive with its SHA-256.
- Reproducible builds are described only for Hubris. RFD 605: "We have
  done significant work to make reproducing Hubris (RoT and SP) images
  trivial but additional work will be required for up-stack components."
  At the cited revision, Hubris CI builds an RoT image and an SP image in
  two environments and compares them (noting this is not a guarantee), and
  release builds receive GitHub build-provenance attestations.
- With public tools a customer can: read the source and pins; check the
  bundle hash and TUF metadata (see "Software Update"); strip the
  signature from a shipped RoT image (`hubedit`) to compare it with an
  image built from source; and check that an RoT image's certificate chain
  matches the root key table hash it reports, or verify it against CMPA
  and CFPA contents (`hubedit verify`, `lpc55_sign`). No public source
  reports a shipped image having been reproduced outside Oxide.
- A customer cannot, from public sources alone: anchor an RoT image to
  Oxide, because no public source publishes the production root
  certificates or expected root key table hash; reproduce the host OS,
  control plane or the release bundle bit for bit; or inspect ceremony
  records, which are not published.

Narrative guidance: write "pinned by version and hash", not
"reproducible", except for Hubris images with the RFD 605 qualification.

Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/docs/releng.adoc
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/tools/pins.toml
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/package-manifest.toml
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/.github/buildomat/jobs/tuf-repo.sh
Source: https://rfd.shared.oxide.computer/rfd/0605
Source: https://github.com/oxidecomputer/hubris (`.github/workflows/ci.yml`, `.github/workflows/build-boards.yml`, `.github/workflows/release.yml`; 4a7567b4)
Source: https://github.com/oxidecomputer/hubtools (`hubedit/src/main.rs`, `hubtools/src/lib.rs`; 4491a75d)
Source: https://github.com/oxidecomputer/lpc55_support (`lpc55_sign_bin/src/main.rs`, `lpc55_sign/src/verify.rs`; 1710b531)

### Manufacturing and acquisition posture

- Oxide's public sector page states: "NDAA, BAA, and TAA compliant
  infrastructure" and "Designed and assembled in the USA."
- Oxide's incident response plan includes contract manufacturing,
  component sourcing and rack integration in its supply chain scope, and
  says it supports Oxide's objectives for SOC for Supply Chain and SOC 2.

Narrative guidance: quote these as Oxide's statements and do not
elaborate or infer certifications or issued reports from them. Make no claim about tamper-evident packaging, counterfeit
prevention or component sourcing practice.

Source: https://oxide.computer/solutions/public-sector
Source: https://rfd.shared.oxide.computer/rfd/0733

### Control mapping notes

- **SR-3:** offline roots, a separate online signer and scripted, recorded
  ceremonies are a supply chain control for RoT firmware and platform
  identity. The tooling is public; ceremony records are not published
  (Oxide Computer Company states they are available through Oxide support
  under confidentiality arrangements). Scope
  the claim to RoT firmware and platform identity, not all software.
- **SR-4:** RoT images and bootleby carry a certificate chain to an Oxide
  root, enforced by the RoT at boot. This shows who signed, not source
  provenance. Other provenance evidence: hash pinning of release inputs
  and Hubris reproducibility. For SP, host OS and control plane
  artifacts, no signature under a persistent Oxide key is verified.
- **SR-5:** weak fit. The only public multi-party mechanism is that root
  key backups cannot be restored by a single person. Witnessing is an
  Oxide statement. Do not claim
  resistance to insider compromise.
- **SR-11:** RoT firmware authenticity is enforced on the device (see
  "Hardware Root of Trust"). Do not write that customers can
  independently verify RoT firmware authenticity; see "Build provenance"
  for what they can check. For SP firmware, cite TUF hashes and RoT
  measurement.
- **SA-10 / SA-15:** public version control, hash-pinned inputs and a
  release process run in CI on every commit support these. Signed TUF
  repositories are identified as future work in the release engineering
  documentation.

## Software Update

Self-service update lets operators update Oxide system software and vendor
firmware through the API "independently without Oxide involvement".

### What an update contains

- A bundle is one ZIP file "organized as a TUF repository" (The Update
  Framework), in the format defined by Oxide's `tufaceous` tooling.
- It carries: host OS (Helios) images, phase 1 and phase 2, and a recovery
  (trampoline) OS image used to install them; service processor (SP), root
  of trust (RoT) and RoT bootloader firmware for sleds, switches and power
  shelf controllers; and control plane software as zone images.
- The guide places vendor firmware "(e.g., AMD microcode)" in scope. The
  repository has no separate artifact kind for it.
- Excluded: "SSD firmware is not included in the update bundle. Oxide
  Support can assist with any necessary SSD firmware updates."

Source: https://docs.oxide.computer/guides/operator/system-update
Source: https://github.com/oxidecomputer/tufaceous README.md, artifact/src/tags.rs (rev 38730b6)
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/docs/releng.adoc

### Delivery and the customer hash check

- "The Oxide Support team distributes update bundles through a
  customer-specified file transfer. The operator should validate the SHA
  checksum of the bundle against the value provided by support."
- The guide does not name the algorithm or say how Support conveys the
  value. The release tooling emits a SHA-256 of the ZIP, and Nexus returns
  the SHA-256 of an uploaded archive as `hash` in the upload response.
- This comparison is the only step that ties a bundle to Oxide, because the
  trust root is taken from the bundle itself.

Narrative guidance: record the comparison as a customer responsibility in
`remarks`. Do not describe how Support provides the value.

Source: https://docs.oxide.computer/guides/operator/system-update
Source: https://docs.oxide.computer/api/system_update_repository_upload

### Trust roots

- A trust root is a self-signed TUF root role: a JSON document holding the
  repository's public key and role thresholds. Each bundle contains its own
  at `repo/metadata/1.root.json`; the operator extracts it and adds it to
  the rack's "updates trust store".
- Adding or deleting a root requires fleet admin; listing requires fleet
  viewer. Both changes are audit-logged.
- When a root is added, Nexus checks only that it is a well-formed,
  self-signed TUF root role. Nothing in this check ties the root to Oxide.
- Any number of roots may coexist. Each build has its own key, so each
  release's root is added and remains until an operator deletes it.
  Deletion does not check whether uploaded repositories become untrusted.

Source: https://docs.oxide.computer/api/system_update_trust_root_create
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/types/versions/src/initial/update.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/auth/src/authz/omicron.polar

### Verification at upload and at install

1. At repository upload, Nexus verifies the TUF metadata signatures against
   the trust store. Any one trusted root that verifies the repository is
   sufficient; with an empty store, upload fails. This is the only point at
   which TUF signatures are checked.
2. Afterwards each artifact is identified by the SHA-256 in the verified
   metadata, and checks are by hash: a sled's artifact store rejects a
   write whose hash differs, Nexus re-hashes SP, RoT and host phase 1
   images when it fetches them for delivery, and the host phase 2 image is
   re-hashed after it is written. The trust store is not consulted again.
3. TUF metadata is built with a one-week expiry, but Nexus does not enforce
   expiry on uploaded repositories, so it does not limit a bundle's use.
4. RoT and RoT bootloader images carry their own signatures, which are
   verified on the RoT at boot: the boot ROM verifies the bootloader and
   the bootloader verifies Hubris (see "Hardware Root of Trust"). For a bootloader update
   the device is reset so the new image is verified before it is activated;
   a failed verification is a fatal update error.
5. No signature on SP firmware is verified during update or at boot. Its
   integrity rests on the repository hash and on the RoT measuring the SP
   when the SP resets, which is recorded for attestation and does not gate
   boot (see "Hardware Root of Trust").

Narrative guidance: write that signatures are verified at upload and that
installation is hash-checked against the verified metadata. Do not write
that the trust root verifies artifacts as they are installed, and do not
cite metadata expiry as a control.

Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/src/app/update.rs
Source: https://github.com/oxidecomputer/tufaceous lib/src/loader.rs (rev 38730b6)
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/sled-agent/src/artifact_store.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/mgs-updates/src/rot_bootloader_updater.rs

### How the repository is signed

- The TUF metadata is signed with an Ed25519 key generated during the build
  and held only in memory: "These repositories use a generated throwaway
  key to sign the TUF metadata." There is no signature over the ZIP. The
  signature shows that a repository is consistent with the root shipped
  inside it, not that it came from Oxide.
- The release engineering document identifies a process to sign release
  builds, with a PKI and trust policy, as future work.
- The tooling is public (`tufaceous`; `cargo xtask releng`, run "on each
  commit"). Some build inputs are not, so a third party cannot rebuild a
  release bundle end to end.

Narrative guidance: narratives may say signed release builds are identified
as future work, without characterising status or timing. Do not say bundles
are signed by Oxide or that the release process is reproducible.

Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/docs/releng.adoc
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/dev-tools/releng/src/tuf.rs

### Online update workflow and behaviour

"Access to the update commands is restricted to users with the fleet admin
role." Status can be viewed with fleet viewer. Steps:

1. Check status (web console or `oxide system update status`). "If progress
   is not at 100%, or you see a Contact Support warning, do NOT proceed".
2. Validate the bundle checksum, add the trust root (`oxide system update
   trust-root create`) and upload the repository (`oxide system update
   repo upload`), using the CLI or API: "upload via the web console is not
   supported at this time".
3. Set the target release (`oxide system update target-release update`, or
   the web console). This alone starts the update; there is no separate
   approval step.

Trust root changes, repository upload, target release changes and
`recovery-finish` are audit-logged.

- Progress is reported "in terms of the number of components processed out
  of the total", in the web console or `oxide system update status`.
- Duration: "about 6 hours for a 16-sled rack, with the total time
  increasing proportionally to the number of sleds".
- "The API and web console will remain available through most of the
  update except for a short period of downtime at the end", "typically a
  few minutes", which "involves a change in external IP addresses".
- "A running instance will experience downtime when its sled is rebooted".
  It enters the failed state and, under the default auto-restart policy, is
  restarted on another sled, possibly more than once. "We recommend
  shutting down instances before starting a system update".

Source: https://docs.oxide.computer/guides/operator/system-update
Source: https://docs.oxide.computer/api/target_release_update
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/src/external_api/http_entrypoints.rs

### Offline update at the technician port

- Wicket can install a repository on sleds, switches and power shelf
  controllers while the control plane is not running. It is used in initial
  rack setup and for recovery: "In the unlikely circumstances that a
  self-service update fails to complete, Oxide Support may perform an
  offline update instead." For how wicket is reached, see "Technician Port
  and Maintenance Access".
- This path does not consult the trust store. wicketd checks that the
  repository is internally consistent (signatures valid against the root
  inside it, every target matching its hash) "but does not verify the TUF
  signatures against a valid trust root or verify the expiration
  timestamps". The installer re-checks the SHA-256 of each artifact.
- Afterwards the control plane suspends automatic update until `oxide
  system update recovery-finish` is run, which "should only be called at
  the direction of Oxide support".

Narrative guidance: scope trust-store statements to API-driven updates. On
this path the controls are the checksum comparison and control of access to
the technician port; RoT boot-time signature verification still applies.

Source: https://docs.oxide.computer/guides/operator/system-update
Source: https://docs.oxide.computer/api/system_update_recovery_finish
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/wicketd/src/update_tracker.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/installinator/src/dispatch.rs

### Downgrade, abort and recovery

- Downgrades are refused: a target release older than the current target
  is rejected, as is one that skips a major release.
- A new target cannot be set while an update is incomplete or an offline
  update has not been cleared with `recovery-finish`.
- The API has no operation to abort, pause or roll back an update.
- The documented recovery from a failed update is the Support-performed
  offline update. No public document describes a rollback procedure.
- Not established: whether RoT or SP firmware enforces anti-rollback.

Narrative guidance: describe recovery as forward-only with Oxide Support.
Do not claim rollback or anti-rollback.

Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/src/app/deployment.rs
Source: https://github.com/oxidecomputer/omicron/blob/rel/v23/nexus/external-api/src/lib.rs
Source: https://docs.oxide.computer/release-notes/system/23

## Vulnerability Reporting and Advisories

- "Security issues found in Oxide products and systems operated by Oxide
  should be reported to security@oxidecomputer.com." The same contact is in
  `security.txt`, which adds: "We do not currently have a bug bounty
  program."
- "We will acknowledge your report within 72 hours." No other response or
  remediation time is published.
- Oxide publishes advisories ("Vulnerabilities in Oxide products, where
  customer data may be at risk and action may be required on their part
  for mitigation") and informational announcements, with an RSS feed.
- Oxide's public incident response plan covers "any software or hardware
  that Oxide produces and distributes to customers, and the systems that
  build, sign, and distribute them". It gives customer notification timing
  as "Per contractual commitments" and excludes incidents in customer
  environments.

Narrative guidance: do not assert a published vulnerability disclosure
policy.

Source: https://docs.oxide.computer/security
Source: https://docs.oxide.computer/security/advisories
Source: https://oxide.computer/.well-known/security.txt
Source: https://rfd.shared.oxide.computer/rfd/0733

## Not Established by This Reference

No public source establishes the following. Narratives must not assert
them as fact; where one matters, direct the customer to confirm it with Oxide.

- FIPS 140 validation of any cryptographic module, or operation of any
  component in a FIPS-approved mode.
- Results of any penetration test, third-party assessment or audit.
- Incident response or support SLAs, beyond the 72-hour acknowledgement of
  vulnerability reports.
- RoT or SP firmware anti-rollback, and any update rollback procedure.
- How Oxide Support conveys the bundle checksum.
- How the underlay network is kept separate from guest and external
  networks.
- Anything listed under "Oxide statements without a public source" in
  this file (as-shipped RoT configuration, ceremony practice, custody of
  support tokens). Those are Oxide Computer Company's own statements:
  they must not be asserted as fact and may be used only with
  attribution.
- Signing key rotation and recovery procedures, and records of support
  sessions.
- Bit-for-bit reproducible builds, other than of Hubris images (RFD 605).
- Any absolute claim, such as that the RoT "cannot be bypassed".
- Per-flow network logging, packet capture, or deep-packet inspection of
  guest traffic; volumetric denial-of-service protection; a setting that
  disables the web console; runtime integrity monitoring of control plane
  software. Narratives may say these are not documented capabilities and
  must not say more.
- Review of API error messages for content an attacker could use.
- How the rack switches, or the host OS packet processing that enforces
  VPC boundaries, behave when they fail. Narratives leave this out.

Source: https://rfd.shared.oxide.computer/rfd/0605
