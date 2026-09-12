--!strict

const RunService = game:GetService("RunService")

const Signal = require("./Signal")
const Cleanup = require("./Cleanup")
const Dispatcher = require("./Dispatcher")
const Queue = require("./Queue")
const TrackState = require("./TrackState")

const TRACING = RunService:IsStudio()

export type ScheduledEvent = Queue.Event

type Fields = {
	Track: AnimationTrack,
	State: TrackState.State,
	Cleanup: Cleanup.Cleanup,
	Finished: Signal.Signal,
	IsDead: boolean,
	HasStarted: boolean,
}

const TrackSequencer = {}
TrackSequencer.__index = TrackSequencer

export type TrackSequencer = typeof(setmetatable({} :: Fields, TrackSequencer))

function TrackSequencer.new(Track: AnimationTrack): TrackSequencer
	const self: Fields = {
		Track = Track,
		State = TrackState.new(os.clock()),
		Cleanup = Cleanup.new(),
		Finished = Signal.new(),
		IsDead = false,
		HasStarted = false,
	}

	return setmetatable(self, TrackSequencer)
end

function TrackSequencer.At(
	self: TrackSequencer,
	Frame: number,
	Callback: Dispatcher.Callback,
	Args: { any }?
): TrackSequencer
	if self.IsDead then
		warn(`[perfect sequencer] :At({Frame}) ignored, this track sequencer already finished`)
		return self
	end

	TrackState.Add(self.State, {
		TargetFrame = Frame,
		Callback = Callback,
		Args = Args,
	})

	return self
end

function TrackSequencer.Cancel(self: TrackSequencer)
	if self.IsDead then
		return
	end

	self.IsDead = true
	self.Cleanup:Clean()

	const Unfired = #self.State.Events
	table.clear(self.State.Events)

	self.Finished:Fire(Unfired == 0)
	self.Finished:Destroy()
end

function TrackSequencer.Start(self: TrackSequencer): TrackSequencer
	if self.IsDead or self.HasStarted then
		return self
	end

	self.HasStarted = true

	self.Cleanup:Add(RunService.PostSimulation:Connect(function()
		if self.IsDead then
			return
		end

		const Result = TrackState.Step(self.State, self.Track.IsPlaying, self.Track.TimePosition, os.clock())

		for _, Event in Result.Due do
			Dispatcher.Dispatch(Event.Callback, Event.Args)
		end

		if Result.TimedOut and TRACING then
			warn(`[perfect sequencer] track "{self.Track.Name}" never played, cancelling`)
		end

		if Result.Cancel then
			self:Cancel()
		end
	end))

	return self
end

return TrackSequencer
