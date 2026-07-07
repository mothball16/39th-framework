local SequenceEval = {}

function SequenceEval.evalColorSequence(sequence: ColorSequence, time: number, backOffset: number?, blendAlpha: number?)
	if time == 0 then
		return sequence.Keypoints[1].Value
	elseif time == 1 then
		return sequence.Keypoints[#sequence.Keypoints].Value
	end

	local offset = backOffset or 0
	local blend = blendAlpha or 1
	if offset > 0 and blend < 1 then
		local backTime = math.clamp(time - offset, 0, 1)
		local backValue = SequenceEval.evalColorSequence(sequence, backTime)
		local currValue = SequenceEval.evalColorSequence(sequence, time)
		return backValue:Lerp(currValue, blend)
	end

	for i = 1, #sequence.Keypoints - 1 do
		local thisKeypoint = sequence.Keypoints[i]
		local nextKeypoint = sequence.Keypoints[i + 1]
		if time >= thisKeypoint.Time and time < nextKeypoint.Time then
			local alpha = (time - thisKeypoint.Time) / (nextKeypoint.Time - thisKeypoint.Time)
			return Color3.new(
				(nextKeypoint.Value.R - thisKeypoint.Value.R) * alpha + thisKeypoint.Value.R,
				(nextKeypoint.Value.G - thisKeypoint.Value.G) * alpha + thisKeypoint.Value.G,
				(nextKeypoint.Value.B - thisKeypoint.Value.B) * alpha + thisKeypoint.Value.B
			)
		end
	end
	return Color3.new(0, 0, 0)
end

function SequenceEval.evalNumberSequence(
	sequence: NumberSequence,
	time: number,
	backOffset: number?,
	blendAlpha: number?
)
	if time == 0 then
		return sequence.Keypoints[1].Value
	elseif time == 1 then
		return sequence.Keypoints[#sequence.Keypoints].Value
	end

	local offset = backOffset or 0
	local blend = blendAlpha or 1
	if offset > 0 and blend < 1 then
		local backTime = math.clamp(time - offset, 0, 1)
		local backValue = SequenceEval.evalNumberSequence(sequence, backTime)
		local currValue = SequenceEval.evalNumberSequence(sequence, time)
		return backValue + (currValue - backValue) * blend
	end

	for i = 1, #sequence.Keypoints - 1 do
		local currKeypoint = sequence.Keypoints[i]
		local nextKeypoint = sequence.Keypoints[i + 1]
		if time >= currKeypoint.Time and time < nextKeypoint.Time then
			local alpha = (time - currKeypoint.Time) / (nextKeypoint.Time - currKeypoint.Time)
			return currKeypoint.Value + (nextKeypoint.Value - currKeypoint.Value) * alpha
		end
	end
	return 0
end

return SequenceEval
