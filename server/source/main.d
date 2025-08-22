import std.random;
import std.conv;
import std.stdio;
import std.exception;
import std.datetime.systime;
import std.format;

import vibe.vibe;

import game;
import terrain;

const MAP_DIR = "maps";

alias GameID = uint;
alias Token = string;

class Game
{
	GameID id;
	int numPlayers;
	string map;

	SysTime createdDate;

	Token adminToken;
	Token[] playerTokens;

	@ignore	GameState state;

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

	this(GameID id, int numPlayers, string map)
	{
		this.id = id;
		this.numPlayers = numPlayers;
		this.map = map;

		createdDate = Clock.currTime;

		auto tokens = generateTokens(numPlayers + 1);
		adminToken = tokens[0];
		playerTokens = tokens[1 .. $];

		auto mapData = loadMap(MAP_DIR ~ "/" ~ map ~ ".txt");
		state = new GameState(mapData[0], mapData[1], numPlayers);
	}
}

class Server
{
	Game[GameID] games;

	this(ushort port)
	{
		auto router = new URLRouter;
		router.registerWebInterface(this);

		auto settings = new HTTPServerSettings();
		settings.port = port;

		listenHTTP(settings, router);
	}

	Json getNewgame(int players, string map)
	{
		GameID id;
		do { id = uniform!GameID; } while (id in games);

		try
		{
			auto game = new Game(id, players, map);
			games[id] = game;

			return game.serializeToJson;
		}
		catch (ErrnoException e)
		{
			status(HTTPStatus.badRequest);
			return Json("Unknown map: " ~ map);
		}
		catch (Exception e)
		{
			status(HTTPStatus.badRequest);
			return Json(e.msg);
		}
	}

	Json getStatus()
	{
		return games.serializeToJson;
	}
}

void main()
{
	auto server = new Server(8000);
	runApplication();

	writeln("Are we there yet?");
}
