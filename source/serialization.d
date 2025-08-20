import std.json;
import std.typecons;
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
		j["hp"].get!int,
		j["player"].get!ubyte
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

JSONValue serialize(const Map map, const uint[Coords] fieldFlowers, const ubyte[Coords] influence = null)
{
	JSONValue[] j;

	foreach (coords, terrain; map)
	{
		JSONValue t;
		t["row"] = coords.row;
		t["col"] = coords.col;
		t["type"] = terrain.to!string;

		if (terrain == Terrain.FIELD)
			t["flowers"] = fieldFlowers[coords];

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
			flowers[pos] = t["flowers"].get!uint;
	}

	return tuple(map, flowers);
}

JSONValue serialize(const GameState game, bool includeInfluence = false)
{
	JSONValue j;

	j["numPlayers"] = game.numPlayers;
	j["map"] = serialize(game.staticMap, game.fieldFlowers, includeInfluence ? game.influence : null);
	j["entities"] = serialize(game.entities);
	j["resources"] = game.playerFlowers;

	return j;
}

GameState deserializeGameState(JSONValue j)
{
	auto map = deserializeMap(j["map"]);
	auto numPlayers = j["numPlayers"].get!ubyte;

	auto game = new GameState(map[0], [], numPlayers);
	game.fieldFlowers = map[1];
	game.entities = deserializeEntities(j["entities"]);

	foreach (v; j["resources"].array)
		game.playerFlowers ~= v.get!uint;

	game.updateInfluence();

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

Order deserializeOrder(JSONValue j)
{
	auto coords = Coords(j["row"].get!int, j["col"].get!int);
	auto player = j["player"].get!ubyte;
	auto type = j["type"].get!string;

	switch (type)
	{
		case "MOVE": return new MoveOrder(null, player, coords, j["direction"].get!string.to!Direction);
		case "ATTACK": return new AttackOrder(null, player, coords, j["direction"].get!string.to!Direction);
		case "BUILD_WALL": return new BuildWallOrder(null, player, coords, j["direction"].get!string.to!Direction);
		case "BUILD_HIVE": return new BuildHiveOrder(null, player, coords);
		case "FORAGE": return new ForageOrder(null, player, coords);
		case "SPAWN": return new SpawnOrder(null, player, coords, j["direction"].get!string.to!Direction);
		default: throw new Exception("Invalid order type:" ~ type);
	}
}
