local util = require 'util'

local f = function()
	return 314
end

local socket = require("socket")

local client = assert(socket.connect("127.0.0.1", 1234))
local data = string.dump(f)
assert(client:send(#data .. "\n" .. data))

local response = assert(client:receive())
print(response)

