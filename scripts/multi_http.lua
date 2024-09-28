-- Example path: "/" or "https://www.google.com"
-- Example header: { ["Content-Type"] = "application/json" }
-- Example body: '{"key": "value"}'

local urls = {
   { path = "/", method = "GET", headers = nil, body = nil },
   { path = "/stories", method = "GET", headers = nil, body = nil },
   { path = "/products", method = "GET", headers = nil, body = nil },
   { path = "https://www.google.com", method = "GET", headers = nil, body = nil }
}

local counter = 1
local threads = {}
local min_delay_ms = 10
local max_delay_ms = 100
local range_latency = { 50, 75, 95, 99.99 }

function setup(thread)
   local data_str = ""

   -- Loop through each URL to prepare the path and add a request counter
   for i, data in ipairs(urls) do
      local path = data.path
      data_str = data_str .. string.format("%s;0|", path)  -- Format: path;number of requests
   end

   -- Store the string and counters in the thread
   thread:set("id", counter)
   thread:set("response_count", 0)
   thread:set("url_request_count", data_str)

   table.insert(threads, thread)
   counter = counter + 1
end

function init(args)
   pre_generated_requests = {}

   -- Generate requests for each path in urls
   for i, data in ipairs(urls) do
      local req = wrk.format(data.method, data.path, data.headers, data.body)
      table.insert(pre_generated_requests, req)
   end

   -- Load the thread's request counters
   url_request_count = wrk.thread:get("url_request_count")
end

function update_request_count(path)
   -- Update the request counter for the given URL in the url_request_count string
   local updated_str = ""
   
   -- Iterate over the URLs and their counters
   for entry in string.gmatch(url_request_count, "([^|]+)") do
      local url, count = string.match(entry, "([^;]+);(%d+)")
      if url == path then
         count = tonumber(count) + 1
      end
      updated_str = updated_str .. string.format("%s;%d|", url, count)
   end

   -- Save the updated string
   wrk.thread:set("url_request_count", updated_str)
end

function request()
   -- Select a random request and get its URL
   local index = math.random(1, #pre_generated_requests)
   local req = pre_generated_requests[index]

   -- Update the request counter for the corresponding URL
   local path = urls[index].path
   update_request_count(path)
   return req
end

function delay()
   -- Return a random delay between X and Y milliseconds
   return math.random(min_delay_ms, max_delay_ms)
end

function response(status, headers, body)
   -- Increment the response counter for the thread
   local response_count = wrk.thread:get("response_count")
   wrk.thread:set("response_count", response_count + 1)
end

function done(summary, latency, requests)
   local total_requests = 0
   local total_responses = 0

   print("--------------------------------------------------------")
   for index, thread in ipairs(threads) do
      local id = thread:get("id")
      local response_count = thread:get("response_count")
      local request_count = thread:get("url_request_count")
      local thread_requests = 0

      for entry in request_count:gmatch("[^|]+") do
         local url, count = entry:match("([^;]+);(%d+)")
         thread_requests = thread_requests + tonumber(count)
         local request_msg = "URL '%s' was requested %d times"
         print(request_msg:format(url, count))
      end

      total_requests = total_requests + thread_requests
      total_responses = total_responses + response_count

      local percentage = (response_count / thread_requests) * 100
      local percentage_msg = "Thread %d made %d requests and handled %d responses (%.2f%%)\n"
      print(percentage_msg:format(id, thread_requests, response_count, percentage))
   end

   -- Display global statistics
   local global_percentage = (total_responses / total_requests) * 100
   local global_msg = "Total made %d requests and handled %d responses (%.2f%%)\n"
   print(global_msg:format(total_requests, total_responses, global_percentage))

   -- Display latency percentiles
   print("Latency Percentiles (in ms):")
   for index, p in pairs(range_latency) do
      local n = latency:percentile(p) / 1000
      print(string.format("  %gth percentile: %d ms", p, n))
   end
end
