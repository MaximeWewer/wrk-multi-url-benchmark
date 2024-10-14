# HTTP Benchmarking with `wrk` and Lua Script

This document explains how to use `wrk` with a Lua script to perform HTTP performance tests on multiple URLs.

## Overview of `wrk`

[wrk](https://github.com/wg/wrk) is a high-performance HTTP benchmarking tool that can generate a large number of concurrent requests. It allows you to test server load capacity and obtain detailed performance statistics.

## Prerequisites

Ensure you have the following tools installed on your machine:

- Docker
- Jq

The script will automatically check for the installation of Docker and Jq before executing the benchmark.

## Build WRK docker image

Use the Dockerfile to build your `wrk` Docker image: `docker build -t wrk:latest .`

## Script Usage

```bash
./run_wrk.sh [options]
```

### Example

```bash
./run_wrk.sh --connections 100 --threads 4 --duration 30s --url https://example.com
```

### Options

```text
--connections    Total number of connections (default: 100)"
--threads        Number of threads (default: 2)"
--duration       Test duration (default: 10s)"
--script         Lua script to use (default: multi_http.lua)"
--timeout        Request timeout (default: 2s)"
--min-delay      Minimum delay in ms (default: 10)"
--max-delay      Maximum delay in ms (default: 100)"
--range-latency  Latency range (default: 50,75,95,99.99)"
--filename       Output file name (default: wrk_results)"
--show-stdout    Do not display stdout results (default: false)"
--url            Target URL (default: https://about.google/). 
                 To test multiple URLs, you need to edit this bash."
```

### Impact of `--connections` and `--threads` Parameters

- **`--connections`** : Sets the total number of HTTP connections to keep open. Each thread manages a certain number of connections, determined by `N = connections / threads`, so if you have `-c 100 -t 4`, each thread manages 25 connections. A higher number of connections test how the server handles a high simultaneous load, but it can also overload the client or server if set too high.

- **`--threads`** : Sets the total number of threads used. Each thread executes HTTP requests in parallel. More threads maximize the generation of simultaneous requests, but this also depends on the CPU capabilities and system limits.

### Lua Script for wrk

`multi_http.lua` script allows you to :

- Send requests to multiple URLs simultaneously and give them weight
- Track the number of requests per URL
- Simulate random delays between requests for more realistic connections
- Export the statistics to a JSON file

The script creates a configuration file `wrk_config.txt` in the `./scripts` directory, which is used by the Lua script. This file contains the following settings:

```text
urls = {
    { path = "/", method = "GET", headers = nil, body = nil, weight = 100 }
}
min_delay_ms = [min_delay_value]
max_delay_ms = [max_delay_value]
stdout_result = [true|false]
connections = [number_of_connections]
threads = [number_of_threads]
range_latency = [latency_percentiles]
filename = [output_filename]
```

### Limitations

- The response tracking in the Lua script is done globally, meaning per-path statistics may not be available
- Connections and threads should be set according to the machine's capabilities
- Testing local URLs might yield different results compared to internet URLs
- The quality of the internet connection impacts the results
- The network card might not be able to handle many simultaneous connections in high-load tests

## JSON output

The results of the benchmark are saved as a JSON file, which contains detailed statistics about the test. An example output might look like this:

```json
{
  "data_received_MB": 66.49,
  "data_received_MB_per_second": 6.65,
  "errors": {
    "non_2xx_or_3xx_responses": 1024,
    "timeouts": 139
  },
  "latency_percentiles_in_ms": {
    "50th": 119.78,
    "75th": 289.26,
    "95th": 474.54,
    "99.99th": 879.1
  },
  "nb_connections": 100,
  "nb_threads": 2,
  "requests_per_second": 408.06,
  "response_success_percentage": 97.86,
  "total_requests": 4168,
  "total_responses": 4079,
  "url_requests": {
    "/": 1113,
    "/products": 994,
    "/stories": 1025,
    "https://www.google.com": 1036
  }
}
```
