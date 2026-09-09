--!strict

const RunService = game:GetService("RunService")

const Signal = require(script.Parent.Parent.Signal)
const Configuration = require("./Configuration")
const Dispatcher = require("./Dispatcher")

export type ScheduledEvent = {
	TargetFrame: number,
	Callback: Dispatcher.Callback,
	Args: { any }?,
}

type Fields = {
	Track: AnimationTrack,
	Events: { ScheduledEvent },
	Connection: RBXScriptConnection?,
	Finished: any,
	IsDead: boolean,
}

const TrackSequencer = {}
TrackSequencer.__index = TrackSequencer

export type TrackSequencer = typeof(setmetatable({} :: Fields, TrackSequencer))

function TrackSequencer.new(Track: AnimationTrack): TrackSequencer
	const self: Fields = {
		Track = Track,
		Events = {},
		Connection = nil,
		Finished = Signal.new(),
		IsDead = false,
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

	const Connection = self.Connection

	if Connection then
		Connection:Disconnect()
		self.Connection = nil
	end

	const Unfired = #self.Events
	table.clear(self.Events)

	self.Finished:Fire(Unfired == 0)
	self.Finished:Destroy()
end

function TrackSequencer.Start(self: TrackSequencer): TrackSequencer
	if self.IsDead or self.Connection then
		return self
	end

	const StartedAt = os.clock()
	local HasPlayed = false

	self.Connection = RunService.PostSimulation:Connect(function()
		if self.IsDead then
			return
		end

		if not self.Track.IsPlaying then
			if not HasPlayed and os.clock() - StartedAt <= Configuration.NeverPlayedTimeout then
				return
			end

			if not HasPlayed and Configuration.Tracing then
				warn(
					`[perfect sequencer] track "{self.Track.Name}" never played within `
						.. `{Configuration.NeverPlayedTimeout}s, cancelling`
				)
			end

			self:Cancel()
			return
		end

		HasPlayed = true

		const Frame = self.Track.TimePosition * Configuration.FramesPerSecond

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
	end)

	return self
end

return TrackSequencer
