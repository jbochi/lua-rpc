local rpc = require("rpc")
local interface = rpc.interface


describe("interface", function()
  it("should have a name", function()
    local i = interface { name = "myInterface" }
    assert.truthy(i)
    assert.are.equal("myInterface", i.__name)
  end)

  describe("a method", function()
    it("should be created", function()
      local i = interface { methods = {
        foo = { resulttype = "double"
      }}}
      assert.truthy(i.foo)
    end)

    it("should know the result types", function()
      local i = interface { methods = {
        foo = { resulttype = "double"
      }}}
      assert.same({"double"}, i.foo.result_types())
    end)

    it("should support multiple results", function()
      local i = interface { methods = {
        foo = { resulttype = "double",
                args = {{direction = "in",
                          type = "double"},
                        {direction = "out",
                          type = "string"}}}
      }}
      assert.same({"double", "string"}, i.foo.result_types())
    end)

    it("should know the argument types", function()
      local i = interface { methods = {
        foo = { resulttype = "double",
                args = {{direction = "in",
                          type = "double"},
                        {direction = "in",
                          type = "char"},
                        {direction = "out",
                          type = "string"}}}
      }}
      assert.same({"double", "char"}, i.foo.arg_types())
    end)

    it("should support in/out direction", function()
      local i = interface { methods = {
        foo = { resulttype = "double",
                args = {{direction = "inout",
                          type = "string"}}}
      }}
      assert.same({"string"}, i.foo.arg_types())
      assert.same({"double", "string"}, i.foo.result_types())
    end)

    it("should support void", function()
      local i = interface { methods = {
        foo = { resulttype = "void", args = {} }
      }}
      assert.same({}, i.foo.arg_types())
      assert.same({}, i.foo.result_types())
    end)
  end)
end)

describe("serialization", function()
  it("should serialize a string", function()
    assert.same("oi", rpc.serialize("string", "oi"))
  end)

  it("should escape new lines", function()
    assert.same("\\n", rpc.serialize("string", "\n"))
  end)

  it("should escape slashes", function()
    assert.same("\\\\n", rpc.serialize("string", "\\n"))
  end)

  it("should serialize a char", function()
    assert.same("o", rpc.serialize("char", "o"))
  end)

  it("should support doubles", function()
    assert.same("3.1415", rpc.serialize("double", 3.1415))
  end)

  it("should validate arguments", function()
    assert.has_error(function() rpc.serialize("string", 4) end, "String expected")
    assert.has_error(function() rpc.serialize("string", nil) end, "String expected")
    assert.has_error(function() rpc.serialize("char", "asdf") end, "Char expected")
    assert.has_error(function() rpc.serialize("char", 4) end, "Char expected")
    assert.has_error(function() rpc.serialize("double", "a") end, "Double expected")
    assert.has_error(function() rpc.serialize("double", nil) end, "Double expected")
  end)

  describe("list serialization", function()
    it("should serialize a list with new line separator", function()
      assert.same("a\nb\nc\n", rpc.serialize_list({"string", "string", "string"}, {"a", "b", "c"}))
    end)

    it("should validate the number of arguments", function()
      assert.has_error(function() rpc.serialize_list({"string"}, {}) end,
        "Wrong number of arguments (0 instead of 1)")
      assert.has_error(function() rpc.serialize_list({"string"}, {"a", "b"}) end,
        "Wrong number of arguments (2 instead of 1)")
    end)

    it("should validate the argument types", function()
      assert.has_error(function() rpc.serialize_list({"string"}, {7}) end,
        "String expected")
    end)
  end)
end)

describe("deserialization", function()
  it("should validate doubles", function()
    assert.has_error(function() rpc.deserialize("double", "abc") end, "Double expected")
  end)

  it("should validate chars", function()
    assert.has_error(function() rpc.deserialize("char", "abc") end, "Char expected")
  end)

  it("should deserialize to original value", function()
    assert.same("abc", rpc.deserialize("string", rpc.serialize("string", "abc")))
    assert.same("a", rpc.deserialize("char", rpc.serialize("char", "a")))
    assert.same(3.14, rpc.deserialize("double", rpc.serialize("double", 3.14)))
    assert.same("a\\b", rpc.deserialize("string", rpc.serialize("string", "a\\b")))
    assert.same("a\n", rpc.deserialize("string", rpc.serialize("string", "a\n")))
    assert.same("\n", rpc.deserialize("string", rpc.serialize("string", "\n")))
    assert.same("\\n\\", rpc.deserialize("string", rpc.serialize("string", "\\n\\")))
  end)
end)

