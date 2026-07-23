# Y Repair Modifier

Y is now `repairModifier`; RB owns front insertion.

When Y is held, A and X both call `ControllerCameraTestTryIssueRepairModifier`. A valid target is an allied, valid, living unit accepted by the Repair command lookup or BAR's current default command. If no valid repair target exists, Y+A falls through to normal A selection/modal handling and Y+X falls through to Smart X.

Hold-X still owns path/line movement until release, so a held X gesture cannot emit an early repair tap.
