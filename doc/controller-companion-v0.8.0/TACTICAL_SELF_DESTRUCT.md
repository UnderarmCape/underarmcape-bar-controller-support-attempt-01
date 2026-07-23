# Tactical Self Destruct

The native Tactical adapter classifies an available Self Destruct descriptor as Utility and renders it with the shared vanilla-style Tactical entry renderer. Disabled descriptors cannot activate.

Selecting the item only arms the existing protected controller path. It closes the radial and instructs the player to hold Back/View + R3 + L3. The existing 0.75-second hold, selected-unit validation, cancellation, timeout, toast, and command lookup remain authoritative. The Tactical item never issues raw `CMD.SELFD` itself.
