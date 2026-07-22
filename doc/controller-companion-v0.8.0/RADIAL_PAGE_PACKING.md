# Radial page packing and sectors

`controller_native_radial_adapter.lua:PackCategories` is a deterministic dynamic-programming solver. It flattens non-empty fixed-order categories without reordering items, uses exactly `ceil(itemCount / 8)` pages, and considers every legal one-to-eight-item page break. Its dominant penalty avoids a one-item category wedge on a mixed page when the same minimum page count permits a better break; secondary penalties balance page sizes and reduce category splits.

Categories may overflow onto a later page and share that page with any following category, including Economy with Combat when Build and Utility are empty. Every category run is contiguous within a page, empty categories never produce pages, and each packed page stores explicit sector `firstSlot`, `lastSlot`, and count data.

The shared radial renderer draws a single full background for one category. Mixed pages draw slot-aligned category-colored triangle-fan sectors, boundary dividers, and compact category labels. RB advances the global packed page sequence; LB reverses it; both wrap and focus the first valid item.
