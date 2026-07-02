function Limiter(value,min,max)
	if (value < min) then 
		value = min
	elseif (value > max) then
		value = max
	end
	return value
end
