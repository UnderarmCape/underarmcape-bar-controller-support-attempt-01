# Smart X restoration and native extensions

Normal Smart X uses the complete decision tree from commit
`95e4b907f73bc78c2944ed55dac2e53d82d7c7d1`. The function is retained as
`attemptLegacyContextCommand`; its T2 upgrade, transport load/move, assisted
command, geothermal, metal-extractor, self-target, feature, and guarded Move
behavior is unchanged. The later wrapper that made
`Spring.GetDefaultCommand()` the sole Smart X implementation is not used.

Hold-X drag Move was intentionally not reverted. Press/hold detection,
`singleMovePath`, drag preview, release confirmation, and the modal/build/radial
guards remain the current v0.8 implementation.

Native Experimental adds one narrow preflight for live default commands:

- Repair on an exact unit target is sent once through Order Menu's
  `controllerExecuteAtTarget`, including when selected builders are airborne.
- Reclaim on an exact enemy unit or structure is sent through the same native
  `CommandNotify` boundary, without an allegiance filter.
- An accepted extension stops processing, so it cannot fall through to Move.
- Every other command continues into the restored Smart X tree.

The runtime priority is active native targeting, placement, Factory/Build
radials, Disassemble, held-X drag, then the clean X-tap resolver. The native
Repair/Reclaim preflight exists only inside that clean tap and issues at most
one command.
