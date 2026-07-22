# Legacy Sunset Map

Public v0.7.0 and its tag are immutable. This experimental branch keeps `Native Experimental` and `Legacy Controller UI` mutually exclusive.

| Legacy responsibility | Native replacement | Current decision | Deletion gate |
|---|---|---|---|
| Build option discovery/classification | vanilla cells + hybrid adapter; v0.7 classifier fallback | keep fallback | BAR exports reliable categories across factions |
| Factory build/queue execution | vanilla Build Menu activation | Native uses vanilla; Legacy retained | live queue/dequeue approval across labs |
| Tactical template discovery | vanilla Order Menu descriptors | Native bypass removed; templates Legacy-only | mixed-selection and state approval |
| Tactical state cycling | Order Menu state activation | Native state values are descriptor-owned | Fire/Move/binary live approval |
| Controller build placement | no equivalent complete controller system | keep v0.7 placement | not a legacy-deletion candidate |
| Custom selection mutation | SmartSelect | disabled in Native | broad selection approval |
| Marked-target reclaim | Smart Area Reclaim | disabled in Native | reclaim/disassemble approval |
| v0.7 radial renderer | no vanilla replacement intended | permanent controller presentation | not a sunset candidate |

Changing integration mode closes active Build/Tactical radials, clears native focus/capture, resets build placement to Single, invalidates adapter caches, refreshes hints, and preserves engine selection.

Legacy code is ready for later deletion only after multiple constructors/factories, tactical mixed selections, native selection/reclaim, rollback, performance, and focus synchronization have passed the live checklist. Panel hiding is a separate later change; it does not require returning to legacy execution.
