#!/usr/bin/env bash

# set -xe

name="test"
host="localhost:8000"
token=
game_id=
map="balanced"

# start a new game
start_game() {
    map=$1
    match="$(curl "$host/newgame?map=$map&players=1")"
    token=$(echo $match | jq '.adminToken' | tr -d '"')
    game_id=$(echo $match | jq '.id' | tr -d '"')
}

game_url=

usage() {
    echo "Usage: ./match <map_name> <agent>"
}

fatal() {
    usage
    exit 1
}

main() {
    map=$1
    agent=$2
    if [[ -z $map || -z $agent ]]
    then
        fatal
    fi
    start_game $1
    # connect your agent to test
    go run ./$agent/ $host $game_id $name

    game_url="$(curl $host/history/ | grep "$game_id" | sed -E 's/.*>(.*)<.*/\1/')"
    echo "http://$host/history/$game_url"
    # run viewer
    go run ./viewer/ --url "http://$host/history/$game_url"
}

# provide map and agent as command line arguments
main $@