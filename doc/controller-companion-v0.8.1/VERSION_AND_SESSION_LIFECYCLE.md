# Version and Session Lifecycle

`tools/controller-companion/Directory.Build.props` is authoritative for:

- semantic version: `0.8.1`
- channel: `Experimental`
- display version: `v0.8.1 Experimental`

`ProductMetadata` derives the bridge banner, installer filename, restore filename, and application display strings from that central metadata. The bridge banner is exactly:

```text
BAR Controller Bridge v0.8.1 Experimental
```

The session lifecycle remains unchanged from v0.8.0:

- the bridge waits for Spring/Recoil when not launched in standalone mode;
- it tracks the attached engine PID;
- it allows a bounded Spring-to-Recoil transition grace period;
- it exits after the tracked game process is gone;
- it never kills BAR or controller processes.

Tests cover the central metadata, console banner, attach/wait/transition/exit lifecycle, and redirected-console formatting.

