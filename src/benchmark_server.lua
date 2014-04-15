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
            end,
          boo_deser =
            function (s)
              tbl = {}
              cmd = "tbl = " .. s
              loadstring(cmd)()
              local size = 0
              for k, v in pairs(tbl) do
                size = size + 1
              end
              return size
            end
}

arq_interface = "benchmark_interface.lua"

serv1 = luarpc.createServant(myobj1, arq_interface, 10000, false)
serv2 = luarpc.createServant(myobj1, arq_interface, 10001, true)

print("Server without keepalive listening on: ", serv1.ip, serv1.port)
print("Server with keepalive listening on: ", serv2.ip, serv2.port)

luarpc.waitIncoming()
