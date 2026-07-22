# Build and Factory radial paging

With no radial open, a clean RB tap opens the eligible constructor Build Radial
or selected Factory/Lab Radial. No eligible context remains a no-op.

Once either radial is open, it owns LB/RB before shoulder arbitration. RB moves
to the next compact page and LB to the previous compact page, wrapping within
the current category. A one-page category safely consumes the shoulder without
changing category. A page change resets to the first valid compact slot,
updates the stable focus key and native hidden focus identity, and therefore
refreshes title, description, indicator, border, and hints.

The same press cannot reopen the menu or reach Queue Mode, Move State, or
Disassemble. Tactical radial ownership disables this path entirely.
