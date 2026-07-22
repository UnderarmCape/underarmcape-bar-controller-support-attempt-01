# Controller input priority

The camera update uses modal ownership before normal actions. A consumed press
is not reconsidered by a lower layer.

| Input | Highest to lowest priority |
| --- | --- |
| A / X | Anchored native target-session confirm; build placement; Factory queue quantity; Tactical sub-radial; Disassemble target/reclaim; normal selection or Smart X |
| B | Native target cancel; placement cancel; active radial close; Disassemble double-B/timeout rules; normal clear selection |
| RB | Back/View+RB Tactical toggle; Tactical modal ownership; open Build/Factory next page; distributed/shoulder chord; closed eligible Build/Factory open; otherwise no-op |
| LB | Open Build/Factory previous page; placement Grid modifier; Tactical/command modifier; shoulder chord; other gameplay action |
| Back/View | Back/View+RB toggle and safety chords before standalone Back/View controls |
| D-pad Left/Right | Active radial/category or settings navigation; otherwise live Idle Builders previous/next API |

The Back/View+RB latch owns both the press and its release. Native targeting is
checked before active-engine-command queries and before normal A/X handlers.
Build/Factory and Tactical shoulder handling are mutually exclusive while a
radial is open.
