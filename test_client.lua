luarpc = require("rpc")

if #arg ~= 3 then
    print("Uso: " .. arg[0] .. " IP porta1 porta2")
    return
end

IP = arg[1]
porta1 = arg[2]
porta2 = arg[3]
arq_interface = "test_interface.lua"

print("Clients are going to connect to IP " .. IP .. " and ports", porta1, porta2)

local p1 = luarpc.createproxy(IP, porta1, arq_interface)
local p2 = luarpc.createproxy(IP, porta2, arq_interface)

print("Clients connected")

local r, s = p1.foo(3, 5)

print("p1.foo(3, 5) = (" .. r .. ", '" .. s .."')")

local t = p2.boo(10)
print("p2.boo(10) = '" ..  t .. "'")