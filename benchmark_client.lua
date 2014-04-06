luarpc = require("rpc")

arq_interface = "benchmark_interface.lua"

local client_factories = {
  dont = function() return luarpc.createProxy("localhost", 10000, arq_interface) end,
  keep = function() return luarpc.createProxy("localhost", 10001, arq_interface) end,
}

local tests = {}
tests.correction = function(client)
  assert(client.foo(1, 2, 3) == 3)
  assert(client.foo2() == nil)
  assert(client.boo("test") == 4)
end

tests.boo_long = function(client)
  local s = string.rep("test", 10000)
  assert(client.boo(s), 40000)
end

tests.boo_short = function(client)
  local s = string.rep("test", 1)
  assert(client.boo(s), 4)
end

tests.table_ser = function(client)
  local tbl = {}
  for i = 1, 100 do
    tbl[i] = i
  end
  assert(client.boo(serialize(tbl)) > 100)
end

tests.table_deser = function(client)
  local tbl = {}
  for i = 1, 100 do
    tbl[i] = i
  end
  assert(client.boo_deser(serialize(tbl)) == 100)
end

local format_n = function(time, unit)
  return string.format("%.5f", time)  .. unit
end

function serialize (o)
  if type(o) == "number" then
    return tostring(o)
  elseif type(o) == "string" then
    return string.format("%q", o)
  elseif type(o) == "table" then
    tokens = {}
    tokens[#tokens + 1] = "{\n"
    for k,v in pairs(o) do
      tokens[#tokens + 1] = "  [\"" .. serialize(k) .. "\"] = "
      tokens[#tokens + 1] = serialize(v)
      tokens[#tokens + 1] = ",\n"
    end
    tokens[#tokens + 1] = "}\n"
    return table.concat(tokens, "")
  else
    error("cannot serialize a " .. type(o))
  end
end

print("name", "", "client", "pool", "#", "elapsed time", "time/test", "tests/s")
for test_name, test in pairs(tests) do
  for client_name, client_factory in pairs(client_factories) do
    for _, pool_size in ipairs({1, 3, 10}) do
      local clients = {}
      for i = 1, pool_size do
        clients[i] = client_factory()
      end
      times = 0
      start_time = os.clock()
      while os.clock() < start_time + 1 do
        test(clients[(times % pool_size) + 1])
        times = times + 1
      end
      end_time = os.clock()
      for i = 1, pool_size do
        clients[i].client:close()
      end

      elapsed_time = end_time - start_time
      print(
        test_name,
        client_name,
        pool_size,
        times,
        format_n(elapsed_time, " s"),
        format_n(elapsed_time / times, " s"),
        format_n(times / elapsed_time, "/s")
      )
    end
  end
end
