local arena = require "arena"
local utils = require "utils"

local args = {...}

local host = args[1]
local gameid = args[2]
local name = args[3]

if not host or not gameid or not name then
	print "Usage: lua main.lua <host> <gameid> <name>"
end

local function callback(state, player)

	utils.printState(state)

	return {[0] = 0}
end

arena.runAgent(host, gameid, name, callback)
