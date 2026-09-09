--!strict

const RunService = game:GetService("RunService")

const Signal = require(script.Parent.Parent.Signal)
const Maid = require(script.Parent.Parent.Maid)
const Dispatcher = require("./Dispatcher")

const FRAMES_PER_SECOND = 60
const NEVER_PLAYED_TIMEOUT = 1
const TRACING = RunService:IsStudio()

export type ScheduledEvent = {
	TargetFrame: number,
	Callback: Dispatcher.Callback,
	Args: { any }?,
}

type Fields = {
	Track: AnimationTrack,
	Events: { ScheduledEvent },
	Maid: any,
	Finished: any,
	IsDead: boolean,
	HasStarted: boolean,
}

const TrackSequencer = {}
TrackSequencer.__index = TrackSequencer

export type TrackSequencer = typeof(setmetatable({} :: Fields, TrackSequencer))

function TrackSequencer.new(Track: AnimationTrack): TrackSequencer
	const self: Fields = {
		Track = Track,
		Events = {},
		Maid = Maid.new(),
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

	table.insert(self.Events, {
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
	self.Maid:DoCleaning()

	const Unfired = #self.Events
	table.clear(self.Events)

	self.Finished:Fire(Unfired == 0)
	self.Finished:Destroy()
end

function TrackSequencer.Start(self: TrackSequencer): TrackSequencer
	if self.IsDead or self.HasStarted then
		return self
	end

	self.HasStarted = true

	const StartedAt = os.clock()
	local HasPlayed = false

	self.Maid:GiveTask(RunService.PostSimulation:Connect(function()
		if self.IsDead then
			return
		end

		if not self.Track.IsPlaying then
			if not HasPlayed and os.clock() - StartedAt <= NEVER_PLAYED_TIMEOUT then
				return
			end

			if not HasPlayed and TRACING then
				warn(
					`[perfect sequencer] track "{self.Track.Name}" never played within `
						.. `{NEVER_PLAYED_TIMEOUT}s, cancelling`
				)
			end

			self:Cancel()
			return
		end

		HasPlayed = true

		const Frame = self.Track.TimePosition * FRAMES_PER_SECOND

		for Index = #self.Events, 1, -1 do
			const Event = self.Events[Index]

			if Frame >= Event.TargetFrame then
				table.remove(self.Events, Index)
				Dispatcher.Dispatch(Event.Callback, Event.Args)
			end
		end

		if #self.Events == 0 then
			self:Cancel()
		end
	end))

	return self
end

return TrackSequencer
