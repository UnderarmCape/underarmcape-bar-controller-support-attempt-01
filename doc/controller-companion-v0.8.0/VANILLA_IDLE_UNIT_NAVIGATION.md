# Vanilla Idle Builders navigation

The native Idle Builders override exposes only `controllerGetLiveIdleEntries`, a read-only snapshot built from the exact current `existingIcons` order and live `idleList` buckets used by the ZZZ widget. It filters invalid/dead IDs during snapshot creation. No controller activation, click, mouse, sound, or selection wrapper is exported.

The camera widget owns the controller action. D-pad Right/Left wraps through the flattened live IDs and directly selects/focuses exactly one with `Spring.SelectUnitArray` plus the v0.7 camera-target helper. It remembers the last ID and UnitDef. If that ID disappears or becomes non-idle, traversal repairs to a current live ID of the remembered type before continuing.

LB+D-pad Down directly selects the snapshot bucket for the remembered type, so busy and otherwise non-idle same-type units are excluded. Settings, placement, active targeting, Build/Factory radial, Tactical Radial, and Disassemble have higher priority and suppress idle traversal.
