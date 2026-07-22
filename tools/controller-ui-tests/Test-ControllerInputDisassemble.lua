-- Compatibility entry point retained for existing deployment tooling.
-- The authoritative atomic input/disassemble/hint suite now contains the
-- prompt-mandated exact 152 cases.
local root = assert(arg[1], "repository root argument required"):gsub("[\\/]$", "")
local suite = assert(loadfile(root .. "/tools/controller-ui-tests/Test-ControllerInputPolish.lua"))
suite()
