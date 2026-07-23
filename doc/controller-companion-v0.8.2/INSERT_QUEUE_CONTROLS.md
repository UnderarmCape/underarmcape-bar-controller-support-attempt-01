# Insert Queue Controls

Factory/Lab radial:

- A queues one unit normally.
- X removes one unit.
- RT+A queues five.
- RT+X removes five.
- LT+A issues `CMD.INSERT` with `{ 0, option.cmdID, 0 }` and shows the INSERT toast.

General front insertion:

- RB is `insertNextCommandModifier`.
- RB+A fronts compatible active build placement and staged commands through real `CMD.INSERT`.
- Parameters, facing, target IDs, and command options are preserved by wrapping `{ 0, cmdID, 0, ...params }` with outer `{ "alt" }`.
