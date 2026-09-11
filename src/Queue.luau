--!strict

export type Event = {
	TargetFrame: number,
	Callback: (...any) -> ...any,
	Args: { any }?,
}

const Queue = {}

function Queue.Insert(Events: { Event }, Item: Event)
	local Low, High = 1, #Events + 1

	while Low < High do
		const Middle = (Low + High) // 2

		if Events[Middle].TargetFrame > Item.TargetFrame then
			Low = Middle + 1
		else
			High = Middle
		end
	end

	table.insert(Events, Low, Item)
end

function Queue.TakeDue(Events: { Event }, Clock: number): { Event }
	const Due: { Event } = {}

	for Index = #Events, 1, -1 do
		const Item = Events[Index]

		if Clock < Item.TargetFrame then
			break
		end

		table.remove(Events, Index)
		table.insert(Due, Item)
	end

	return Due
end

return Queue
