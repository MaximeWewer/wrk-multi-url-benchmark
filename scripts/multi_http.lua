-- Scripting doc : https://github.com/wg/wrk/blob/master/SCRIPTING

function load_config(file)
    local config = {}
    local f, err = loadfile(file)

    if f then
        setfenv(f, config) -- Run config file as a local 'config' table
        f()
    else
        error("Error reading configuration file: " .. err)
    end

    return config
end

-- Load configuration
local config = load_config("/data/wrk_config.txt")

-- Extract variables from config file
local urls = config.urls
local filename = config.filename
local nb_threads = config.threads
local min_delay_ms = config.min_delay_ms
local max_delay_ms = config.max_delay_ms
local nb_connections = config.connections
local range_latency = config.range_latency
local stdout_result = config.stdout_result

local counter = 1
local threads = {}

function setup(thread)
    local data_str = ""

    -- Loop through each URL to prepare the path and add a request counter
    for i, data in ipairs(urls) do
        local path = data.path
        data_str = data_str .. string.format("%s;0|", path) -- Format: "path;nb_requests"
    end

    -- Store the string and counters in the thread
    thread:set("id", counter)
    thread:set("response_count", 0)
    thread:set("url_request_count", data_str)

    table.insert(threads, thread)
    counter = counter + 1
end

function generate_weighted_requests(urls)
    local weighted_requests = {}
    for i, url in ipairs(urls) do
        -- Add the URL as many times as its weight indicates
        for j = 1, url.weight do
            table.insert(weighted_requests, url)
        end
    end
    return weighted_requests
end

