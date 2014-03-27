local rpc = require("rpc")

describe("interface", function()
  it("should have name", function()
    interface = rpc.interface
    local i = interface { name = "myInterface" }
    assert.truthy(i)
    assert.are.equal(i.name, "myInterface")
  end)
end)