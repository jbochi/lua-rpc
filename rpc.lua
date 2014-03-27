local rpc = {}

rpc.interface = function(args)
    return {name=args.name}
end

return rpc