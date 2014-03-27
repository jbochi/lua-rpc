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
  end)
end)