describe("communication", function()
  describe("a simple method", function ()
    before_each(function()
      i = interface { methods = {
        add = { resulttype = "double",
                args = {{direction="in", type="double"},
                        {direction="in", type="double"},
                }}
      }}
      add = i.add
    end)

    it("should serialize a call", function()
      assert.same("add\n3\n4\n", add.serialize_call(3, 4))
    end)

    it("should validate the number of arguments for a call", function()
      assert.has_error(function() add.serialize_call(4) end, "Wrong number of arguments (2 instead of 3)")
      assert.has_error(function() add.serialize_call(4, 5, 6) end, "Wrong number of arguments (4 instead of 3)")
    end)

    it("should serialize returned values", function()
      assert.same("7\n", add.serialize_result(7))
    end)

    describe("proxy", function()
      before_each(function()
        socket = require("socket")
        client = {
          send = function(c, str)
            return true
          end,
          settimeout = function() end,
          receive = function(c)
            return "8"
          end
        }
        socket.connect = function()
          return client
        end
        spy.on(socket, "connect")
        mock(client)
        p = rpc.create_proxy_from_interface("127.0.0.1", 1234, i)
      end)

      it("should handle the happy path", function()
        local r = p.add(3, 5)

        assert.spy(socket.connect).was.called_with("127.0.0.1", 1234)
        assert.spy(client.send).was.called_with(client, "add\n3\n5\n")
        assert.spy(client.receive).was.called_with(client)
        assert.same(8, r)
      end)

      it("should not allow invalid methods", function()
        assert.has_error(function() p.mul(3, 5) end, "Invalid method")
      end)

      it("should handle errors", function()
        client.receive = function(c)
          return "___ERRORPC: sorry!"
        end

        assert.has_error(function() p.add(3, 5) end, "RPC error: sorry!")
      end)

      it("should handle multiple arguments", function()
        i.__methods.swap = { resulttype = "double",
                             args = {{direction="in", type="double"},
                                     {direction="inout", type="double"}}}
        local return_value_index = 0
        local return_values = {"2", "1"}
        client.receive = function(c)
          return_value_index = return_value_index + 1
          return return_values[return_value_index]
        end
        local a, b = 1, 2
        a, b = p.swap(a, b)
        assert.same(2, a)
        assert.same(1, b)
      end)
    end)

    describe("servant", function()
      before_each(function()
        socket = require("socket")
        local return_value_index = 0
        return_values = {"add", "3", "4"}
        client = {
          receive = function()
            return_value_index = return_value_index + 1
            return return_values[return_value_index]
          end,
          settimeout = function() end,
          send = function(arg)
            return true
          end,
          close = function()
            return true
          end,
        }
        server = {
          getsockname = function(s)
            return "0.0.0.0", 60468
          end,
          settimeout = function() end,
          accept = function(s)
            return client, nil
          end,
        }
        socket.bind = function(ip, port)
          return server
        end
        spy.on(socket, "bind")
        mock(server)
        mock(client)
        implementation = {
          add = function(a, b) return a + b end
        }
        servant = rpc.create_servant_from_interface(implementation, i)
        ip = servant.ip
        port = servant.port
      end)

      it("should bind to local host at any port", function()
        assert.spy(socket.bind).was.called_with("*", 0)
        assert.same(ip, "0.0.0.0")
        assert.same(port, 60468)
      end)

      it("should handle clients", function()
        servant:serve_client()
        assert.spy(server.accept).called()
        assert.spy(client.receive).called(3) -- three lines for function call are read
        assert.spy(client.send).called_with(client, "7\n")
        assert.spy(client.close).called()
      end)

      it("should ignore timeouts", function()
        server.accept = function()
          return nil, "timeout"
        end
        spy.on(server, "accept")
        servant:serve_client()
        assert.spy(server.accept).called()
        assert.spy(client.receive).not_called()
      end)

      it("should handle receive timeouts", function()
        client.receive = function()
          return nil, "timeout"
        end
        spy.on(client, "receive")
        servant:serve_client()
        assert.spy(server.accept).called()
        assert.spy(client.receive).called(1)
        assert.spy(client.send).called_with(client, "___ERRORPC: Unknown error: timeout\n")
        assert.spy(client.close).called()
      end)

      it("should handle unknown commands", function()
        return_values = {"baz", "3", "4"}
        servant:serve_client()
        assert.spy(server.accept).called()
        assert.spy(client.receive).called(1)
        assert.spy(client.send).called_with(client, "___ERRORPC: Unknown command 'baz'\n")
        assert.spy(client.close).called()
      end)

      it("should handle missing implementation", function()
        servant.implementation.add = nil
        servant:serve_client()
        assert.spy(server.accept).called()
        assert.spy(client.receive).called(1)
        assert.spy(client.send).called_with(client, "___ERRORPC: Command 'add' not implemented\n")
        assert.spy(client.close).called()
      end)

      it("should handle broken implementations", function()
        local ln = debug.getinfo(1).currentline + 1
        servant.implementation.add = function(a, b) error("error") end
        servant:serve_client()
        assert.spy(server.accept).called()
        assert.spy(client.receive).called(3)
        local expected_error = "___ERRORPC: Unknown error: './test.lua:" .. ln .. ": error'\n"
        assert.spy(client.send).called_with(client, expected_error)
        assert.spy(client.close).called()
      end)
    end)
  end)
end)
