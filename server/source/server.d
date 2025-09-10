import std.algorithm;
import std.array;
import std.file;
import std.random;
import std.regex;
import std.stdio;

import vibe.vibe;

import game;
import terrain;
import gamesession;

const MAP_DIR = "maps";
const HISTORY_DIR = "history";
const GAME_START_TIMEOUT = 5.minutes;

class Server
{
	MapData[string] maps;
	GameSession[GameID] games;

	this(ushort port)
	{
		loadMaps();

		auto fsettings = new HTTPFileServerSettings;
		fsettings.serverPathPrefix = "/history";

		auto router = new URLRouter;
		router.registerWebInterface(this);
		router.get("/history/*", serveStaticFiles(HISTORY_DIR ~ "/", fsettings));
		router.get("/ws", &startWebsocket);

		auto settings = new HTTPServerSettings();
		settings.port = port;

		listenHTTP(settings, router);

		setTimer(GAME_START_TIMEOUT, &removeFinishedGames, periodic: true);

		if (!exists(HISTORY_DIR))
			mkdir(HISTORY_DIR);
	}

	private void loadMaps()
	{
		foreach (path; dirEntries(MAP_DIR, SpanMode.shallow))
		{
			auto name = path.name.matchFirst(r"/(\w+)\.txt")[1];
			auto map = loadMap(path);

			map.name = name;
			maps[name] = map;
		}

		logInfo("Loaded maps: " ~ maps.keys.join(", "));
	}

	private void removeFinishedGames()
	{
		auto finished = games.values.filter!(g => g.state.gameOver).map!(g => g.id).array;
		foreach(id; finished)
		{
			persistGame(games[id]);
			games.remove(id);
			logInfo("Removed finished game %d", id);
		}
	}

	struct NewGameResponse
	{
		GameID id;
		PlayerID numPlayers;
		string map;
		SysTime createdDate;
		Token adminToken;
	}

	Json getNewgame(int players, string map)
	{
		GameID id;
		do { id = uniform!GameID; } while (id in games);

		if (map !in maps)
		{
			status(HTTPStatus.badRequest);
			return Json("Unknown map: " ~ map);
		}

		if (!GameState.validNumPlayers(players))
		{
			status(HTTPStatus.badRequest);
			return Json("Invalid player count: " ~ players.to!string);
		}

		auto game = new GameSession(id, players, maps[map]);
		games[id] = game;

		logInfo("Created game %d (%s, %d players)", id, map, players);
		setTimer(GAME_START_TIMEOUT, () => removeIfNotStarted(id));

		return NewGameResponse(
			id: game.id,
			numPlayers: game.state.numPlayers,
			map: game.map,
			createdDate: game.createdDate,
			adminToken: game.adminToken
		).serializeToJson;
	}

	private void removeIfNotStarted(GameID id)
	{
		if (id in games && !games[id].full)
		{
			games.remove(id);
			logInfo("Removed game %d because of timeout", id);
		}
	}

	struct StatusResponse
	{
		GameID id;
		PlayerID numPlayers;
		PlayerID playersJoined;
		string map;
		SysTime createdDate;
	}

	Json getStatus()
	{
		return games.values.map!(game => StatusResponse(
			id: game.id,
			numPlayers: game.state.numPlayers,
			playersJoined: cast(PlayerID) game.players.length,
			map: game.map,
			createdDate: game.createdDate
		)).array.serializeToJson;
	}

	struct JoinResponse
	{
		PlayerID id;
		Token token;
	}

	Json getJoin(GameID id, string name)
	{
		auto game = id in games;
		if (!game)
		{
			status(HTTPStatus.badRequest);
			return Json("Invalid game id: " ~ id.to!string);
		}

		if (name == "")
		{
			status(HTTPStatus.badRequest);
			return Json("Invalid name");
		}

		if (game.full)
		{
			status(HTTPStatus.badRequest);
			return Json("Game is full");
		}

		auto player = game.addPlayer(name);
		logInfo("Player %s joined game %d (#%d)", player.name, game.id, player.id);

		if (game.full)
		{
			setTimer(1.seconds, () {
				logInfo("Game %d started", id);
				game.startNextTurn();
			});
		}

		return JoinResponse(player.id, player.token).serializeToJson;
	}

	Json getGame(GameID id, Token token)
	{
		auto game = id in games;
		if (!game)
		{
			status(HTTPStatus.badRequest);
			return Json("Invalid game id: " ~ id.to!string);
		}

		if (!game.full)
		{
			status(HTTPStatus.badRequest);
			return Json("Game has not started");
		}

		if (token == game.adminToken)
			return game.fullState;

		auto player = game.getPlayer(token);
		if (!player)
		{
			status(HTTPStatus.forbidden);
			return Json("Invalid token");
		}

		if (game.pulledState[player.id])
		{
			status(HTTPStatus.tooManyRequests);
			return Json("State already pulled for this turn");
		}

		game.pulledState[player.id] = true;
		return game.playerView(player);
	}

	Json postOrders(GameID id, Token token)
	{
		auto game = id in games;
		if (!game)
		{
			status(HTTPStatus.badRequest);
			return Json("Invalid game id: " ~ id.to!string);
		}

		if (game.state.gameOver)
		{
			status(HTTPStatus.badRequest);
			return Json("Game over");
		}

		auto player = game.getPlayer(token);
		if (!player)
		{
			status(HTTPStatus.forbidden);
			return Json("Invalid token");
		}

		if (game.playedTurn[player.id])
		{
			status(HTTPStatus.tooManyRequests);
			return Json("Orders already sent for this turn");
		}

		auto orders = deserializeJson!(Order[])(request.json);
		game.setOrders(player.id, orders);

		logInfo("Player %s posted orders in game %d", player.name, id);
		return Json("OK");
	}

	struct FinishedGame
	{
		GameID id;
		string map;
		SysTime createdDate;
		GameState state;
		Order[][] orderHistory;
	}

	private void persistGame(GameSession game)
	{
		assert(game.state.gameOver);

		auto path = format("%s/%s-%d-%s.json",
			HISTORY_DIR,
			game.createdDate.toISOString,
			game.id,
			game.map
		);

		FinishedGame(
			game.id,
			game.map,
			game.createdDate,
			game.state,
			game.orderHistory
		).serializeToJsonString.toFile(path);
	}

	Json getHistory()
	{
		return dirEntries(HISTORY_DIR, SpanMode.shallow)
			.map!(e => e.name)
			.array
			.serializeToJson;
	}

	private void startWebsocket(HTTPServerRequest req, HTTPServerResponse res)
	{
		auto id = req.query["id"].to!GameID;

		auto game = id in games;
		if (!game)
		{
			res.writeBody("Invalid game id: " ~ id.to!string);
			res.statusCode = HTTPStatus.badRequest;
			return;
		}

		handleWebSocket((scope WebSocket socket)
		{
			game.sockets ~= socket;

			while (socket.waitForData)
				auto text = socket.receiveText;

			socket.close();
			game.sockets = game.sockets.remove!(s => s == socket);

		}, req, res);
	}
}

void main()
{
	setLogFormat(FileLogger.Format.threadTime, FileLogger.Format.threadTime);

	auto server = new Server(8000);
	runApplication();
}
