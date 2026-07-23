# BAR Controller Companion v0.8.0 Experimental development

The experimental source version is centralized in `Directory.Build.props`. All projects consume semantic version `0.8.0`, channel `Experimental`, and display version `v0.8.0 Experimental`; `ProductMetadata` derives runtime banners and artifact names. Public releases now use the mandatory manifest-driven GitHub workflow. Every successful future milestone must invoke `tools/release/Publish-ControllerRelease.ps1`, include schema-v1 sidecars, and become GitHub Latest unless it is historical Recovery Mode data. Deployment alone is not completion.

`BARControllerBridge.exe` sends XInput controller state to LuaUI over localhost UDP. In session mode it waits for a Spring/Recoil process, tracks that PID across a bounded engine transition, and exits cleanly after the game session closes. Use `--standalone` for manual operation that must remain open.

Development commands include `check`, `defaults`, `update`, `recover`, `catalog`, `status`, `reload`, and `help`. Release checks run asynchronously at startup and every six hours, use ETag/cache fallback, and never install without explicit keyboard approval.

The public v0.8.0 package and publishing workflow are under `tools/release`. Updates, downgrades, and reinstalls are dynamic-manifest transactions with an external self-update helper, preserved configuration, automatic rollback, and a verified Recovery Mode floor of v0.6.0. BAR is never force-closed; live installs display `/luaui reset` guidance.
