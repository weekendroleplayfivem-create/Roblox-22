--[[
	DevConfig
	Developer command access. Commands work ONLY:
	  * in Roblox Studio, or
	  * in a private server for a UserId listed in AuthorizedUserIds.
	They never work in public live servers.
]]

local TableUtil = require(script.Parent.Parent.Modules.TableUtil)

local DevConfig = {
	AuthorizedUserIds = {
		-- Add your Roblox UserId(s) here, e.g. 12345678,
	},
	CommandPrefix = "/vr",
	RunTestsOnStudioStart = true,
}

return TableUtil.DeepFreeze(DevConfig)
