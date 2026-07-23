# v0.8.4 RT+RB Suppression

RT+RB is a hard conflict suppressor. When either shoulder joins the other inside the chord grace window, the camera widget consumes the controller chord, closes controller-owned visible selection radial state, prevents Build/Factory radial and Disassemble ownership, and keeps the Tactical RB latch waiting until RB is released.

No delayed replay is performed. The only rearm path is both RT and RB returning neutral.
