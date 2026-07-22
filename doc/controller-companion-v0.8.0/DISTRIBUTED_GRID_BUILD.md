# Distributed Grid build

During active build placement, LB+RB+RT arms Grid preview and native distributed
assignment. The patched BAR Build Split widget exposes a minimal
`controllerDistribute` adapter that converts the preview positions to
`BuildingInfo` values and calls the same `api_build_orders.splitBuildOrders`
helper used by vanilla shift+space placement.

With one constructor the adapter declines and normal Grid placement runs. With
two or more constructors each preview position enters the native allocator once;
the camera does not issue the full grid to every constructor. RT queue semantics
are preserved. The chord has priority over Disassemble, Move State, and Factory
Queue Mode. B cancels placement without changing constructor selection, and a
confirmation clears the distributed-armed flag.
