local rpc = {}

local interface_mt = {
    __index = function(o, method)
        return o._methods[method]
    end
}

rpc.interface = function(args)
    local interface = {_name=args.name, _methods=args.methods}
    setmetatable(interface, interface_mt)
    return interface
end

return rpc
