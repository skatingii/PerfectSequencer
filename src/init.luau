--!strict

const RunService = game:GetService("RunService")

const Signal = require(script.Parent.Signal)
const Configuration = require("@self/Configuration")
const Dispatcher = require("@self/Dispatcher")
const TrackSequencer = require("@self/TrackSequencer")

export type SequencerEvent = {
	PresetFrame: number,
	Callback: Dispatcher.Callback,
	Args: { any }?,
}

export type TrackSequencer = TrackSequencer.TrackSequencer

const PerfectSequencer = {}

PerfectSequencer.Completed = Signal.new()

const Queue: { TrackSequencer.ScheduledEvent } = {}
local Connection: RBXScriptConnection? = nil
local Clock = 0

function PerfectSequencer.AddEvent(Event: SequencerEvent)
	if type(Event.PresetFrame) ~= "number" then
		warn(`[perfect sequencer] AddEvent needs a numeric PresetFrame, got {typeof(Event.PresetFrame)}`)
		return
	end

	if type(Event.Callback) ~= "function" then
		warn(`[perfect sequencer] AddEvent needs a Callback function, got {typeof(Event.Callback)}`)
		return
	end

	const Base = if Connection then Clock else 0

	const Scheduled: TrackSequencer.ScheduledEvent = {
		TargetFrame = Base + Event.PresetFrame,
		Callback = Event.Callback,
		Args = Event.Args,
	}

	local Low, High = 1, #Queue + 1

	while Low < High do
		const Middle = (Low + High) // 2

		if Queue[Middle].TargetFrame > Scheduled.TargetFrame then
			Low = Middle + 1
		else
			High = Middle
		end
	end

	table.insert(Queue, Low, Scheduled)
end

function PerfectSequencer.Reset()
	table.clear(Queue)
end

function PerfectSequencer.IsRunning(): boolean
	return Connection ~= nil
end

function PerfectSequencer.GetPendingCount(): number
	return #Queue
end

function PerfectSequencer.Run()
	if Connection then
		return
	end

	Clock = 0

	Connection = RunService.PostSimulation:Connect(function(DeltaTime: number)
		Clock += DeltaTime * Configuration.FramesPerSecond

		for Index = #Queue, 1, -1 do
			const Event = Queue[Index]

			if Clock < Event.TargetFrame then
				break
			end

			table.remove(Queue, Index)
			Dispatcher.Dispatch(Event.Callback, Event.Args)
		end

		if #Queue == 0 and Connection then
			Connection:Disconnect()
			Connection = nil

			PerfectSequencer.Completed:Fire()
		end
	end)
end

function PerfectSequencer.ForTrack(Track: AnimationTrack): TrackSequencer.TrackSequencer
	return TrackSequencer.new(Track)
end

return PerfectSequencer
