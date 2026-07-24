# Update Prompt Behavior (`UPDATE_PROMPT_BEHAVIOR.md`)

## Panel Rendering

The update panel border box is rendered exactly **once** when an update is available:

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
```

## Line Input and Error Handling

- **Line Input**: Input is read using line-based `ReadLine()`, trimmed of whitespace, and evaluated case-insensitively.
- **Accepted Inputs**:
  - `U`, `Update`, `Update now` -> Triggers Update transaction.
  - `N`, `No`, `Not now` -> Dismisses release for the process lifetime.
  - `V`, `View`, `View notes`, `Release notes` -> Displays release notes once.
  - `R`, `Recovery`, `Recovery Mode` -> Opens Recovery Mode.
- **Blank Input (pressing Enter)**:
  Outputs inline: `Enter U, N, V, or R: ` and waits for the next line without redrawing the panel.
- **Invalid Input**:
  Outputs inline: `Invalid choice. Type U, N, V, or R, then press Enter: ` and waits for the next line without redrawing the panel.
