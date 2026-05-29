# BAR Xbox Controller Support v0.4.0 Checkpoint - Binding UI Pre-Alpha

This checkpoint documents the stable pre-alpha release of the unified modern **Bindings / Settings UI** (v0.4.0) for Beyond All Reason (BAR) Xbox Controller Support.

---

## 1. Current State
- **Decoupled Architecture**: 
  - `gui_controller_bindings_ui.lua` is the new primary widget responsible for all visual rendering, D-pad/keyboard settings navigation, mouse clicks, and layout adjustments.
  - `gui_controller_camera_test.lua` has been preserved as the gameplay-only and input-translation engine core. It remains completely untouched during the layout settings pass.
- **Legacy Settings Redirection**: The legacy settings UI has been deprecated. Standard legacy settings hotkeys automatically redirect to open the new combined interface.
- **Activation Paths**: The new editor is fully operational and can be launched in-game by running the text command `/luaui bar_controller_bindings` or by clicking the new mouse-interactive top-right screen button labeled **Bindings**.

---

## 2. Key Features

- **Modern Combined UI**: Switch seamlessly between **Bindings** and **Settings** categories using the top header tabs or the controller's **Start/Menu** button.
- **Full Bindings Audit**: Displays all 37 mapped controller binding definitions dynamically partitioned across categories, with a count of active actions rendered live.
- **D-pad / Keyboard Tuning**: Setting ranges have been broadly expanded (e.g. up to `20,000` deadzones and curves) to accommodate high-sensitivity tuning.
- **Tuned Safe-Window Layout**: Features a dynamic layout centered on the screen which prevents overlaps with BAR HUD panels.
- **Input Grabbing**: Blocks all standard keyboard/gameplay inputs from leaking to the game below while the UI is open, cleanly resuming play when closed with **B** or **Escape**.
- **Adjustable UI Layout Settings**: Addressed user requirements by making margins, safe areas, and button coordinates fully tunable directly in-game under the `Settings -> UI` category.
- **Queue Command Removal**:
  - Tapping **Back/View** removes the current/next queued unit command.
  - Pressing **LT + Back/View** removes the last queued unit command.

---

## 3. Crash / Hotfix Note

- **Issue**: The original implementation of layout settings under commit `9a9aaae5` caused a crash when opening the `Settings` page.
- **Log Tracer**:
  ```
  Error in DrawScreen(): [string "LuaUI/Widgets/gui_controller_bindings_ui.lua"]:234: attempt to call global 'ControllerBindingsUISafeCall' (a nil value)
  ```
- **Root Cause**: The settings getters/setters/reset wrappers were defined at the top of the file before `ControllerBindingsUISafeCall` was parsed. In Lua, this results in a global variable lookup at runtime that evaluates to `nil`.
- **Resolution**:
  1. The bad commit was immediately reverted under commit [`3bf76d67`](file:///C:/Users/kaili/AppData/Local/Programs/Beyond-All-Reason/data/games/BAR.sdd) to bring the workspace back to a known stable baseline.
  2. Re-added the layout settings safely under commit [`04551703`](file:///C:/Users/kaili/AppData/Local/Programs/Beyond-All-Reason/data/games/BAR.sdd) by defining all wrappers strictly *after* `ControllerBindingsUISafeCall`.
  3. Integrated a robust `ControllerBindingsUIIsRowMalformed` guard to ensure the renderer skips any row lacking required properties and logs once instead of crashing.

---

## 4. Tuned Layout Defaults

We have permanently updated the widget's defaults to match the exact preferred, custom-tuned layout parameters:
```lua
ControllerBindingsUILayoutDefaults = {
	useSafeArea = true,
	maxXMargin = 600,
	maxYMargin = 300,
	xMarginRatio = 0.15,
	yMarginRatio = 0.10,
	toggleButtonVisible = true,
	toggleButtonRightOffset = 560,
	toggleButtonTopOffset = 8,
}
```
- **Live Margins**: The default safe margin values now perfectly match the user's tuned horizontal (`600` / `0.15`) and vertical (`300` / `0.10`) parameters.
- **Reset Action**: Pressing `A/Enter` or clicking on the local settings row **`Reset Bindings UI layout`** restores only these layout settings back to the tuned defaults above.

---

## 5. Technical Validation

The codebase was validated successfully with no errors or warnings:
1. **Compilation**: Clean syntax compilation verified:
   ```powershell
   luac -p luaui/Widgets/gui_controller_bindings_ui.lua luaui/Widgets/gui_controller_camera_test.lua
   ```
2. **Whitespace Formatting**: Git diff checks verified perfectly clean with no trailing whitespace errors:
   ```powershell
   git diff --check -- luaui/Widgets/gui_controller_bindings_ui.lua luaui/Widgets/gui_controller_camera_test.lua
   ```
3. **No UTF-8 BOM**: Confirmed files are encoded in standard UTF-8 without BOM.

---

## 6. Manual Test Results

- [x] **Settings Category Loading**: The modern `Settings` list switches and navigates cleanly with zero lag or crashes.
- [x] **Live Layout Tuning**: Adjusting max margins or margin ratios live in-game resizes and shifts the centered safe window on-the-fly.
- [x] **Live Button Alignment**: Changing top/right button offsets moves the screen button live, and toggling `Bindings button visible` off hides it instantly.
- [x] **Reset Operations**: Pressing `X/R` on individual rows resets only that setting. Triggering the `Reset Bindings UI layout` row instantly restores the exact custom tuned defaults.
- [x] **Gameplay Restoration**: Closing the UI with **B** or **Escape** correctly releases all input locks and resumes standard gameplay.
