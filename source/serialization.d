import std.json;
import std.typecons;
import std.algorithm;
import std.array;
import std.conv;

import terrain;
import order;
import game;

JSONValue serialize(const Entity entity, const Coords position)
{
	JSONValue j;

	j["row"] = position.row;
	j["col"] = position.col;

	j["type"] = entity.type.to!string;
	j["hp"] = entity.hp;
	j["player"] = entity.player;

	return j;
}

Tuple!(Entity,Coords) deserializeEntity(JSONValue j)
{
	Coords pos = Coords(j["row"].get!int, j["col"].get!int);

	auto entity = new Entity(
		j["type"].get!string.to!(Entity.Type),
		hp: j["hp"].get!int,
		player: j["player"].get!PlayerID
	);

	return tuple(entity, pos);
}

JSONValue serialize(const Entity[Coords] entities)
{
	JSONValue[] j;
	foreach (coords, entity; entities)
		j ~= serialize(entity, coords);

	return JSONValue(j);
}

Entity[Coords] deserializeEntities(JSONValue j)
{
	Entity[Coords] entities;
	foreach (entity; j.array)
	{
		auto res = deserializeEntity(entity);
		entities[res[1]] = res[0];
	}
	return entities;
}

JSONValue serialize(const Map map, const uint[Coords] mapResources, const PlayerID[Coords] influence = null)
{
	JSONValue[] j;

	foreach (coords, terrain; map)
	{
		JSONValue t;
		t["row"] = coords.row;
		t["col"] = coords.col;
		t["type"] = terrain.to!string;

		if (terrain == Terrain.FIELD)
			t["resources"] = mapResources[coords];

		if (influence && coords in influence)
			t["influence"] = influence[coords];

		j ~= t;
	}

	return JSONValue(j);
}

Tuple!(Map, uint[Coords]) deserializeMap(JSONValue j)
{
	Map map;
	uint[Coords] flowers;

	foreach (t; j.array)
	{
		auto pos = Coords(t["row"].get!int, t["col"].get!int);
		auto terrain = t["type"].get!string.to!Terrain;

		map[pos] = terrain;

		if (terrain == Terrain.FIELD)
			flowers[pos] = t["resources"].get!uint;
	}

	return tuple(map, flowers);
}

JSONValue serialize(const GameState game)
{
	JSONValue j;

	j["numPlayers"] = game.numPlayers;
	j["map"] = serialize(game.staticMap, game.mapResources, game.influence);
	j["entities"] = serialize(game.entities);
	j["resources"] = game.playerResources;

	j["turn"] = game.turn;
	j["lastInfluenceChange"] = game.lastInfluenceChange;

	j["gameOver"] = game.gameOver;
	if (game.gameOver)
		j["winners"] = game.winners;

	return j;
}

GameState deserializeGameState(JSONValue j)
{
	auto map = deserializeMap(j["map"]);
	auto numPlayers = j["numPlayers"].get!PlayerID;

	auto game = new GameState(map[0], [], numPlayers);
	game.mapResources = map[1];
	game.entities = deserializeEntities(j["entities"]);
	game.playerResources = j["resources"].array.map!(i => i.get!uint).array;

	game.updateInfluence();

	game.turn = j["turn"].get!uint;
	game.lastInfluenceChange = j["lastInfluenceChange"].get!uint;

	game.gameOver = j["gameOver"].get!bool;

	if (game.gameOver)
		game.winners = j["winners"].array.map!(p => p.get!PlayerID).array;

	return game;
}

JSONValue serialize(const Order order)
{
	JSONValue j;

	j["row"] = order.coords.row;
	j["col"] = order.coords.col;
	j["player"] = order.player;
	j["status"] = order.status.to!string;

	if (auto targetOrder = cast(TargetOrder) order)
		j["direction"] = targetOrder.direction.to!string;

	string type;
	if (cast(MoveOrder) order) type = "MOVE";
	else if (cast(AttackOrder) order) type = "ATTACK";
	else if (cast(BuildWallOrder) order) type = "BUILD_WALL";
	else if (cast(BuildHiveOrder) order) type = "BUILD_HIVE";
	else if (cast(ForageOrder) order) type = "FORAGE";
	else if (cast(SpawnOrder) order) type = "SPAWN";

	j["type"] = type;

	return j;
}

Order deserializeOrder(JSONValue j, PlayerID player, GameState state)
{
	auto coords = Coords(j["row"].get!int, j["col"].get!int);
	auto type = j["type"].get!string;

	switch (type)
	{
		case "MOVE": return new MoveOrder(state, player, coords, j["direction"].get!string.to!Direction);
		case "ATTACK": return new AttackOrder(state, player, coords, j["direction"].get!string.to!Direction);
		case "BUILD_WALL": return new BuildWallOrder(state, player, coords, j["direction"].get!string.to!Direction);
		case "BUILD_HIVE": return new BuildHiveOrder(state, player, coords);
		case "FORAGE": return new ForageOrder(state, player, coords);
		case "SPAWN": return new SpawnOrder(state, player, coords, j["direction"].get!string.to!Direction);
		default: throw new Exception("Invalid order type:" ~ type);
	}
}
