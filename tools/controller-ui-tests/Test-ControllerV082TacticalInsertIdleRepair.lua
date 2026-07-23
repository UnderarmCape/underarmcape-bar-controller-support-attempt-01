local root = assert(arg and arg[1], "repository root argument required")
return assert(loadfile((root:gsub("\\", "/"):gsub("/$", "")) .. "/tools/controller-ui-tests/Test-ControllerV083SmartXInsertTacticalRepair.lua"))()
