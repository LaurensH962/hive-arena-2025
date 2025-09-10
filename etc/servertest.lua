local http = require "http.request"
local httph = require "http.headers"
local ws = require "http.websocket"
local json = require "lunajson"

local host = "http://localhost:8000/"

local function req(route, ...)
	local headers, stream = http.new_from_uri(string.format(host .. route, ...)):go()
	local body = stream:get_body_as_string()

	local success, res = pcall(json.decode, body)
	if success then
		return res
	else
		print(body)
	end
end

local function post(route, payload, ...)

	local headers = httph.new()
	headers:append(":method", "POST")
	headers:append("content-type", "application/json")

	local req = http.new_from_uri(string.format(host .. route, ...), headers)
	req:set_body(json.encode(payload))

	local headers, stream = req:go()
	local body = stream:get_body_as_string()

	local success, res = pcall(json.decode, body)
	if success then
		return res
	else
		print(body)
	end
end

local function start_game(players, map)

	local game = req("newgame?players=%d&map=%s", players, map)
	game.players = {}

	for i = 1, game.numPlayers do
		local player = req("join?id=%d&name=%s", game.id, "coolplayer" .. math.random(1000000))
		table.insert(game.players, player)
	end

	return game
end

local g = start_game(math.random(2,6), "balanced")

print(json.encode(g))

print("Admin view")
local state = req("game?id=%d&token=%s", g.id, g.adminToken)
print(json.encode(state))

while false do

	for i,player in ipairs(g.players) do
		print("View from player ", player.id)
		local state = req("game?id=%d&token=%s", g.id, player.token)
		print(json.encode(state))

		local orders = {
			{
				type = "MOVE",
				direction = "E",
				coords = "1,1"
			}
		}

		local res = post("orders?id=%d&token=%s", orders, g.id, player.token)
		print(json.encode(res))
	end

end
