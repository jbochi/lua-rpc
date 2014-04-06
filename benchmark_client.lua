luarpc = require("rpc")

arq_interface = "benchmark_interface.lua"

local clients = {
  dontkeepalive = luarpc.createProxy("localhost", 10000, arq_interface),
  keepalive = luarpc.createProxy("localhost", 10001, arq_interface),
}

local tests = {}
tests.correction = function(client)
  assert(client.foo(1, 2, 3) == 3)
  assert(client.foo2() == nil)
  assert(client.boo("teste") == 5)
end
tests.correction.times = 100

for test_name, test in pairs(tests) do
  for client_name, client in pairs(clients) do
    times = test.times
    start_time = os.clock()
    test(client)
    end_time = os.clock()

    elapsed_time = end_time - start_time
    print(test_name, client_name, times, string.format("%.5fs", elapsed_time))
  end
end
