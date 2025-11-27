package main

import (
	"bytes"
	"image"

	"github.com/hajimehoshi/ebiten/v2"
	"github.com/hajimehoshi/ebiten/v2/examples/resources/fonts"
	"github.com/hajimehoshi/ebiten/v2/text/v2"

	. "hive-arena/common"

	_ "embed"
)

var TerrainTiles map[Terrain]*ebiten.Image
var EmptyFieldTile *ebiten.Image
var FlowerImage *ebiten.Image

var EntityTiles map[EntityType]*ebiten.Image
var EntityOffset = map[EntityType]float64{
	BEE:  8,
	HIVE: 12,
	WALL: 8,
}

//go:embed tile-empty.png
var TileEmpty []byte

//go:embed tile-rock.png
var TileRock []byte

//go:embed tile-field.png
var TileField []byte

//go:embed tile-field-empty.png
var TileFieldEmpty []byte

//go:embed bee.png
var SpriteBee []byte

//go:embed hive.png
var SpriteHive []byte

//go:embed wall.png
var SpriteWall []byte

//go:embed flower.png
var SpriteFlower []byte

func loadImage(data []byte) *ebiten.Image {
	img, _, _ := image.Decode(bytes.NewReader(data))
	return ebiten.NewImageFromImage(img)
}

var Font *text.GoTextFace

func LoadResources() {
	TerrainTiles = make(map[Terrain]*ebiten.Image)

	TerrainTiles[EMPTY] = loadImage(TileEmpty)
	TerrainTiles[ROCK] = loadImage(TileRock)
	TerrainTiles[FIELD] = loadImage(TileField)
	EmptyFieldTile = loadImage(TileFieldEmpty)

	EntityTiles = make(map[EntityType]*ebiten.Image)

	EntityTiles[BEE] = loadImage(SpriteBee)
	EntityTiles[HIVE] = loadImage(SpriteHive)
	EntityTiles[WALL] = loadImage(SpriteWall)
	EntityTiles[WALL] = loadImage(SpriteWall)
	FlowerImage = loadImage(SpriteFlower)

	fontSource, _ := text.NewGoTextFaceSource(bytes.NewReader(fonts.PressStart2P_ttf))
	Font = &text.GoTextFace{
		Source: fontSource,
		Size:   16,
	}
}
