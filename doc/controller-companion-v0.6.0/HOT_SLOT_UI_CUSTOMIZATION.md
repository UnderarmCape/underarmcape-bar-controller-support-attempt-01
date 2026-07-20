# Unit hot-slot UI customization

`hotSlots` is the selectable controller-group strip. It preserves all 10 gameplay groups, same-type/future auto-add, recall/assign/clear semantics, and native BAR Auto Group mirroring.

Editable controls include visibility, normalized position, anchor, scale/font/icon/opacity, square or independent slot width/height, gap, visible count, horizontal/vertical/grid orientation, grid rows, padding, concise header/status visibility, header label, count/AUTO/role markers, hidden empty slots, selected border thickness, empty opacity, background opacity, follow/fixed/wrap overflow, optional auto-collapse timing, animation duration metadata, and a per-component theme override.

When fewer than 10 slots are shown, Follow Active centers the visible window around the active slot while staying within 1–10. Fixed starts at the first eligible slot; Wrap cycles eligible slots. Hide Empty retains the active slot so input state is never invisible.

The default panel no longer carries the long control paragraph. Detailed group controls live in the contextual hint overlay; the panel keeps only `Controller Groups` and the concise active-group status unless the user hides them. Unit texture, count, AUTO state, recent/active borders, type label, and last action remain available.

Changing layout or visibility never changes controller input, group contents, or auto-add behavior.
