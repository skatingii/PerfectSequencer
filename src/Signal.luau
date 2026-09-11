--!strict

export type Connection = {
	Connected: boolean,
	Handler: (...any) -> (),
	Next: Connection?,
	Disconnect: (self: Connection) -> (),
}

type Fields = {
	Head: Connection?,
}

local FreeRunnerThread: thread? = nil

const function AcquireRunnerThreadAndCallHandler(Handler: (...any) -> (), ...: any)
	const AcquiredThread = FreeRunnerThread
	FreeRunnerThread = nil

	Handler(...)

	FreeRunnerThread = AcquiredThread
end

const function RunHandlerInFreeThread(...: any)
	AcquireRunnerThreadAndCallHandler(...)

	while true do
		AcquireRunnerThreadAndCallHandler(coroutine.yield())
	end
end

const SignalClass = {}
SignalClass.__index = SignalClass

export type Signal = typeof(setmetatable({} :: Fields, SignalClass))

function SignalClass.Connect(self: Signal, Handler: (...any) -> ()): Connection
	const Link: Connection = {
		Connected = true,
		Handler = Handler,
		Next = self.Head,

		Disconnect = function(Node: Connection)
			if not Node.Connected then
				return
			end

			Node.Connected = false

			if self.Head == Node then
				self.Head = Node.Next
				return
			end

			local Previous = self.Head

			while Previous and Previous.Next ~= Node do
				Previous = Previous.Next
			end

			if Previous then
				Previous.Next = Node.Next
			end
		end,
	}

	self.Head = Link

	return Link
end

function SignalClass.Once(self: Signal, Handler: (...any) -> ()): Connection
	local Link: Connection

	Link = self:Connect(function(...)
		Link:Disconnect()
		Handler(...)
	end)

	return Link
end

function SignalClass.Wait(self: Signal): ...any
	const Waiting = coroutine.running()

	self:Once(function(...)
		task.spawn(Waiting, ...)
	end)

	return coroutine.yield()
end

function SignalClass.Fire(self: Signal, ...: any)
	local Link = self.Head

	while Link do
		if Link.Connected then
			local Runner = FreeRunnerThread

			if not Runner then
				Runner = coroutine.create(RunHandlerInFreeThread)
				FreeRunnerThread = Runner
			end

			if Runner then
				task.spawn(Runner, Link.Handler, ...)
			end
		end

		Link = Link.Next
	end
end

function SignalClass.DisconnectAll(self: Signal)
	local Link = self.Head

	while Link do
		Link.Connected = false
		Link = Link.Next
	end

	self.Head = nil
end

SignalClass.Destroy = SignalClass.DisconnectAll

const Signal = {}

function Signal.new(): Signal
	const self: Fields = {
		Head = nil,
	}

	return setmetatable(self, SignalClass)
end

return Signal
