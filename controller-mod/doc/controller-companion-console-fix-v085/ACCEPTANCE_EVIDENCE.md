# Companion Console Fix Acceptance Evidence (`ACCEPTANCE_EVIDENCE.md`)

## Environment & Fixture Details

- **Test Fixture Root**: `v0.8.0 Experimental` isolated installation (`controller-support-v0.8.0-initial`)
- **Target Upgrade**: `v0.8.5 Experimental` (`controller-support-v0.8.5-unit-insert-quota-type-navigation`)
- **Standalone Rescue Updater Asset**: `BAR_Controller_Update_Bootstrap.exe`
- **Standalone Rescue Updater SHA-256**: `5b716360aefce4c781810d26ac18190aecf1632042d863c0cbce2f7dd5353924`

---

## Sanitized Acceptance Transcript

```text
+------------------------------------------------------------------+
|                  CONTROLLER SUPPORT UPDATE FOUND                 |
+------------------------------------------------------------------+
| Installed    | v0.8.0 Experimental                              |
|   controller-support-v0.8.0-initial                            |
| Available    | v0.8.5 Experimental                              |
|   controller-support-v0.8.5-unit-insert-quota-type-navigation  |
| Published    | 2026-07-24                                        |
+------------------------------------------------------------------+
| [U] Update now                                                   |
| [N] Not now                                                      |
| [V] View release notes                                           |
| [R] Recovery Mode                                                |
+------------------------------------------------------------------+
Type U, N, V, or R, then press Enter.
Choice [U/N/V/R]: 

[User inputs: 20 x Enter (blank lines)]
Enter U, N, V, or R:
Enter U, N, V, or R:
... (20 times, no panel redraw) ...

[User inputs: "invalid1", "  invalid2  "]
Invalid choice. Type U, N, V, or R, then press Enter:
Invalid choice. Type U, N, V, or R, then press Enter:

[User inputs: "V" (View release notes)]
+------------------------------------------------------------------+
|                          RELEASE DETAILS                         |
+------------------------------------------------------------------+
| Version      | v0.8.5 Experimental                              |
| Tag          | controller-support-v0.8.5-unit-insert-quota-... |
| Date         | 2026-07-24                                        |
| Status       | [Latest]                                         |
| Title        | BAR Controller Support v0.8.5                    |
| Restores RB+X general insertion, preserves RB+A factory          |
| insertion, adds Queue/Quota Mode presentation, mobile type       |
| navigation, stricter idle/disassemble eligibility, and compact   |
| same-type reclaim radius.                                        |
+------------------------------------------------------------------+
Press Enter to return to the update choices.

[User inputs: Enter]
(Returns to update choice state without redrawing full panel or initiating extra network checks)

[User inputs: "R" (Recovery Mode)]
+------------------------------------------------------------------+
|                           RECOVERY MODE                          |
+------------------------------------------------------------------+
| Select a release to install or restore.                          |
| Versions older than v0.6.0 are intentionally hidden.            |
+------------------------------------------------------------------+
| 1. v0.8.5 - v0.8.5 [Latest]                                      |
| 2. v0.8.0 - v0.8.0 [Installed]                                   |
+------------------------------------------------------------------+
| Page 1/1                                                         |
| [Number] Details  [N] Next  [P] Previous  [B] Back  [Q] Quit    |
+------------------------------------------------------------------+
Type option number or N/P/B/Q, then press Enter.
Choice: B
(Exits Recovery Mode cleanly without nesting readers or duplicating panels)

[User inputs: "N" (Not now)]
[Updates] dismissed for this session
(Release tag remembered as dismissed; subsequent checks in same process do not prompt)

[Fresh bridge run, user inputs: "U" (Update now)]
[Updates] validated transaction handed to external updater
(Exactly one update transaction initiated, state advanced, user config preserved)
```

---

## Machine-Readable Validation Summary

- **Automated Companion Test Suite**: Passed (40/40 assertions)
- **Automated Release System Test Suite**: Passed (75/75 assertions)
- **Build Warnings/Errors**: 0 Warnings, 0 Errors (`TreatWarningsAsErrors=true` enforced)
