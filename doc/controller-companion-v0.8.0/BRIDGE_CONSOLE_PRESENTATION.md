# Bridge Console Presentation

`Shared/BridgeConsole.cs` renders a compact 68-column ASCII frame with aligned Camera, UDP, Controller, and Engine rows. Session updates include the tracked Spring/Recoil PID; Ctrl+C guidance remains visible.

Interactive consoles use `ConsoleColor` for heading, success, waiting, warning, and error states. Redirected output and `NO_COLOR` disable color. No ANSI escape sequence is generated, and non-ASCII log characters are replaced so default Windows consoles remain readable. Lifecycle, packet format, polling, and shutdown behavior are unchanged.
