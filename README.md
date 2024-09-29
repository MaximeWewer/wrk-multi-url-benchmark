# HTTP Benchmarking with `wrk` and Lua Script

This document explains how to use `wrk` with a Lua script to perform HTTP performance tests on multiple URLs.

## Overview of `wrk`

[wrk](https://github.com/wg/wrk) is a high-performance HTTP benchmarking tool that can generate a large number of concurrent requests. It allows you to test server load capacity and obtain detailed performance statistics.

### Command

Use the Dockerfile to build your `wrk` Docker image: `docker build -t wrk:latest .`

```bash
docker run -v ./scripts:/data wrk -t <threads> -c <connections> -d <duration> -s <script.lua> <url>
```

```text
-c, --connections: Total number of HTTP connections to keep open.
                   Each thread handles N = connections/threads.

-d, --duration:    Duration of the test, e.g. 2s, 2m, 2h

-t, --threads:     Number of threads to use. Each thread is responsible 
                   for managing connections.

-s, --script:      Lua script used to customize the requests, 
                   like the one detailed below.

-H, --header:      Add an HTTP header to requests. With our script, 
                   this is not necessary as headers can be 
                   managed directly in the script.

    --latency:     Prints detailed latency statistics.
                   This option is already handled in the script,
                   so it's unnecessary here.

    --timeout:     Timeout after which a request fails if no
                   response is received.
                   The default value is 2 seconds.
```

### Impact of `-c` and `-t` Parameters

- **`-c, --connections`** : Sets the total number of HTTP connections to keep open. Each thread manages a certain number of connections, determined by `N = connections / threads`, so if you have `-c 100 -t 4`, each thread manages 25 connections . A higher number of connections tests how the server handles a high simultaneous load, but it can also overload the client or server if set too high.

- **`-t, --threads`** : Sets the total number of threads used. Each thread executes HTTP requests in parallel. More threads maximize the generation of simultaneous requests, but this also depends on the CPU capabilities and system limits.

### Limitations

- In the Lua script, the response() function does not provide the tested path, so responses can only be tracked globally, not per path.
- The number of connections and threads should be adjusted according to the machine's CPU capabilities.
- Testing a local URL will not yield the same results as testing over the internet.
- The quality of the internet connection impacts the results.
- The network card might not be able to handle many simultaneous connections in high-load tests.

### Lua Script for wrk

This script allows you to :

- Send requests to multiple URLs simultaneously
- Track the number of requests per URL
- Simulate random delays between requests for more realistic connections
- Export the statistics to a JSON file

The values you can modify are at the beginning of the script:

```text
local urls = {
   { path = "/", method = "GET", headers = nil, body = nil },
   { path = "/stories", method = "GET", headers = nil, body = nil },
   { path = "/products", method = "GET", headers = nil, body = nil },
   { path = "https://www.google.com", method = "GET", headers = nil, body = nil }
}
local min_delay_ms = 10
local max_delay_ms = 100
local range_latency = { 50, 75, 95, 99.99 }
local filename = "wrk_summary"
```

Example : `docker run -v ./scripts:/data wrk -c 5 -t 2 -d 5 -s multi_http.lua --timeout 2s https://about.google/`

JSON results :

```json
{
    "data_received_MB": 41.15,
    "data_received_MB_per_second": 8.05,
    "errors": {
        "non_2xx_or_3xx_responses": 648,
        "timeouts": 134
    },
    "latency_percentiles_in_ms": {
        "50th": 116.61,
        "75th": 186.09,
        "95th": 355.12,
        "99.99th": 764.28
    },
    "requests_per_second": 477.52,
    "response_success_percentage": 97.87,
    "total_requests": 2494,
    "total_responses": 2441,
    "url_requests": {
        "/": 681,
        "/products": 610,
        "/stories": 546,
        "https://www.google.com": 657
    }
}
```
