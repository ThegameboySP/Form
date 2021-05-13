local TimeCycle = {}
TimeCycle.__index = TimeCycle

function TimeCycle.new(length)
	return setmetatable({
		_length = length;
		_multiplier = 1;
	}, TimeCycle)
end

function TimeCycle:GetMultiplier()
	return self._multiplier
end


function TimeCycle:SetMultiplier(multiplier)
	self._multiplier = multiplier
end


function TimeCycle:GetLength()
	return self._length
end


function TimeCycle:SetLength(length)
	self._length = length
end


function TimeCycle:Calculate(baseTime)
	return (baseTime * self._multiplier) % self._length
end


function TimeCycle:CalculatePercent(baseTime)
	return ((baseTime * self._multiplier) % self._length) / self._length
end


function TimeCycle:GetIterations(baseTime)
	return math.floor((baseTime * self._multiplier) / self._length)
end

return TimeCycle