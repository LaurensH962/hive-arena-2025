import std.stdio;
import std.algorithm;
import std.range;

import game;
import map;
import order;

void main()
{
	auto map = loadMap("map.txt");
	auto game = new GameState(map[0], map[1], 4);


	import vibe.data.json;
	writeln(serialize!JsonSerializer(game));
	writeln(serialize!JsonSerializer(game.map));
}
