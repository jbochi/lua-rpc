local rpc = {}

-- create a method based on its interface definition
local method = function(method_interface)
    local m = {}
    m.result_types = function()
        return {method_interface.resulttype}
    end
    return m
end

-- the interface metatable defines the metamethods for a interface
local interface_mt = {
    __index = function(o, method_name)
        local m = o.__methods[method_name]
        if m then return method(m) end
    end
}

-- function to load new interfaces
rpc.interface = function(args)
    local interface = {__name=args.name, __methods=args.methods}
    setmetatable(interface, interface_mt)
    return interface
end

return rpc
