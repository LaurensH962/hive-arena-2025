#!/bin/bash

# Configuration
SERVER_URL="http://localhost:8000"
SERVER_HOST="localhost:8000"
MAP_NAME="inverted" # Change this to a map name from the maps/ folder (balanced, inverted, scarce, tiny)
PLAYERS=2

# Bot configurations - you can specify different bots for each player
# Bot 1 configuration
BOT1_SOURCE="./strategrify-agent"
BOT1_BINARY="./strategrify-agent/agent_bin"
BOT1_NAME="BeeBee"

# Bot 2 configuration (change these to use a different bot)
BOT2_SOURCE="./strategrify-agent"  # Change to "./example-agent-go" or another agent folder
# Use a different binary filename for bot2 so building bot2 doesn't overwrite bot1's binary
BOT2_BINARY="./strategrify-agent/agent_bin2"
BOT2_NAME="Laila"

# 1. Check for dependencies
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is not installed. Please install it to parse API responses."
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "Error: 'curl' is not installed."
    exit 1
fi

# 2. Compile the Bots
echo "🔨 Building Bot 1..."
if ! go build -o "$BOT1_BINARY" "$BOT1_SOURCE"; then
    echo "❌ Bot 1 compilation failed."
    exit 1
fi
echo "✅ Bot 1 build successful: $BOT1_BINARY"

echo "🔨 Building Bot 2..."
if ! go build -o "$BOT2_BINARY" "$BOT2_SOURCE"; then
    echo "❌ Bot 2 compilation failed."
    exit 1
fi
echo "✅ Bot 2 build successful: $BOT2_BINARY"

# 3. Create the Game
echo "🌐 Contacting server at $SERVER_URL..."
RESPONSE=$(curl -s "$SERVER_URL/newgame?map=$MAP_NAME&players=$PLAYERS")

# Check if curl failed
if [ -z "$RESPONSE" ]; then
    echo "❌ Failed to connect to server. Is it running?"
    exit 1
fi

# Parse the Game ID using jq
GAME_ID=$(echo $RESPONSE | jq -r '.id')
ADMIN_TOKEN=$(echo $RESPONSE | jq -r '.adminToken')

if [ "$GAME_ID" == "null" ]; then
    echo "❌ Failed to create game. Server response:"
    echo $RESPONSE
    exit 1
fi

echo "==================================================="
echo "🎮 Game Created!"
echo "🆔 ID: $GAME_ID"
echo "🔗 ID for Clipboard: $GAME_ID"
echo "==================================================="

# 4. Cleanup Trap
# This ensures that if you press Ctrl+C, all background bots are killed
trap "kill 0" SIGINT

# 5. Launch Bots
echo "🚀 Launching $PLAYERS bots..."

# Launch Bot 1
$BOT1_BINARY "$SERVER_HOST" "$GAME_ID" "$BOT1_NAME" &
PID1=$!
echo "   Spawned $BOT1_NAME (PID: $PID1)"
sleep 0.2

# Launch Bot 2
$BOT2_BINARY "$SERVER_HOST" "$GAME_ID" "$BOT2_NAME" &
PID2=$!
echo "   Spawned $BOT2_NAME (PID: $PID2)"
sleep 0.2

# If more players are needed, launch additional bots
for (( i=3; i<=PLAYERS; i++ ))
do
    NAME="Bot-$i"
    # Default to using Bot 1 for additional players
    $BOT1_BINARY "$SERVER_HOST" "$GAME_ID" "$NAME" &
    PID=$!
    echo "   Spawned $NAME (PID: $PID)"
    sleep 0.2
done
echo "==================================================="
echo "⚔️  Match in progress. Press Ctrl+C to stop."
echo "==================================================="

# 6. Keep script running to maintain the trap
wait

# 7. After match ends, find the history file and open the viewer
echo ""
echo "==================================================="
echo "🎬 Opening viewer for completed game..."
echo "==================================================="

# Wait a moment for the history file to be written
sleep 1

# Find the most recent history file matching our game ID in the local history folder
HISTORY_FILE=$(ls -t history/*${GAME_ID}*.json 2>/dev/null | head -n 1)

if [ -n "$HISTORY_FILE" ]; then
    echo "📂 History file: $HISTORY_FILE"
    echo "🔗 Opening viewer..."
    # Use the file path directly with autoplay enabled
    go run ./viewer --file "$HISTORY_FILE"
else
    echo "⚠️  Could not find history file for game $GAME_ID"
    echo "   Trying to open viewer with server URL..."
    HISTORY_URL=$(ls -t history/*.json 2>/dev/null | head -n 1)
    if [ -n "$HISTORY_URL" ]; then
        echo "📂 Opening most recent game: $HISTORY_URL"
        go run ./viewer --file "$HISTORY_URL" 
    else
        echo "   No history files found. The game may not have completed properly."
    fi
fi