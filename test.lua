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
    assert.same("oi\n", rpc.serialize("string", "oi"))
  end)

  it("should serialize a char", function()
    assert.same("o\n", rpc.serialize("char", "o"))
  end)

  it("should support doubles", function()
    assert.same("3.1415\n", rpc.serialize("double", 3.1415))
  end)
end)