# Tactical Self Destruct

Self Destruct is now ensured in Tactical -> Utility when selected owned units or structures expose the protected command path.

Registration flow:

- `ControllerCameraTestFindSelfDestructCommandID(includeDisabled)` searches active command descriptors and can include disabled descriptors.
- `ControllerCameraTestEnsureSelfDestructCommand(commands)` adds or normalizes a Utility item with `kind = "self_destruct"`.
- Native and legacy tactical model rebuilds both call the ensure helper.

Safety behavior:

- The radial item uses the same native-style tactical renderer as other commands.
- A disabled item shows `Protected Self Destruct unavailable`.
- Selecting the item does not issue raw `CMD.SELFD`.
- Enabled selection calls `ControllerCameraTestArmProtectedSelfDestruct()`.
- Completion still requires the existing protected Back/View + R3 + L3 hold and keeps the existing 0.75-second hold, warnings, cancellation, and selection validation.

