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

return function(T: any, Queue: any)
	T:Test("inserts in descending order so the soonest event is last", function()
		const Events = {}

		Queue.Insert(Events, Event(20))
		Queue.Insert(Events, Event(4))
		Queue.Insert(Events, Event(12))

		T:Equal(Frames(Events), "20,12,4", "queue order")
	end)

	T:Test("keeps order when inserting a duplicate frame", function()
		const Events = {}

		Queue.Insert(Events, Event(10))
		Queue.Insert(Events, Event(10))
		Queue.Insert(Events, Event(5))

		T:Equal(Frames(Events), "10,10,5", "queue order with duplicates")
	end)

	T:Test("takes nothing before the first event is due", function()
		const Events = {}
		Queue.Insert(Events, Event(10))

		T:Equal(#Queue.TakeDue(Events, 9.99), 0, "due count")
		T:Equal(#Events, 1, "queue length")
	end)

	T:Test("takes an event exactly on its frame", function()
		const Events = {}
		Queue.Insert(Events, Event(10))

		T:Equal(#Queue.TakeDue(Events, 10), 1, "due count")
		T:Equal(#Events, 0, "queue length")
	end)

	T:Test("takes due events in ascending frame order", function()
		const Events = {}

		Queue.Insert(Events, Event(20))
		Queue.Insert(Events, Event(4))
		Queue.Insert(Events, Event(12))

		T:Equal(Frames(Queue.TakeDue(Events, 12)), "4,12", "fire order")
		T:Equal(Frames(Events), "20", "remaining")
	end)

	T:Test("takes every event when the clock passes all of them", function()
		const Events = {}

		Queue.Insert(Events, Event(1))
		Queue.Insert(Events, Event(2))
		Queue.Insert(Events, Event(3))

		T:Equal(#Queue.TakeDue(Events, 100), 3, "due count")
		T:Equal(#Events, 0, "queue length")
	end)

	T:Test("handles an empty queue", function()
		const Events = {}

		T:Equal(#Queue.TakeDue(Events, 50), 0, "due count")
	end)

	T:Test("inserts a frame earlier than everything queued", function()
		const Events = {}

		Queue.Insert(Events, Event(10))
		Queue.Insert(Events, Event(20))
		Queue.Insert(Events, Event(1))

		T:Equal(Frames(Events), "20,10,1", "queue order")
	end)
end
