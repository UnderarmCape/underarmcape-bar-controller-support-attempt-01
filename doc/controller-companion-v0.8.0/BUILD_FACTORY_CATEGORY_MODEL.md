# Build and Factory category model

Constructor wheels use the fixed order Economy, Build, Utility, Combat. BAR `customParams.unitgroup` is consulted first. Resource production/storage/conversion maps to Economy; factories, labs, gantries, construction turrets, nano infrastructure, and constructor-producing structures map to Build; sensors, shields, support, and transport structures map to Utility; armed defenses map to Combat.

Factory wheels use Constructors, Utility, Combat. Mobile builders are Constructors. Scouts, transports, radar/jammer/sonar units, and other support units are Utility even if an incidental weapon sets `canAttack`. Remaining armed products are Combat. Native build command IDs and queue quantities are never rewritten.

Metadata and capability checks are authoritative. Two small exact-name override tables cover known ambiguity only: `armnanotc`, `cornanotc`, and `legnanotc` remain Build; `armflea`, `armfav`, `corfav`, `legscout`, and `legscoutveh` remain Utility. Classification is cached by context plus UnitDef ID and is deterministic.
