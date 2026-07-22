# Build and Factory global paging

An open Build or Factory/Lab radial flattens its authoritative model into one page sequence: every Economy page, every Combat page, every Utility page, then wrap. Empty categories are omitted. Native `radialPage` and `radialSlot` order is preserved; Legacy pages retain compact groups of eight.

RB advances one sequence entry. LB moves one entry backward. Crossing a boundary updates category, local page, global page indicator, the first valid selected item, center text, and the hidden native stable focus key. Backward traversal from the first Combat page enters the final Economy page; backward wrap from Economy enters the final Utility page.

The traversal is rebuilt whenever the native/Legacy option model is refreshed, so changing selection cannot leave stale category/page entries. D-pad category shortcuts remain independent. Queue quantities, compaction, eligibility, and closed-RB opening behavior are unchanged.
