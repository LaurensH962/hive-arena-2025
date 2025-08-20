import std.stdio;
import std.json;
import std.getopt;
import std.algorithm;

import game;
import terrain;
import order;
import serialization;

void process(JSONValue data)
{
	auto game = deserializeGameState(data["gamestate"]);
	auto orders = data["orders"].array.map!(arr => arr.array.map!deserializeOrder);
}

void main(string[] args)
{
	string mapPath;
	ubyte players;
	string toProcess;

	getopt(args,
		"map", &mapPath,
		"players", &players,
		"process", &toProcess
	);

	if (mapPath.length != 0)
	{
		auto map = loadMap(mapPath);
		auto game = new GameState(map[0], map[1], players);

		writeln(serialize(game));
	}
	else if (toProcess.length != 0)
	{
		import std.file;

		auto txt = readText(toProcess);
		auto data = parseJSON(txt);

		process(data);
	}
	else
	{
		writeln("Usage:");
		writeln(args[0], " --map=<map file> --players=<number of players to spawn>");
		writeln(args[0], " --process=<json formatted game state and orders>");
	}
}
