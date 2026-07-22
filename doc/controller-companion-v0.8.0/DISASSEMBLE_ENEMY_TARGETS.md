# Enemy Disassemble targets

Owned eligible constructors remain the command source. Enemy units, enemy structures, friendly targets, and factories may remain reclaim targets; factories never become reclaimers. Direct X and LB+A tap reclaim paths are unchanged.

LB+A hold captures the hovered target ID, UnitDefID, and position, then starts the controller-owned green reclaim-area gesture. Releasing A/LB only arms confirmation. The reticle changes radius, and a fresh A or X submits `{targetID,x,y,z,r}` through Smart Reclaim's completed-area adapter. The target does not need to be selectable or part of player selection.

Candidate highlighting continues to use the current same-type filter. B cancels, clears candidates, restores constructor selection, and leaves Disassemble active. Accepted dispatch records activity and resets the inactivity timer without exiting the mode. Native reclaim eligibility and Recoil rejection remain authoritative.
