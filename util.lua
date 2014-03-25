local util = {}

util.hex = function (str)
	return (string.gsub(str,"(.)", function (c)
		return string.format("%02X%s",string.byte(c), "")
	end))
end

return util