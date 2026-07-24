# Interactive Console Prompt Smoke Test Evidence

## Execution Summary
- **Environment**: Windows Pseudoconsole (ConPTY) un-redirected session
- **Initial Panel Renders**: 1
- **Blank Enter Inputs**: 3 (printed `Enter U, N, V, or R:` without panel redraw)
- **Invalid Text Inputs**: 2 (printed `Invalid choice...` without panel redraw)
- **Release Notes**: Viewed once, returned to choice state without nesting readers
- **Not Now**: Closed prompt and suppressed tag for current process

## Raw ConPTY Session Transcript
```text
+------------------------------------------------------------------+
|                 CONTROLLER SUPPORT UPDATE FOUND                  |
+------------------------------------------------------------------+
| Installed    | v0.8.0 Experimental                               |
|   controller-support-v0.8.0-initial                              |
| Available    | v0.8.5 Experimental                               |
|   controller-support-v0.8.5-unit-insert-quota-type-navigation    |
| Published    | 2026-07-24                                        |
+------------------------------------------------------------------+
| [U] Update now                                                   |
| [N] Not now                                                      |
| [V] View release notes                                           |
| [R] Recovery Mode                                                |
+------------------------------------------------------------------+
Type U, N, V, or R, then press Enter.
Choice [U/N/V/R]: Enter U, N, V, or R: Enter U, N, V, or R: Enter U, N, V, or R: Invalid choice. Type U, N, V, or R, then press Enter: Invalid choice. Type U, N, V, or R, then press Enter: 
```
