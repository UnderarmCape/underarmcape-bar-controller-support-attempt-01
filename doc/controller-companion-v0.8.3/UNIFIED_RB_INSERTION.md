# Unified RB Insertion

v0.8.3 uses RB+A as the only controller insert chord.

- Factory/lab radial RB+A inserts the focused build option at the real front of the factory queue.
- Normal A still appends, RT+A still queues five, X/RT+X still remove from the factory queue.
- Build placement and compatible command orders use RB+A for queue-front insertion through CMD.INSERT.
- LT+A is intentionally removed from insert behavior and hints.
- Insert feedback appears only after a dispatch succeeds.

Manual check: queue two factory items, focus a third item, press RB+A, and verify the new item appears ahead of the old queue while the older items remain queued behind it.
