BAR Controller Support v0.4.3 Queue Polish - AIO Clean Install
===============================================================

This is the recommended clean installer for normal users.

This release is distributed as a small installer BAT plus PAYLOAD ZIP files
because GitHub release assets must stay under the per-file upload limit.

Download these files from the release:

* Install_BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_CLEAN_INSTALL.bat
* README_AIO_CLEAN_INSTALL.txt
* All files named BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_PAYLOAD_*.zip

Put all downloaded files in the same folder, then double-click:

Install_BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_CLEAN_INSTALL.bat

Do not manually extract the PAYLOAD ZIP files. The BAT extracts and validates
them automatically.

No Git is required.
No GitHub CLI is required.
No internet connection is required during install after the release files have
been downloaded.

What this installer includes
----------------------------

* Fresh official vanilla BAR.sdd payload.
* Stable controller-enabled Recoil 2025.06.24 compatibility engine payload.
* v0.4.3 Queue Polish LuaUI controller widgets.
* A clean payload-driven installer BAT.

What this installer intentionally does not include
--------------------------------------------------

* No old backed-up BAR.sdd.
* No old full or bloated BAR.sdd package.
* No local BYAR Chobby.sdd.
* No Attempt 02 engine.
* No Git requirement during install.
* No GitHub CLI requirement during install.
* No internet requirement during install.

Why this release exists
-----------------------

Older full BAR.sdd packaging caused periodic RTSS frametime stutter every
2-3 seconds on the test system. Testing confirmed that the stutter came from
the old packaged BAR.sdd, not from the stable controller engine or the latest
LuaUI widgets.

The tested smooth and working setup is:

* Fresh official vanilla BAR.sdd.
* Stable controller-enabled Recoil 2025.06.24 compatibility engine.
* Latest v0.4.3 Queue Polish LuaUI controller widgets.
* No old backed-up BAR.sdd.
* No local BYAR Chobby.sdd.
* No Attempt 02 engine.

Installer behavior
------------------

The installer first extracts all sibling PAYLOAD ZIP files into a temporary
staging folder, reconstructs the logical payload folder, and validates it.

The combined payload must include:

* payload\engine
* payload\bar_sdd
* payload\lua_widgets

The installer backs up existing active folders before replacing them:

* data\games\BAR.sdd
* data\games\BYAR Chobby.sdd
* data\engine\recoil_2025.06.24

It installs the fresh BAR.sdd payload, copies the controller LuaUI widgets into
BAR.sdd\luaui\Widgets, installs the stable controller engine payload into
data\engine\recoil_2025.06.24, creates data\devmode.txt, and applies:

CamSpringLockCardinalDirections = 0

The installer does not install a local BYAR Chobby.sdd. If an old local
BYAR Chobby.sdd is present from an older install, the installer backs it up and
moves it out of the active games folder.

Validation / dry run
--------------------

For a payload-only validation that does not touch the live BAR install, run:

Install_BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_CLEAN_INSTALL.bat --payload-check

For a dry run that validates the payload and prints the live install paths
without replacing files, run:

Install_BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_CLEAN_INSTALL.bat --dry-run

Final user test
---------------

1. Launch BAR normally.
2. Go to Settings > Developer.
3. Start Singleplayer: Beyond All Reason Dev.
4. Start a local match.
5. Watch RTSS.
6. Test Xbox controller input.
