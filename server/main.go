package main

import (
	"flag"
	"fmt"
	"runtime/debug"
)

func PrintGitRevision() {
	buildInfo, _ := debug.ReadBuildInfo()
	for _, info := range buildInfo.Settings {
		if info.Key == "vcs.revision" {
			fmt.Printf("git revision: %s\n", info.Value)
			break
		}
	}
}

func main() {
	port := flag.Int("p", 8000, "port on which the server will listen")
	flag.Parse()

	PrintGitRevision()
	RunServer(*port)
}
