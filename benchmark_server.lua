luarpc = require("rpc")

myobj1 = { foo =
            function (a, b, c)
              return a + b, a + b + c
            end,
           foo2 =
            function ()
              return
            end,
           boo =
            function (s)
              return #s
            end
}

arq_interface = "benchmark_interface.lua"

serv1 = luarpc.createServant(myobj1, arq_interface, 10000, false)
serv2 = luarpc.createServant(myobj1, arq_interface, 10001, true)

print("Server without keepalive listening on: ", serv1.ip, serv1.port)
print("Server with keepalive listening on: ", serv2.ip, serv2.port)

luarpc.waitIncoming()
