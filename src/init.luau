--[[

	PerfectSequencer
	Made by skaterstudios

	Frame-accurate event scheduling for Roblox.

	AddEvent and Run share one wall-clock scheduler whose delays are measured
	in 60fps frames but ticked against real DeltaTime, so they hold under
	frame drops.

	ForTrack returns a per-swing scheduler locked to an AnimationTrack's own
	timeline. It follows the animation through speed changes and dies with
	the track.

	Version 0.1.0

]]

--!strict

const RunService = game:GetService("RunService")

const Signal = require("@self/Signal")
const Cleanup = require("@self/Cleanup")
const Dispatcher = require("@self/Dispatcher")
const TrackSequencer = require("@self/TrackSequencer")

const FRAMES_PER_SECOND = 60

export type SequencerEvent = {
	PresetFrame: number,
	Callback: Dispatcher.Callback,
	Args: { any }?,
}

export type TrackSequencer = TrackSequencer.TrackSequencer

const PerfectSequencer = {}

PerfectSequencer.Completed = Signal.new()

const Queue: { TrackSequencer.ScheduledEvent } = {}
local RunCleanup: Cleanup.Cleanup? = nil
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

	const Base = if RunCleanup then Clock else 0

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
	return RunCleanup ~= nil
end

function PerfectSequencer.GetPendingCount(): number
	return #Queue
end

function PerfectSequencer.Stop()
	if not RunCleanup then
		return
	end

	RunCleanup:Clean()
	RunCleanup = nil

	PerfectSequencer.Completed:Fire()
end

function PerfectSequencer.Run()
	if RunCleanup then
		return
	end

	Clock = 0

	const NewCleanup = Cleanup.new()
	RunCleanup = NewCleanup

	NewCleanup:Add(RunService.PostSimulation:Connect(function(DeltaTime: number)
		Clock += DeltaTime * FRAMES_PER_SECOND

		for Index = #Queue, 1, -1 do
			const Event = Queue[Index]

			if Clock < Event.TargetFrame then
				break
			end

			table.remove(Queue, Index)
			Dispatcher.Dispatch(Event.Callback, Event.Args)
		end

		if #Queue == 0 then
			PerfectSequencer.Stop()
		end
	end))
end

function PerfectSequencer.ForTrack(Track: AnimationTrack): TrackSequencer.TrackSequencer
	return TrackSequencer.new(Track)
end

return PerfectSequencer
