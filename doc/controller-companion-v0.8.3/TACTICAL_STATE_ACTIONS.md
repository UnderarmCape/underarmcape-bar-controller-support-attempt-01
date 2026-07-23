# Tactical State Actions

Tactical state commands remain open in v0.8.3.

- Hold Position / Move State cycles forward with A and backward with X.
- Wait toggles once and keeps Tactical open.
- Repeat and Fire State keep the existing Tactical behavior.
- After a state change, the Tactical radial rebuilds so labels and state indicators update in place.

Manual check: open Tactical, activate Hold Position with A and X, then toggle Wait twice. The radial should remain open and reflect the current state each time.
