-- Compatibility entry point. The v0.8 input-polish suite supersedes the old
-- unused-timeout and fixed-anchor Disassemble assumptions.
local root = assert(arg[1], "repository root argument required"):gsub("[\\/]$", "")
assert(loadfile(root .. "/tools/controller-ui-tests/Test-ControllerInputPolish.lua"))()
