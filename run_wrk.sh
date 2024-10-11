#!/bin/bash

# Default values
WRK_CONNECTIONS=100
WRK_THREADS=2
WRK_DURATION=10s
WRK_SCRIPT=multi_http.lua
WRK_TIMEOUT=2s
WRK_URL=https://about.google/
MIN_DELAY_MS=10
MAX_DELAY_MS=100
RANGE_LATENCY=50,75,95,99.99
FILENAME=wrk_results
STDOUT_RESULT=false

# Function to display usage
usage() {
  echo "Usage: $0 [--connections connections] [--threads threads] [--duration duration] [--script script] [--timeout timeout] [--url url] [--min-delay min_delay] [--max-delay max_delay] [--range-latency range_latency] [--filename filename] [--show-stdout show_stdout]"
  echo "  --connections    Total number of connections (default: 100)"
  echo "  --threads        Number of threads (default: 2)"
  echo "  --duration       Test duration (default: 10s)"
  echo "  --script         Lua script to use (default: multi_http.lua)"
  echo "  --timeout        Request timeout (default: 2s)"
  echo "  --url            Target URL (default: https://about.google/). To test multiple URLs, you need to edit this bash."
  echo "  --min-delay      Minimum delay in ms (default: 10)"
  echo "  --max-delay      Maximum delay in ms (default: 100)"
  echo "  --range-latency  Latency range (default: 50,75,95,99.99)"
  echo "  --filename       Output file name (default: wrk_results)"
  echo "  --show-stdout    Do not display stdout results (default: false)"
  exit 1
}

# Read past options
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --connections) WRK_CONNECTIONS="$2"; shift ;;
    --threads) WRK_THREADS="$2"; shift ;;
    --duration) WRK_DURATION="$2"; shift ;;
    --script) WRK_SCRIPT="$2"; shift ;;
    --timeout) WRK_TIMEOUT="$2"; shift ;;
    --url) WRK_URL="$2"; shift ;;
    --min-delay) MIN_DELAY_MS="$2"; shift ;;
    --max-delay) MAX_DELAY_MS="$2"; shift ;;
    --range-latency) RANGE_LATENCY="$2"; shift ;;
    --filename1) FILENAME="$2"; shift ;;
    --show-stdout) STDOUT_RESULT="$2"; shift ;;
    *) usage ;;
  esac
  shift
done

# Create the configuration file for the Lua script
## Example config for URLs
    # path: "/" or "https://www.google.com"
    # header: { ["Content-Type"] = "application/json" }
    # body: '{"key": "value"}'

## Minimal URL config
    # urls = {
    #     { path = "/", method = "GET", headers = nil, body = nil }
    # }

## Multi URLs example :
    # urls = {
    #    { path = "/", method = "GET", headers = nil, body = nil },
    #    { path = "/stories", method = "GET", headers = nil, body = nil },
    #    { path = "/products", method = "GET", headers = nil, body = nil },
    #    { path = "https://www.google.com", method = "GET", headers = nil, body = nil }
    # }

cat <<EOL > ./scripts/wrk_config.txt

urls = {
    { path = "/", method = "GET", headers = nil, body = nil },
    { path = "/stories", method = "GET", headers = nil, body = nil },
    { path = "/products", method = "GET", headers = nil, body = nil },
    { path = "https://www.google.com", method = "GET", headers = nil, body = nil }
}
min_delay_ms = $MIN_DELAY_MS
max_delay_ms = $MAX_DELAY_MS
stdout_result = $STDOUT_RESULT
connections = $WRK_CONNECTIONS
threads = $WRK_THREADS
range_latency = {$RANGE_LATENCY}
filename = "$FILENAME"

EOL

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if Docker is installed
if ! command_exists docker; then
    echo "Error: Docker is not installed on this machine."
    exit 1
fi

# Check if jq is installed
if ! command_exists jq; then
    echo "Error: jq is not installed on this machine."
    exit 1
fi

# Build the wrk command
WRK_CMD="docker run --rm -v ./scripts:/data wrk -t $WRK_THREADS -c $WRK_CONNECTIONS -d $WRK_DURATION -s $WRK_SCRIPT --timeout $WRK_TIMEOUT $WRK_URL"

# Run the WRK command with all parameters
eval $WRK_CMD

# Remove config file
rm ./scripts/wrk_config.txt

# Get lastest result file
latest_file=$(ls -t "./scripts/$FILENAME"_*.json | head -n 1)

# Check if file is found
if [ -z "$latest_file" ]; then
  echo "No result files found."
  exit 1
fi

# Sort JSON
jq -S '.' "$latest_file" > temp.json && mv temp.json "$latest_file"