# Version and session lifecycle

`tools/controller-companion/Directory.Build.props` is the authoritative source for semantic version `0.8.1`, channel `Experimental`, and display version `v0.8.1 Experimental`. `ProductMetadata` derives the bridge banner, installer name, restore name, and application display strings from assembly informational metadata. Package scripts parse the same props file. The public v0.7.0 workflow is frozen and unchanged.

The bridge prints exactly `BAR Controller Bridge v0.8.1 Experimental`. In normal session mode, `EngineSessionTracker` waits indefinitely until a Spring or Recoil process appears, remembers its PID and start time, follows only a newer Spring/Recoil transition during a bounded three-second grace period, and stops after the tracked session is gone. A never-attached bridge does not self-terminate. `--standalone` disables session tracking for manual/settings use. Normal scope disposal closes the UDP socket, and console output is flushed on exit. No process is killed.

Static and .NET tests cover the central strings, never-attached state, PID attachment, Spring-to-Recoil transition, grace period, and terminal exit. Actual process attachment remains part of the live checklist.
