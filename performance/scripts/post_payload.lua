local payload_file = os.getenv("PAYLOAD_FILE")
if not payload_file then
    error("PAYLOAD_FILE environment variable not set")
end

local f = assert(io.open(payload_file, "rb"))
local body = f:read("*all")
f:close()

wrk.method  = "POST"
wrk.body    = body
wrk.headers["Content-Type"] = "text/plain"
