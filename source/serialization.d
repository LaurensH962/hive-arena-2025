import std.json;
import std.typecons;

import terrain;
import order;
import game;

JSONValue serialize(Entity entity, Coords position)
{
	JSONValue j;

	j["row"] = position.row;
	j["col"] = position.col;
	j["hp"] = entity.hp;

	if (auto unit = cast(Unit) entity)
		j["player"] = unit.player;

	if (cast(Wall) entity)
		j["type"] = "wall";
	else if (cast(Bee) entity)
		j["type"] = "bee";
	else if (cast(Hive) entity)
		j["type"] = "hive";

	return j;
}

Tuple!(Entity,Coords) deserializeEntity(JSONValue j)
{
	Coords pos = Coords(j["row"].get!int, j["col"].get!int);
	Entity entity;

	switch (auto type = j["type"].get!string)
	{
		case "wall":
			entity = new Wall(j["hp"].get!int);
			break;
		case "bee":
			entity = new Bee(j["player"].get!ubyte, j["hp"].get!int);
			break;
		case "hive":
			entity = new Hive(j["player"].get!ubyte, j["hp"].get!int);
			break;
		default:
			throw new Exception("Unknown entity type: " ~ type);
	}

	return tuple(entity, pos);
}

JSONValue serialize(Entity[Coords] entities)
{
	JSONValue[] j;
	foreach(coords, entity; entities)
		j ~= serialize(entity, coords);

	return JSONValue(j);
}

Entity[Coords] deserializeEntities(JSONValue j)
{
	Entity[Coords] entities;
	foreach(entity; j.array)
	{
		auto res = deserializeEntity(entity);
		entities[res[1]] = res[0];
	}
	return entities;
}