function init(args)
    weighted_requests = {}
    pre_generated_requests = {}

    -- Generate weighted requests urls list
    weighted_requests = generate_weighted_requests(urls)

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
    local index
    local url_weighted = weighted_requests[math.random(1, #weighted_requests)]
    -- Select a random URL ID
    for i, u in ipairs(urls) do
        if u == url_weighted then
            index = i
            break
        end
    end
    req = pre_generated_requests[index]

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

function stdout_message(message)
    if stdout_result then
        print(message) -- Show only if stdout_result is true
    end
end

function done(summary, latency, requests)
    local total_requests = 0
    local total_responses = 0
    local global_url_requests = {} -- Table to store global request counts for each URL

    stdout_message("--------------------------------------------------------")
    for index, thread in ipairs(threads) do
        local id = thread:get("id")
        local response_count = thread:get("response_count")
        local request_count = thread:get("url_request_count")
        local thread_requests = 0

        for entry in request_count:gmatch("[^|]+") do
            local url, count = entry:match("([^;]+);(%d+)")
            thread_requests = thread_requests + tonumber(count)

            -- Update the global counter for each URL
            if global_url_requests[url] then
                global_url_requests[url] = global_url_requests[url] + tonumber(count)
            else
                global_url_requests[url] = tonumber(count)
            end

            local request_msg = "URL '%s' was requested %d times"
            stdout_message(request_msg:format(url, count))
        end

        total_requests = total_requests + thread_requests
        total_responses = total_responses + response_count

        local percentage = (response_count / thread_requests) * 100
        local percentage_msg = "Thread %d made %d requests and handled %d responses (%.2f%%)\n"
        stdout_message(percentage_msg:format(id, thread_requests, response_count, percentage))
    end

    -- Display global statistics per URL
    stdout_message("Global requests per URL:")
    for url, count in pairs(global_url_requests) do
        stdout_message(string.format("  URL '%s' was requested %d times", url, count))
    end

    -- Global statistics
    local global_percentage = (total_responses / total_requests) * 100
    local global_msg = "Total made %d requests and handled %d responses (%.2f%%)"
    stdout_message(global_msg:format(total_requests, total_responses, global_percentage))

    -- Display latency percentiles
    stdout_message("\nLatency Percentiles (in ms):")
    for index, p in pairs(range_latency) do
        local n = latency:percentile(p) / 1000
        stdout_message(string.format("  %gth percentile: %d ms", p, n))
    end

    -- Additional info
    local duration_in_seconds = summary.duration / 1000000 -- Conversion from microseconds to seconds
    local requests_per_second = summary.requests / duration_in_seconds

    local megabytes_received = summary.bytes / 1048576 -- Convert to megabytes
    local mb_per_second = megabytes_received / duration_in_seconds

    stdout_message(string.format("\nDuration in seconds: %.2f", duration_in_seconds))
    stdout_message(string.format("MB received: %.2f", megabytes_received))
    stdout_message(string.format("Requests per second: %.2f", requests_per_second))
    stdout_message(string.format("Data received per second: %.2f MB/s", mb_per_second))
    stdout_message(string.format("Number of timeouts: %d", summary.errors.timeout))
    stdout_message(string.format("Number of Non-2xx or 3xx HTTP status codes: %d", summary.errors.status))

    -- Create a global summary
    write_summary_to_json(filename,
                            total_requests,
                            total_responses,
                            global_percentage,
                            requests_per_second,
                            megabytes_received,
                            mb_per_second,
                            summary.errors.timeout,
                            summary.errors.status,
                            global_url_requests,
                            latency,
                            nb_connections,
                            nb_threads)
end

-- Function to escape quotes in strings
local function escape_string(str)
    return str:gsub('"', '\\"')
end

-- Function to manually convert a Lua table to JSON
function to_json(value)
    local value_type = type(value)

    if value_type == "table" then
        local is_array = #value > 0
        local result = {}

        if is_array then
            -- Convert a list (table with numeric indexes)
            for i = 1, #value do
                table.insert(result, to_json(value[i]))
            end
            return "[" .. table.concat(result, ",") .. "]"
        else
            -- Convert a dictionary (table with non-numeric keys)
            for k, v in pairs(value) do
                table.insert(result, '"' .. escape_string(tostring(k)) .. '":' .. to_json(v))
            end
            return "{" .. table.concat(result, ",") .. "}"
        end
    elseif value_type == "string" then
        return '"' .. escape_string(value) .. '"'
    elseif value_type == "number" or value_type == "boolean" then
        return tostring(value)
    else
        return "null"
    end
end

-- Function to round a number to a specified number of decimal places
function round(value, decimal_places)
    local multiplier = 10 ^ (decimal_places or 0)
    return math.floor(value * multiplier + 0.5) / multiplier
end

-- Function to get the current timestamp in a readable format
function get_timestamp()
    return os.date("%Y%m%d_%H%M%S") -- Format: YYYYMMDD_HHMMSS
end

-- Function to write statistics in JSON format to a file
function write_summary_to_json(filename,
                               total_requests, 
                               total_responses, 
                               global_percentage, 
                               requests_per_second, 
                               megabytes_received, 
                               mb_per_second, 
                               timeouts, 
                               non_2xx_responses, 
                               global_url_requests, 
                               latency, 
                               nb_connections, 
                               nb_threads)
   
    -- Prepare global data as a Lua table
    local data = {
        nb_connections = nb_connections,
        nb_threads = nb_threads,
        total_requests = total_requests,
        total_responses = total_responses,
        response_success_percentage = round(global_percentage, 2),
        requests_per_second = round(requests_per_second, 2),
        data_received_MB = round(megabytes_received, 2),
        data_received_MB_per_second = round(mb_per_second, 2),
        latency_percentiles_in_ms = {},
        url_requests = global_url_requests,
        errors = {
            timeouts = timeouts,
            non_2xx_or_3xx_responses = non_2xx_responses
        }
    }

    -- Populate latency percentiles dynamically from range_latency
    for i, p in pairs(range_latency) do
        local n = latency:percentile(p) / 1000 -- Convert to milliseconds
        data.latency_percentiles_in_ms[string.format("%gth", p)] = round(n, 2) -- Add to table and round
    end

    -- Convert the Lua table into JSON format manually
    local json_data = to_json(data)

    -- Add the timestamp to the filename
    local timestamp = get_timestamp()
    local filename_date = filename .. "_" .. timestamp .. ".json"

    -- Write the JSON data to the specified file
    local file = io.open(filename_date, "w")
    if file then
        file:write(json_data)
        file:close()
    else
        print("Error: Unable to open file " .. filename)
    end
end
