--!strict

const Signal = require(script.Parent.Parent.Signal)

export type Callback = (...any) -> ...any

const DispatchSignal = Signal.new()

DispatchSignal:Connect(function(Callback: Callback, Args: { any }?)
	const Succeeded, Problem = pcall(Callback, table.unpack(Args or {}))

	if not Succeeded then
		warn(`[perfect sequencer] event callback errored: {Problem}`)
	end
end)

const Dispatcher = {}

function Dispatcher.Dispatch(Callback: Callback, Args: { any }?)
	DispatchSignal:Fire(Callback, Args)
end

return Dispatcher
