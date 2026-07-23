# Tactical Self Destruct

The Tactical Utility Self Destruct item now routes to the protected controller flow.

Selecting the item arms Self Destruct and closes Tactical with the instruction to hold Back/View + L3 + R3. The protected flow keeps the existing hold duration, selected-unit validation, cancellation, expiry, and single dispatch after the safety hold.

The button renders through the shared Tactical command renderer with `colorProfile = "danger"`, using the standard geometry with a red vertical gradient and danger focus border.
