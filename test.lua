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
end)

describe("deserialization", function()
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
