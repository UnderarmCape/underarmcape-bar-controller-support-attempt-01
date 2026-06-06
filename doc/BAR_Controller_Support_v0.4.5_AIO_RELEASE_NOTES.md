# BAR Xbox Controller Support v0.4.5 - AIO Clean Installer Release Notes

This is the recommended clean installer release for v0.4.5.

It follows the payload-driven installer structure to include a compiled controller-enabled Recoil engine and a vanilla `BAR.sdd` payload while staying under GitHub's per-file upload size limits.

## Installation Instructions

> [!IMPORTANT]
> To install this release successfully, download **all** of the following files into the **same folder**:
>
> 1. `Install_BAR_Controller_Support_v0.4.5_AIO_CLEAN_INSTALL.bat`
> 2. `README_AIO_CLEAN_INSTALL_v0.4.5.txt`
> 3. `BAR_Controller_Support_v0.4.5_AIO_PAYLOAD_1_OF_2.zip`
> 4. `BAR_Controller_Support_v0.4.5_AIO_PAYLOAD_2_OF_2.zip`
> 5. `BAR_Controller_Support_v0.4.5_AIO_RELEASE_NOTES.md`
>
> Once all assets are downloaded into the same folder, double-click:
> `Install_BAR_Controller_Support_v0.4.5_AIO_CLEAN_INSTALL.bat`
>
> Do not manually extract the payload ZIP files; the BAT script automatically verifies their SHA256 hashes and handles extraction.

---

## What's New in v0.4.5

This release incorporates all features from the incremental v0.4.5 update onto a fresh vanilla install:

- **Dedicated Air Transport Profile**: Air transports automatically bypass normal Smart X behavior for specialized controls.
  - Tapping `X` over allied unit loads the transport; tapping `X` on empty ground executes a Move command.
  - `LB + X` initiates Load command; `LB + Hold X` triggers Load Area auto-anchored.
  - `LB + A` triggers Unload command; `LB + Hold A` triggers Unload Area auto-anchored.
- **Command Toast Feedback**: Cleaned up visual toast notification triggers to prevent command spam.
- **Builder Area Command Auto-Anchors**:
  - `LB + A` Repair Area auto-anchors.
  - `LB + X` Reclaim Area auto-anchors.
- **Build Placement Polish**:
  - Slow/full pan toggle during placement.
  - Removed redundant `[X] Stay` option.
- **Affordability Visual Integrity**:
  - Unaffordable build items are dimmed but readable.
  - Affordability cache reduces UI flickering.
- **Outlines and Highlighting**:
  - Removed redundant extra green controller highlight rings around selected units, restoring the native BAR selection outlines.

---

## Payload Integrity Details

The installer BAT validates payload integrity using the following SHA256 hashes:

- **BAR_Controller_Support_v0.4.5_AIO_PAYLOAD_1_OF_2.zip**:
  `EE1A5AEF034E4ED2DEBBE07CC87ED78D75659C95C3932CF5DB2CD403E4CF9EB3`
- **BAR_Controller_Support_v0.4.5_AIO_PAYLOAD_2_OF_2.zip**:
  `18E525AABC4B36D900688D9C4CC91DA4A39AF5FDB5B5F3E5FC8E84206E1E333E`

---

## Validation and Testing

To verify the files before installing, you can run:
- Payload-only validation check:
  `Install_BAR_Controller_Support_v0.4.5_AIO_CLEAN_INSTALL.bat --payload-check`
- Dry run:
  `Install_BAR_Controller_Support_v0.4.5_AIO_CLEAN_INSTALL.bat --dry-run`
