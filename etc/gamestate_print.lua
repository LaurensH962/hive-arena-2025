local json = require "lunajson"		-- luarocks install lunajson

local args = {...}
local txt

if #args == 1 then
	txt = io.open(args[1]):read("a")
else
	txt = io.stdin:read("a")
end

local data = json.decode(txt)

local top,bottom,left,right

for i,v in ipairs(data.map) do
	top = top and math.min(top, v.row) or v.row
	bottom = bottom and math.max(bottom, v.row) or v.row
	left = left and math.min(left, v.col) or v.col
	right = right and math.max(right, v.col) or v.col
end

local lines = {}
for i = top, bottom do
	lines[i] = {}
end

local terrainToChar = {
	EMPTY = ".",
	ROCK = "S",
	FIELD = "F"
}

local entityToChar = {
	BEE = "B",
	HIVE = "H",
	WALL = "W"
}

for i,v in ipairs(data.map) do
	local c = terrainToChar[v.type]
	lines[v.row][v.col] = c
end

for i,v in ipairs(data.entities) do
	local c = entityToChar[v.type] .. v.player
	lines[v.row][v.col] = c
end

for row = top,bottom do
	for col = left,right do
		local s = lines[row][col] or " "
		io.write(s .. string.rep(" ", 2 - #s))
	end
	io.write "\n"
end

print("Resources: ", table.concat(data.resources, ", "))
print("Game over:", data.gameOver)
if (data.gameOver) then
	print("Winners:", table.concat(data.winners, ", "))
end
