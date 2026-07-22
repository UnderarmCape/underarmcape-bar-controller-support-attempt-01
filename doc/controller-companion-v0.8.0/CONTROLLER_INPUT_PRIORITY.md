# Controller input priority

A consumed edge is never reconsidered by a lower layer.

| Input | Highest to lowest priority |
| --- | --- |
| A / X | controller point/area/front/rectangle targeting; build placement; Factory quantity; Tactical item or direct state cycle; Disassemble; normal A/Smart X |
| B | target cancellation; placement cancellation; active radial close; Disassemble sub-operation/double-B; normal clear |
| RB / LB | active Build/Factory global packed-page traversal; modal quantity/state action; shoulder chord only when explicitly eligible |
| D-pad | settings/modal; active radial; placement; normal live-idle navigation |

The root update services hybrid targeting before Disassemble and normal selection, preventing a second A/X from leaking. A Tactical radial selection closes and arms neutral waiting before any normal action. Build/Factory shoulder traversal clears chord state. Idle navigation is reached only after every higher-priority modal declines the input. Legacy Controller UI retains its separate existing paths.
