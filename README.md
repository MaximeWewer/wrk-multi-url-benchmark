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

The Lua script `multi_http.lua` allows testing multiple URLs with random requests, tracking the number of requests per URL, and collecting statistics on responses and latency. It also simulates random delays between requests to reflect more realistic connections.

There are values (**urls**, **delay_ms**, **range_latency**) that can be adjusted in the script according to your needs.

Example: `docker run -v ./scripts:/data wrk -c 5 -t 2 -d 5 -s multi_http.lua --timeout 2s https://about.google/`

Results:

```text
Running 5s test @ https://about.google/
  2 threads and 5 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    63.13ms   27.56ms 164.19ms   74.03%
    Req/Sec    15.52      6.86    30.00     86.67%
  158 requests in 4.59s, 2.70MB read
  Socket errors: connect 0, read 0, write 0, timeout 4
  Non-2xx or 3xx responses: 40
Requests/sec:     34.40
Transfer/sec:    601.36KB
--------------------------------------------------------
URL '/' was requested 22 times
URL '/stories' was requested 17 times
URL '/products' was requested 15 times
URL 'https://www.google.com' was requested 29 times
Thread 1 made 83 requests and handled 80 responses (96.39%)

URL '/' was requested 22 times
URL '/stories' was requested 20 times
URL '/products' was requested 22 times
URL 'https://www.google.com' was requested 15 times
Thread 2 made 79 requests and handled 78 responses (98.73%)

Total made 162 requests and handled 158 responses (97.53%)

Latency Percentiles (in ms):
  50th percentile: 52 ms
  75th percentile: 82 ms
  95th percentile: 116 ms
  99.99th percentile: 164 ms
```
