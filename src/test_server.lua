luarpc = require("rpc")

myobj1 = { foo =
             function (a, b, s)
               return a+b, "alo alo"
             end,
          boo =
             function (n)
               return n
             end
        }

myobj2 = { foo =
             function (a, b, s)
               return a-b, "tchau"
             end,
          boo =
             function (n)
               return 1
             end
        }

arq_interface = "test_interface.lua"

serv1 = luarpc.createServant(myobj1, arq_interface)
print("Server 1 listening on: ", serv1.ip, serv1.port)

serv2 = luarpc.createServant(myobj2, arq_interface)
print("Server 2 listening on: ", serv2.ip, serv2.port)

luarpc.waitIncoming()