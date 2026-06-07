BAR Xbox Controller Support v0.4.6 - AIO Clean Installer
=========================================================

This is the full AIO clean installer package.

Download all files from this release into the same folder:

- Install_BAR_Controller_Support_v0.4.6_AIO_CLEAN_INSTALL.bat
- README_AIO_CLEAN_INSTALL_v0.4.6.txt
- BAR_Controller_Support_v0.4.6_AIO_PAYLOAD_1_OF_2.zip
- BAR_Controller_Support_v0.4.6_AIO_PAYLOAD_2_OF_2.zip
- BAR_Controller_Support_v0.4.6_AIO_RELEASE_NOTES.md

Do not manually extract the payload ZIPs.
Run Install_BAR_Controller_Support_v0.4.6_AIO_CLEAN_INSTALL.bat.

No Git or GitHub CLI is required. After all release files are downloaded, the
installer does not require an internet connection.

Includes
--------

- Working controller-enabled engine/base from the previous AIO.
- Vanilla BAR.sdd payload.
- Latest v0.4.6 Lua widgets.
- Pregame controller commander placement and Ready support.
- Controller Mouse Mode UI clicking and speed presets.
- Mouse Mode edge clamp.
- Pregame camera modifiers.
- Factory insert-to-front.
- T2 metal extractor and geothermal Smart X upgrades.
- Build/factory radial unit information panel.
- Transport and command polish from v0.4.5.

No new engine code was compiled for v0.4.6.

The custom engine requirement remains until Recoil/BAR controller support is
merged and adopted upstream.

Installer behavior
------------------

The BAT verifies both payload SHA256 hashes, reconstructs the payload in a
temporary folder, validates the engine, BAR.sdd, and required Lua widgets, and
then installs them using the proven v0.4.5 clean-install process.

The installer backs up existing active folders before replacement:

- data\games\BAR.sdd
- data\games\BYAR Chobby.sdd
- data\engine\recoil_2025.06.24

It installs the controller-enabled engine to:

data\engine\recoil_2025.06.24

It installs the vanilla BAR payload and v0.4.6 widgets to:

data\games\BAR.sdd

It also creates data\devmode.txt and sets:

CamSpringLockCardinalDirections = 0

Validation modes
----------------

Payload-only validation without changing the live BAR install:

Install_BAR_Controller_Support_v0.4.6_AIO_CLEAN_INSTALL.bat --payload-check

Dry run that validates the payload and live BAR root without replacing files:

Install_BAR_Controller_Support_v0.4.6_AIO_CLEAN_INSTALL.bat --dry-run

Area Mex note
-------------

cmd_area_mex.lua is included because controller Area Mex currently needs:

WG.controllerAreaMex.issueArea(...)

BAR upstream PR:
https://github.com/beyond-all-reason/Beyond-All-Reason/pull/7874

First test after installation
-----------------------------

1. Launch BAR normally.
2. Go to Settings > Developer.
3. Start Singleplayer: Beyond All Reason Dev.
4. Verify pregame commander placement and Ready with A/X.
5. Test Mouse Mode, camera modifiers, build/factory radials, and factory insert.
6. Watch the console and RTSS for Lua errors, OpenGL errors, or frametime issues.
