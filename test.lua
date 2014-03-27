local rpc = require("rpc")
local interface = rpc.interface


describe("interface", function()
  it("should have name", function()
    local i = interface { name = "myInterface" }
    assert.truthy(i)
    assert.are.equal(i._name, "myInterface")
  end)

  it("should create some methods", function()
    local i = interface { methods = {
      foo = { resulttype = "double"
    }}}
    assert.truthy(i.foo)
  end)
end)
