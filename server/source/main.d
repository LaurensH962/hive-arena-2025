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

import vibe.vibe;

import game;
import terrain;

const MAP_DIR = "maps";

alias GameID = uint;
alias Token = string;

class Player
{
	PlayerID player;
	Token token;
}

class Game
{
	GameID id;
	int numPlayers;
	string map;

	SysTime createdDate;

	Token adminToken;
	Token[] playerTokens;

	Player[] players;

	GameState state;

	static Token[] generateTokens(int count)
	{
		bool[Token] tokens;

		while (tokens.length < count)
		{
			auto token = format("%x", uniform!ulong);
			tokens[token] = true;
		}

		return tokens.keys;
	}

	this(GameID id, int numPlayers, MapData map)
	{
		this.id = id;
		this.numPlayers = numPlayers;
		this.map = map.name;

		createdDate = Clock.currTime;

		auto tokens = generateTokens(numPlayers + 1);
		adminToken = tokens[0];
		playerTokens = tokens[1 .. $];

		state = new GameState(map, numPlayers);
	}

	Player addPlayer()
	{
		if (full)
			throw new Exception("Game is full");

		auto player = new Player();
		player.player = cast(PlayerID) players.length;
		player.token = playerTokens[player.player];

		players ~= player;
		return player;
	}

	bool full()
	{
		return players.length == numPlayers;
	}
}

class Server
{
	MapData[string] maps;
	Game[GameID] games;

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
		int numPlayers;
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

		Game game = new Game(id, players, maps[map]);
		games[id] = game;

		return NewGameResponse(
			id: game.id,
			numPlayers: game.numPlayers,
			map: game.map,
			createdDate: game.createdDate,
			adminToken: game.adminToken
		).serializeToJson;
	}

	struct StatusResponse
	{
		GameID id;
		uint numPlayers;
		uint playersJoined;
		string map;
		SysTime createdDate;
	}

	Json getStatus()
	{
		return games.values.map!(game => StatusResponse(
			id: game.id,
			numPlayers: game.numPlayers,
			playersJoined: cast(int) game.players.length,
			map: game.map,
			createdDate: game.createdDate
		)).array.serializeToJson;
	}

	Json getJoin(GameID id)
	{
		if (id !in games)
		{
			status(HTTPStatus.badRequest);
			return Json("Invalid game id: " ~ id.to!string);
		}

		auto game = games[id];
		if (game.full)
		{
			status(HTTPStatus.badRequest);
			return Json("Game is full");
		}

		auto player = game.addPlayer();
		return player.serializeToJson;
	}
}

void main()
{
	auto server = new Server(8000);
	runApplication();

	writeln("Are we there yet?");
}
