--!strict

const function Event(TargetFrame: number): any
	return {
		TargetFrame = TargetFrame,
		Callback = function() end,
	}
end

const function Frames(Events: { any }): string
	const Out = {}

	for _, Item in Events do
		table.insert(Out, tostring(Item.TargetFrame))
	end

	return table.concat(Out, ",")
end

return function(T: any, TrackState: any)
	T:Test("waits rather than cancelling while the track has not started", function()
		const State = TrackState.new(0)
		const Result = TrackState.Step(State, false, 0, 0.5)

		T:Equal(Result.Cancel, false, "cancel")
		T:Equal(Result.TimedOut, false, "timed out")
	end)

	T:Test("cancels once the track has not played for a second", function()
		const State = TrackState.new(0)
		const Result = TrackState.Step(State, false, 0, 1.5)

		T:Equal(Result.Cancel, true, "cancel")
		T:Equal(Result.TimedOut, true, "timed out")
	end)

	T:Test("cancels without a timeout once the track has played and stopped", function()
		const State = TrackState.new(0)
		TrackState.Add(State, Event(25))

		TrackState.Step(State, true, 0, 0.1)

		const Result = TrackState.Step(State, false, 0, 0.2)

		T:Equal(Result.Cancel, true, "cancel")
		T:Equal(Result.TimedOut, false, "timed out")
		T:Equal(#State.Events, 1, "pending events are left for Cancel to report")
	end)

	T:Test("fires nothing before the target frame", function()
		const State = TrackState.new(0)
		TrackState.Add(State, Event(25))

		const Result = TrackState.Step(State, true, 24 / 60, 0.1)

		T:Equal(#Result.Due, 0, "due count")
		T:Equal(Result.Cancel, false, "cancel")
	end)

	T:Test("fires exactly on the target frame", function()
		const State = TrackState.new(0)
		TrackState.Add(State, Event(25))

		const Result = TrackState.Step(State, true, 25 / 60, 0.1)

		T:Equal(#Result.Due, 1, "due count")
		T:Equal(Result.Cancel, true, "cancel once empty")
	end)

	T:Test("fires a stepped-over target late rather than skipping it", function()
		const State = TrackState.new(0)
		TrackState.Add(State, Event(25))

		const Result = TrackState.Step(State, true, 90 / 60, 0.5)

		T:Equal(#Result.Due, 1, "due count")
		T:Equal(Result.Due[1].TargetFrame, 25, "the skipped event still fired")
	end)

	T:Test("fires several due events in ascending frame order", function()
		const State = TrackState.new(0)

		TrackState.Add(State, Event(20))
		TrackState.Add(State, Event(4))
		TrackState.Add(State, Event(12))

		const Result = TrackState.Step(State, true, 30 / 60, 0.5)

		T:Equal(Frames(Result.Due), "4,12,20", "fire order")
	end)

	T:Test("leaves later events queued", function()
		const State = TrackState.new(0)

		TrackState.Add(State, Event(10))
		TrackState.Add(State, Event(40))

		const Result = TrackState.Step(State, true, 20 / 60, 0.5)

		T:Equal(#Result.Due, 1, "due count")
		T:Equal(Result.Cancel, false, "cancel")
		T:Equal(Frames(State.Events), "40", "remaining")
	end)

	T:Test("an event past the track length never becomes due", function()
		const State = TrackState.new(0)
		TrackState.Add(State, Event(90))

		const Playing = TrackState.Step(State, true, 72 / 60, 0.5)
		T:Equal(#Playing.Due, 0, "nothing fired")

		const Stopped = TrackState.Step(State, false, 0, 1.5)
		T:Equal(Stopped.Cancel, true, "cancelled when the track stopped")
		T:Equal(#State.Events, 1, "the unreachable event is still pending")
	end)

	T:Test("a restarted timeline does not refire an event", function()
		const State = TrackState.new(0)
		TrackState.Add(State, Event(25))

		T:Equal(#TrackState.Step(State, true, 25 / 60, 0.5).Due, 1, "first pass")
		T:Equal(#TrackState.Step(State, true, 25 / 60, 0.6).Due, 0, "second pass")
	end)
end
