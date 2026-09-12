--!strict

const Queue = require("./Queue")

const FRAMES_PER_SECOND = 60
const NEVER_PLAYED_TIMEOUT = 1

export type State = {
	Events: { Queue.Event },
	HasPlayed: boolean,
	StartedAt: number,
}

export type Step = {
	Due: { Queue.Event },
	Cancel: boolean,
	TimedOut: boolean,
}

const TrackState = {}

function TrackState.new(StartedAt: number): State
	return {
		Events = {},
		HasPlayed = false,
		StartedAt = StartedAt,
	}
end

function TrackState.Add(self: State, Event: Queue.Event)
	table.insert(self.Events, Event)
end

function TrackState.Step(self: State, IsPlaying: boolean, TimePosition: number, Now: number): Step
	if not IsPlaying then
		if not self.HasPlayed and Now - self.StartedAt <= NEVER_PLAYED_TIMEOUT then
			return { Due = {}, Cancel = false, TimedOut = false }
		end

		return { Due = {}, Cancel = true, TimedOut = not self.HasPlayed }
	end

	self.HasPlayed = true

	const Frame = TimePosition * FRAMES_PER_SECOND
	const Due: { Queue.Event } = {}

	for Index = #self.Events, 1, -1 do
		const Event = self.Events[Index]

		if Frame >= Event.TargetFrame then
			table.remove(self.Events, Index)
			table.insert(Due, Event)
		end
	end

	table.sort(Due, function(Left, Right)
		return Left.TargetFrame < Right.TargetFrame
	end)

	return { Due = Due, Cancel = #self.Events == 0, TimedOut = false }
end

return TrackState
