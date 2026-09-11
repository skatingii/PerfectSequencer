type Callback = (...args: never[]) => void;

interface Connection {
	Connected: boolean;
	Disconnect(): void;
}

interface Signal<T extends unknown[] = []> {
	Connect(handler: (...args: T) => void): Connection;
	Once(handler: (...args: T) => void): Connection;
	Wait(): LuaTuple<T>;
	Fire(...args: T): void;
	DisconnectAll(): void;
	Destroy(): void;
}

/**
 * A scheduler locked to an AnimationTrack's own timeline. It reads
 * TimePosition, so it follows the animation through speed changes and stops
 * when the track does.
 */
interface TrackSequencer {
	/**
	 * Schedules a callback at a frame on the track's timeline. Chainable.
	 * Order does not matter.
	 */
	At(frame: number, callback: Callback, args?: unknown[]): TrackSequencer;

	/**
	 * Begins watching the track. Chainable. Waits for the track to actually
	 * begin, and cancels itself if it never plays within one second.
	 */
	Start(): TrackSequencer;

	/** Stops the sequencer, drops pending events, and fires Finished(false). */
	Cancel(): void;

	/**
	 * Fired exactly once. True if every event ran, false if the sequencer was
	 * cancelled with events still pending.
	 */
	readonly Finished: Signal<[ranToCompletion: boolean]>;
}

interface SequencerEvent {
	/** Target frame, measured at 60fps against real DeltaTime. */
	PresetFrame: number;
	Callback: Callback;
	Args?: unknown[];
}

declare const PerfectSequencer: {
	/** Queues a callback on the shared scheduler. */
	AddEvent(event: SequencerEvent): void;

	/** Starts the shared clock. No-op if already running. */
	Run(): void;

	/** Stops the clock early and fires Completed. Pending events stay queued. */
	Stop(): void;

	/** Clears every queued event without stopping the clock. */
	Reset(): void;

	IsRunning(): boolean;

	GetPendingCount(): number;

	/** Returns a scheduler locked to the given track's timeline. */
	ForTrack(track: AnimationTrack): TrackSequencer;

	/** Fired when the queue drains and the clock stops. */
	readonly Completed: Signal;
};

export = PerfectSequencer;
