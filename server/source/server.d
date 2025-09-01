import std.random;
import std.conv;
import std.stdio;
import std.exception;
import std.datetime.systime;
import std.format;
import std.file;
import std.regex;
import std.algorithm;
import std.array;
import std.typecons;

import vibe.vibe;

import game;
import terrain;
import gamesession;

const MAP_DIR = "maps";

class Server
{
	MapData[string] maps;
	GameSession[GameID] games;

	this(ushort port)
	{
		loadMaps();

		auto router = new URLRouter;
		router.registerWebInterface(this);

		auto settings = new HTTPServerSettings();
		settings.port = port;

		listenHTTP(settings, router);
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
		setTimer(5.minutes, () => removeIfNotStarted(id));

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
		if (!games[id].full)
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
		if (id !in games)
		{
			status(HTTPStatus.badRequest);
			return Json("Invalid game id: " ~ id.to!string);
		}

		if (name == "")
		{
			status(HTTPStatus.badRequest);
			return Json("Invalid name");
		}

		auto game = games[id];
		if (game.full)
		{
			status(HTTPStatus.badRequest);
			return Json("Game is full");
		}

		auto player = game.addPlayer(name);
		logInfo("Player %s joined game %d (#%d)", player.name, game.id, player.id);

		return JoinResponse(player.id, player.token).serializeToJson;
	}

	Json getGame(GameID id, Token token)
	{
		if (id !in games)
		{
			status(HTTPStatus.badRequest);
			return Json("Invalid game id: " ~ id.to!string);
		}

		auto game = games[id];
		if (!game.full)
		{
			status(HTTPStatus.badRequest);
			return Json("Game has not started");
		}

		if (token == game.adminToken)
			return game.fullState;

		if (game.playerTokens.canFind(token))
			return game.playerView(token);

		status(HTTPStatus.badRequest);
		return Json("Invalid token");
	}
}

void main()
{
	setLogFormat(FileLogger.Format.threadTime, FileLogger.Format.threadTime);

	auto server = new Server(8000);
	runApplication();

	writeln("Are we there yet?");
}
