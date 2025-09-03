local json = require "lunajson"

local function runRaw(command, input)
	local path = os.tmpname()
	local fp = io.popen(command .. " > " .. path, "w")
	fp:write(input or "")
	fp:close()

	fp = io.open(path, "r")
	local res = fp:read("a")
	fp:close()

	return res
end

local function run(command, input)
	return json.decode(runRaw(command, input and json.encode(input) or nil))
end

local function printState(s)
	io.write(runRaw("lua etc/gamestate_print.lua", json.encode(s)))
end

local function parseCoords(c)
	local row,col = c:match("(%d+),(%d+)")
	return tonumber(row), tonumber(col)
end

local directions = {"NW", "NE", "E", "SE", "SW", "W"}
local directionOffsets = {
	E = {0, 2},
	NE = {-1, 1},
	NW = {-1, -1},
	W = {0, -2},
	SW = {1, -1},
	SE = {1, 1}
}

local function neighbour(coords, dir)
	local offset = directionOffsets[dir]
	local row, col = parseCoords(coords)
	return (row + offset[1]) .. "," .. (col + offset[2])
end

local function findEnemyEntity(coords, hexes, player)

	for _,dir in ipairs(directions) do
		local n = neighbour(coords, dir)
		if hexes[n] and hexes[n].entity and hexes[n].entity.player ~= player then
			return dir
		end
	end
end

local function makeOrders(state, player, index)

	local orders = {}

	for coords,hex in pairs(state.hexes) do
		local unit = hex.entity
		if unit and unit.type == "BEE" and unit.player == player then

			local terrain = hex.terrain
			local enemyDir = findEnemyEntity(coords, state.hexes, player)

			local type = "MOVE"

			if enemyDir then
				type = "ATTACK"
			elseif terrain == "FIELD" and hex.resources and hex.resources > 0 then
				type = "FORAGE"
			elseif hex.influence ~= player and state.playerResources[player + 1] >= 24 then
				type = "BUILD_HIVE"
			elseif math.random() < 0.001 then
				type = "BUILD_WALL"
			end

			local order = {
				coords = coords,
				type = type,
				direction = enemyDir or directions[math.random(1, #directions)]
			}

			table.insert(orders, order)

		elseif unit and unit.type == "HIVE" and unit.player == player then
			if state.playerResources[player + 1] >= 64 then

				local order = {
					coords = coords,
					type = "SPAWN",
					direction = directions[math.random(1, #directions)]
				}

				table.insert(orders, order)
			end
		end
	end

	if #orders == 0 then	-- help lunajson know this is an array
		orders[0] = 0
	end

	return orders
end

local function runGame()
	local state = run("cli/arena_cli --map=maps/balanced.txt --players=4")

	while not state.gameOver do

		local porders = {}
		for p = 0, state.numPlayers - 1 do
			table.insert(porders, makeOrders(state, p, index))
		end

		local payload = {
			state = state,
			orders = porders
		}

		local result = run("cli/arena_cli", payload)

		state = result.state
		print(json.encode(result.processed))
		printState(state)
	end

end

runGame()
