# Controller Input Priority

One camera-widget update loop owns controller input.

For A/X, the priority is: staged v0.6 tactical point/area target; active build placement and distributed grid; Factory/Lab queue action; Tactical Radial action; Disassemble direct/radius action; ordinary A selection or Smart X. A consumed edge cannot reach a lower layer.

For A selection: tap selects one exact unit; compatible double tap expands to visible locally owned same-type units; hold enters the brush; RT+A performs exact additive/toggle selection.

For D-pad: modal/radial navigation; build placement; LB+D-pad Down idle same-type selection; then ordinary idle previous/next. Self Destruct always routes through the existing protected Back/View + R3 + L3 hold.

The native owner-session and hybrid target broker remain in the recovery commit but are not polled or registered by the deployed input path.
