# BAR Controller Support v0.4.3 Queue Polish - AIO Clean Install

This is the current recommended installer for normal users.

This release is distributed as a small installer BAT plus PAYLOAD ZIP files because GitHub release assets must stay under the per-file upload limit.

## Install

1. Download the BAT, README, and all PAYLOAD ZIP files.
2. Keep them in the same folder.
3. Run `Install_BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_CLEAN_INSTALL.bat`.
4. The BAT extracts, validates, and installs the payload automatically.

Do not manually extract the PAYLOAD ZIP files.

## Why this release exists

Older full BAR.sdd packaging caused periodic RTSS frametime stutter. Testing confirmed that a fresh official vanilla BAR.sdd plus the stable controller-enabled Recoil 2025.06.24 compatibility engine and latest v0.4.3 Queue Polish LuaUI widgets runs smooth and keeps controller support working.

## What is included

* Fresh official vanilla BAR.sdd payload
* Stable controller-enabled Recoil 2025.06.24 compatibility engine payload
* v0.4.3 Queue Polish LuaUI controller widgets
* Clean payload-driven installer BAT
* README_AIO_CLEAN_INSTALL.txt

## What is not included

* No old backed-up BAR.sdd
* No old full/bloated BAR.sdd package
* No local BYAR Chobby.sdd
* No Attempt 02 engine
* No Git requirement
* No GitHub CLI requirement
* No internet requirement during install

## Release Assets

Download all of these files into the same folder:

* `Install_BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_CLEAN_INSTALL.bat`
* `README_AIO_CLEAN_INSTALL.txt`
* `BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_PAYLOAD_1_OF_2.zip`
* `BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_PAYLOAD_2_OF_2.zip`

## Notes

This AIO installer backs up existing BAR.sdd, BYAR Chobby.sdd, and recoil_2025.06.24 folders before replacing active files. It intentionally removes local BYAR Chobby.sdd from the active games folder to avoid old local install clutter.
