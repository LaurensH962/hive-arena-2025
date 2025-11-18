package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"github.com/hajimehoshi/ebiten/v2"
	"github.com/hajimehoshi/ebiten/v2/ebitenutil"
	"io"
	"net/http"
	"slices"
)

import . "hive-arena/common"

const Dx = 32
const Dy = 16

var Tile1 *ebiten.Image

type Viewer struct {
	Game *PersistedGame
}

func (viewer *Viewer) Update() error {
	return nil
}

type CoordHex struct {
	Coords Coords
	Hex    *Hex
}

func (viewer *Viewer) Draw(screen *ebiten.Image) {
	state := viewer.Game.History[0].State

	hexes := []CoordHex{}
	for coords, hex := range state.Hexes {
		hexes = append(hexes, CoordHex{coords, hex})
	}
	slices.SortFunc(hexes, func(a, b CoordHex) int {
		return a.Coords.Row - b.Coords.Row
	})

	for _, h := range hexes {

		opt := ebiten.DrawImageOptions{}
		opt.GeoM.Translate(float64(Dx*h.Coords.Col/2), float64(Dy*h.Coords.Row))
		screen.DrawImage(Tile1, &opt)
	}
}

func (viewer *Viewer) Layout(outsideWidth, outsideHeight int) (screenWidth, screenHeight int) {
	return outsideWidth, outsideHeight
}

func GetURL(url string) *PersistedGame {
	res, err := http.Get(url)
	if err != nil {
		fmt.Println(err)
		return nil
	}

	body, err := io.ReadAll(res.Body)
	res.Body.Close()

	if res.StatusCode > 299 {
		fmt.Printf("Response failed with status code: %d and\nbody: %s\n", res.StatusCode, body)
		return nil
	}

	if err != nil {
		fmt.Println(err)
		return nil
	}

	var game PersistedGame
	err = json.Unmarshal(body, &game)

	if err != nil {
		fmt.Println(err)
		return nil
	}

	return &game
}

func LoadResources() {
	Tile1, _, _ = ebitenutil.NewImageFromFile("tile.png")
}

func main() {
	url := flag.String("url", "", "URL of the history file to view")
	flag.Parse()

	if *url == "" {
		flag.PrintDefaults()
		return
	}

	game := GetURL(*url)
	if game == nil {
		return
	}

	fmt.Println(game)

	LoadResources()

	ebiten.SetWindowSize(1024, 768)
	ebiten.SetWindowTitle("Hive Arena Viewer")
	ebiten.SetWindowResizingMode(ebiten.WindowResizingModeEnabled)

	viewer := &Viewer{
		Game: game,
	}
	err := ebiten.RunGame(viewer)

	if err != nil {
		fmt.Println(err)
	}
}
