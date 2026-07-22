# BAR Controller Companion v0.8.0 Experimental development

The experimental source version is centralized in `Directory.Build.props`. All projects consume semantic version `0.8.0`, channel `Experimental`, and display version `v0.8.0 Experimental`; `ProductMetadata` derives runtime banners and artifact names. The public v0.7.0 release remains frozen under its existing release workflow.

`BARControllerBridge.exe` sends XInput controller state to LuaUI over localhost UDP. In session mode it waits for a Spring/Recoil process, tracks that PID across a bounded engine transition, and exits cleanly after the game session closes. Use `--standalone` for manual operation that must remain open.

Development commands include `check`, `defaults`, `update`, `status`, `reload`, and `help`. Startup checks remain fail-soft and never apply application releases without explicit user approval.

The v0.8.0 experimental package and deployment scripts are under `tools/dev-scripts` and `tools/release/bar-controller-support-v0.8.0-native-test`. They preserve configuration, create rollback manifests, and never launch or force-kill BAR. See `doc/controller-companion-v0.8.0` for controller ownership, tactical restoration, radial packing, native cells, idle navigation, and the 58-step live checklist.
