# Disassemble Mode Controls

Disassemble X behavior remains discriminated:

- Tap X over a reclaimable unit or structure uses the shared one-shot reclaim helper.
- Tap X over ground issues the Disassemble ground Move path.
- Hold-X starts the existing path/line Move behavior.

B now clears controller-owned Disassemble target state before double-B exit can arm. The clear path resets marked targets, highlights, same-type anchors, radius previews, pending X, and LB+A state while restoring cached constructors.

L3+R3 runs Clear Queue for the cached constructors. LB+B runs Stop Selected. Both preserve Disassemble mode.
