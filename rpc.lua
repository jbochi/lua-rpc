local socket = require("socket")

local SERVER_ACCEPT_TIMEOUT = 1
local SERVER_READ_TIMEOUT = 1
local CLIENT_TIMEOUT = 5
local MAX_SERVER_CONNECTIONS = 3

local rpc = {}

-- create a method based on its interface definition
local method = function(name, method_interface)
  local m = {}
  local list_types = function(direction)
    local results = {}
    for _, arg in ipairs(method_interface.args or {}) do
      if string.match(arg.direction, direction) then
        results[#results + 1] = arg.type
      end
    end
    return results
  end
  m.result_types = function()
    local types = list_types("out")
    if method_interface.resulttype and method_interface.resulttype ~= "void" then
      table.insert(types, 1, method_interface.resulttype)
    end
    return types
  end
  m.arg_types = function()
    return list_types("in")
  end
  m.serialize_call = function(...)
    local args = {...}
    local arg_types = m.arg_types()
    table.insert(args, 1, name)
    table.insert(arg_types, 1, string)
    return rpc.serialize_list(arg_types, args)
  end
  m.serialize_result = function(...)
    local results = {...}
    local result_types = m.result_types()
    return rpc.serialize_list(result_types, results)
  end
  return m
end

-- the interface metatable defines the metamethods for a interface
local interface_mt = {
  __index = function(o, method_name)
    local m = o.__methods[method_name]
    if m then return method(method_name, m) end
  end
}

-- function to load new interfaces
rpc.interface = function(args)
  local interface = {__name=args.name, __methods=args.methods}
  setmetatable(interface, interface_mt)
  return interface
end

-- serialization functions
rpc.serialize = function(arg_type, arg)
  if arg_type == "string" and type(arg) ~= "string" then
    error("String expected")
  elseif arg_type == "char" and (type(arg) ~= "string" or #arg ~= 1) then
    error("Char expected")
  elseif arg_type == "double" and (type(arg) ~= "number") then
    error("Double expected")
  end
  return (string.gsub((string.gsub(arg, "\\", "\\\\")), "\n", "\\n"))
end

rpc.deserialize = function(arg_type, arg)
  if arg_type == "double" then
    local n = tonumber(arg)
    if n == nil then
      error("Double expected")
    end
    return n
  else
    local s = (string.gsub(
              string.gsub(
                string.gsub(arg, "^\\n", "\n"),
              "([^\\])\\n", "%1\n"),
            "\\\\", "\\"))
    if arg_type == "char" and #s > 1 then
      error("Char expected")
    end
    return s
  end
end

rpc.serialize_list = function(arg_types, args)
  if #args > #arg_types then
    error("Wrong number of arguments (" .. #args .. " instead of " .. #arg_types .. ")")
  end
  local lines = {}
  for i, t in ipairs(arg_types) do
    local arg = args[i]
    -- add missing arguments
    if arg == nil then
      if t == "double" then
        arg = 0
      else
        arg = ""
      end
    end
    lines[#lines + 1] = rpc.serialize(t, arg)
  end
  lines[#lines + 1] = ""
  return table.concat(lines, "\n")
end


--- proxy functions
local proxy_call = function(proxy, method_name)
  return function(...)
    local method = proxy.interface[method_name]
    if method == nil then
      error("Invalid method")
    end
    local sent = false
    local client = proxy.client
    local connected = proxy.client:getpeername()
    while not sent do
      if not connected then
        client:connect(proxy.ip, proxy.port)
        client:settimeout(CLIENT_TIMEOUT)
      end
      client:send(method.serialize_call(...))
      if #method.result_types() == 0 then
        break
      end
      local _, err = client:receive(0)
      if err == "closed" then
        connected = false
        client = socket.tcp()
        proxy.client = client
      elseif err then
        error("RPC error: " .. err)
      else
        sent = true
      end
    end
    local results = {}
    local result_types = method.result_types()
    for i in ipairs(result_types) do
      line, err = client:receive()
      err = err or string.match(line, "^___ERRORPC: (.*)$")
      if err then
        error("RPC error: " .. err)
      end
      results[#results + 1] = rpc.deserialize(result_types[i], line)
    end
    return unpack(results)
  end
end

local proxy_mt = {
  __index = proxy_call
}

rpc.create_proxy_from_interface = function(ip, port, interface)
  local proxy = {
    ip=ip,
    port=port,
    client=socket.tcp(),
    interface=interface
  }
  setmetatable(proxy, proxy_mt)
  return proxy
end

-- server functions
local accept_new_client = function(servant)
  local server = servant.server
  local client, err = server:accept()
  if err then
    -- ignores timeouts
    return
  end
  client:settimeout(SERVER_LISTEN_TIMEOUT)
  return client
end

local exec_procedure = function(client, method, implementation)
  local arg_types = method.arg_types()
  args = {}
  for i in ipairs(arg_types) do
    line = client:receive()
    args[#args + 1] = rpc.deserialize(arg_types[i], line)
  end
  local results = {implementation(unpack(args))}
  local result_str = rpc.serialize_list(method.result_types(), results)
  client:send(result_str)
end

local send_error = function(client, err)
  client:send("___ERRORPC: " .. err .. "\n")
  client:close()
end

local serve_client = function(servant, client)
  if client == nil then
    client = servant:accept_new_client()
    if client == nil then return end
  end
  local method_name, err = client:receive()
  if err then
    return send_error(client, "Unknown error: " .. err)
  end
  local method = servant.interface[method_name]
  if method == nil then
    return send_error(client, "Unknown command '" .. (method_name or "") .. "'")
  end
  local implementation = servant.implementation[method_name]
  if implementation == nil then
    return send_error(client, "Command '" .. (method_name or "") .. "' not implemented")
  end
  local status, err = pcall(exec_procedure, client, method, implementation)
  if not status then
    return send_error(client, "Unknown error: '" .. err .. "'")
  end
  if not servant.keepalive then
    client:close()
  end
end

rpc.create_servant_from_interface = function(implementation, interface, port, keepalive)
  port = port or 0
  local server = assert(socket.bind("*", port))
  if keepalive == nil then keepalive = true end
  server:settimeout(SERVER_ACCEPT_TIMEOUT)
  local ip, port = server:getsockname()
  local s = {
    interface=interface,
    accept_new_client=accept_new_client,
    serve_client=serve_client,
    implementation=implementation,
    keepalive=keepalive,
    ip=ip,
    port=port,
    server=server
  }
  setmetatable(s, {__index = function(o, method_name) return o.server[method_name] end })
  return s
end

-- public methods (no unit tests, just integration tests)
rpc.createProxy = function(IP, port, interface_file)
  local int
  interface = function(x)
    int = rpc.interface(x)
  end
  dofile(interface_file)
  return rpc.create_proxy_from_interface(IP, port, int)
end

local servants = {}
local client_servants = {}
local open_sockets = {}
local open_connections = 0

rpc.createServant = function(implementation, interface_file, ...)
  local int
  interface = function(x)
    int = rpc.interface(x)
  end
  dofile(interface_file)
  servant = rpc.create_servant_from_interface(implementation, int, ...)
  servants[servant.server] = servant
  open_sockets[#open_sockets + 1] = servant.server
  return servant
end

rpc.waitIncoming = function()
  function handle_new_client(servant)
    local client = servant:accept_new_client()
    local ip, port = client:getpeername()
    open_connections = open_connections + 1
    print("New client: " .. ip .. ":" .. port .. " (" .. open_connections .. " connected)")
    kill_extra_clients()
    if client then
      open_sockets[#open_sockets + 1] = client
      client_servants[client] = servant
    end
  end

  function handle_connections()
    local ready = socket.select(open_sockets)
    for _, socket in ipairs(ready) do
      local servant = servants[socket]
      if servant then
        handle_new_client(servant)
      else
        servant = client_servants[socket]
        servant:serve_client(socket)
      end
    end
  end

  function kill_extra_clients()
    while open_connections > MAX_SERVER_CONNECTIONS do
      for client, servant in pairs(client_servants) do
        local ip, port = client:getpeername()
        print("Forcing client to close: " .. ip .. ":" .. port)
        client:close()
        clean_client(client)
        break
      end
    end
  end

  function clean_client(client)
    for i, s in ipairs(open_sockets) do
      if s == client then
        table.remove(open_sockets, i)
        client_servants[client] = nil
        open_connections = open_connections - 1
        break
      end
    end
  end

  function clean_closed_connections()
    for client, servant in pairs(client_servants) do
      local connected = client:getpeername()
      if not connected then
        print("Client closed (" .. open_connections .. " connected)")
        clean_client(client)
      end
    end
  end

  while true do
    handle_connections()
    clean_closed_connections()
  end
end

return rpc