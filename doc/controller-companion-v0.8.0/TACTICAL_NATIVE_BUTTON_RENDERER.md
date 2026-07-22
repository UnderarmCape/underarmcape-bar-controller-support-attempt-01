# Tactical native button renderer

Native Tactical outer entries delegate drawing to
`WG.ordermenu.controllerDrawCommandButton`. The callback temporarily supplies
the radial cell rectangle to Order Menu's actual `drawCell`, then restores its
cell rectangle, active state, and display-list cache.

This makes icons, borders, disabled treatment, state pips, and text metrics the
same implementation as the vanilla Order Menu. Category chips, center details,
and state sub-radials remain controller-specific. If the native renderer is
unavailable, the shared renderer's existing fallback remains functional.
