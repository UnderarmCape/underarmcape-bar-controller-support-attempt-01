# BAR Controller Support v0.4.3 Queue Polish - AIO Clean Install

This is the current recommended installer for normal users.

Download the AIO ZIP, extract it, and run:

Install_BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_CLEAN_INSTALL.bat

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

## Install

1. Download BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_CLEAN_INSTALL.zip
2. Extract the ZIP
3. Run Install_BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_CLEAN_INSTALL.bat
4. Launch BAR normally
5. Go to Settings > Developer
6. Start Singleplayer: Beyond All Reason Dev
7. Watch RTSS and test Xbox controller input

## Notes

This AIO installer backs up existing BAR.sdd, BYAR Chobby.sdd, and recoil_2025.06.24 folders before replacing active files. It intentionally removes local BYAR Chobby.sdd from the active games folder to avoid old local install clutter.
