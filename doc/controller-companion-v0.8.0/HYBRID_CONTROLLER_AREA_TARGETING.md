# Hybrid controller area targeting

Status: **EXPERIMENTAL — V0.7 TACTICAL RESTORE, MIXED RADIAL SECTORS, NATIVE CELLS, AND IDLE CONTROL TEST**

The controller owns input edges, neutral gates, anchor, preview geometry, and B cancellation. BAR owns live descriptors, legality, semantic transforms, `CommandNotify`, and engine fallback. Command selection calls `ControllerCameraTestBeginHybridTargeting(..., false)`, so the selection edge is consumed and no anchor exists until a fresh post-selection A/X.

Circular area: fresh A/X stores center; release arms resizing; cursor changes radius; fresh A/X confirms. Front and rectangle use the same sequence with start/end or opposite corners. Release never dispatches. A captured descriptor remains available even if the engine active command is cleared.

Final shapes route through the actual native owners: Area Mex receives center/radius for metal-spot filtering; Smart Area Reclaim receives center/radius; same-type Disassemble adds its fixed target/UnitDef identity; Custom Formations receives front/rectangle endpoints. Order Menu has one guarded `CommandNotify` site and uses direct `GiveOrder`/`CMD.INSERT` only when unhandled. Retired mouse-owner input is never started or updated.

Static tests prove all four A/X area combinations and exactly-once structure. Map-specific legality and gameplay acceptance require the 58-step manual checklist; no static result is presented as live gameplay proof.
