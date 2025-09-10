local json = require "lunajson"

local function req(host, route, method, payload)

	local http = require "http.request"
	local httph = require "http.headers"

	local headers

	if method == "POST" then
		headers = httph.new()
		headers:append(":method", "POST")
		headers:append("content-type", "application/json")
	end

	local req = http.new_from_uri(host .. route, headers)
	if payload then
		req:set_body(json.encode(payload))
	end

	local headers, stream = req:go()
	if not headers or not stream then
		print("Could not connect to " .. req.host .. ":" .. req.port)
		os.exit(1)
	end

	local status = headers:get(":status")
	local body = stream:get_body_as_string()
	if status ~= "200" then
		print(status, body)
		os.exit(1)
	end

	return json.decode(body)
end

local function joinGame(host, gameid, name)

	local q = string.format("?id=%s&name=%s", gameid, name)
	local res = req(host, "join" .. q)

	print("Joined game:" .. gameid, "token:", res.token, "player:", res.id)

	return res
end

local function getState(host, gameid, token)

	local q = string.format("?id=%s&token=%s", gameid, token)
	local res = req(host, "game" .. q)

	return res
end

local function sendOrders(host, gameid, token, orders)

	local q = string.format("?id=%s&token=%s", gameid, token)
	local res = req(host, "orders" .. q, "POST", orders)

	return res
end

local function openWebSocket(host, gameid)

	local ws = require "http.websocket"

	local socket = ws.new_from_uri(host .. "ws?id=" .. gameid)
	socket:connect()

	return socket
end

local function runAgent(host, gameid, name, callback)

	local joinInfo = joinGame(host, gameid, name)
	local token = joinInfo.token
	local player = joinInfo.id

	local socket = openWebSocket(host, gameid)

	for text in socket:each() do

		local message = json.decode(text)

		if message.gameOver then
			print("Game over")
			break
		else
			print("Turn " .. message.turn .. " starts")
		end

		local state = getState(host, gameid, token)
		local orders = callback(state, player)

		sendOrders(host, gameid, token, orders)
	end
end

return {
	joinGame = joinGame,
	openWebSocket = openWebSocket,
	runAgent = runAgent
}
