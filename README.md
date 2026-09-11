<p align="center">
  <h1 align="center"><b>PerfectSequencer</b></h1>
  <p align="center">
    Frame-accurate event scheduling for Roblox
    <br />
    <a href="https://github.com/skatingii/PerfectSequencer"><strong>github →</strong></a>
  </p>
</p>

<div align="center">

![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/skatingii/PerfectSequencer/ci.yml?style=for-the-badge&branch=main&logo=github)
[![GitHub License](https://img.shields.io/github/license/skatingii/PerfectSequencer?style=for-the-badge)](LICENSE)

</div>

PerfectSequencer schedules callbacks by animation frame instead of by seconds. Write `12` and mean frame 12, the same number an animator reads off the timeline, rather than translating it into `task.wait(0.2)` and hoping the two stay in step.

**Two schedulers, for two different problems:**

- Fire events on a [shared clock](#addeventevent) that ticks against real `DeltaTime`, so timings hold under frame drops
- Fire events on an [animation's own timeline](#fortracktrack), so they follow the track through speed changes and die with it

**Why frames instead of seconds?**

Animation data is authored in frames. Once a hitbox is written as `0.2` seconds, the link back to the keyframe it came from is gone, and retiming the animation silently desynchronises the gameplay. Keeping the frame number keeps that link.

<details>
<summary><b>Table of Contents</b></summary>

- [Installation](#installation)
- [At a Glance](#at-a-glance)
- [Reference](#reference)
    - [`AddEvent(Event)`](#addeventevent)
    - [`Run()`](#run)
    - [`Stop()`](#stop)
    - [`Reset()`](#reset)
    - [`IsRunning()`](#isrunning)
    - [`GetPendingCount()`](#getpendingcount)
    - [`Completed`](#completed)
    - [`ForTrack(Track)`](#fortracktrack)
    - [`TrackSequencer:At(Frame, Callback, Args?)`](#tracksequenceratframe-callback-args)
    - [`TrackSequencer:Start()`](#tracksequencerstart)
    - [`TrackSequencer:Cancel()`](#tracksequencercancel)
    - [`TrackSequencer.Finished`](#tracksequencerfinished)
- [Choosing a scheduler](#choosing-a-scheduler)
- [How it behaves](#how-it-behaves)
- [Contributing](#contributing)

</details>

## Installation

```toml
# wally.toml
[dependencies]
PerfectSequencer = "skatingii/perfect-sequencer@0.1.0"
```

Then run `wally install`. The package lands at `Packages/PerfectSequencer`.

<details>
<summary><b>Before it is published</b></summary>

Wally 0.3.2 supports neither path nor git dependencies, so an unpublished package cannot be resolved from a manifest at all. To use it anyway, build the tree Wally would have produced:

```bash
wally install
bash scripts/build-package-tree.sh
```

That writes `dist/Packages`, containing the `_Index` layout and the generated link file. Copy it into your project's `ReplicatedStorage`. When the package is later published, `wally install` writes the same paths, so no require ever changes.

</details>

## At a Glance

```luau
local PerfectSequencer = require(ReplicatedStorage.Packages.PerfectSequencer)

local Track = Humanoid.Animator:LoadAnimation(Animation)

PerfectSequencer.ForTrack(Track)
	:At(4, function()
		SoundService:PlayLocalSound(Sounds.Windup)
	end)
	:At(12, function()
		ApplyHitbox(Character, CFrame.new(0, 0, -3), Vector3.new(4, 4, 6))
	end)
	:At(20, function()
		Character:SetAttribute("Cancellable", true)
	end)
	:Start()

Track:Play()
```

<details>
<summary>Explain code</summary>

```luau
local PerfectSequencer = require(ReplicatedStorage.Packages.PerfectSequencer)

local Track = Humanoid.Animator:LoadAnimation(Animation)

-- Create a scheduler bound to this specific swing. It reads the track's own
-- TimePosition, so every frame number below refers to the animation timeline
-- rather than to wall-clock time.
PerfectSequencer.ForTrack(Track)
	-- Frame 4: the windup is visible, so the sound lands with it
	:At(4, function()
		SoundService:PlayLocalSound(Sounds.Windup)
	end)
	-- Frame 12: the exact keyframe where the fist is extended
	:At(12, function()
		ApplyHitbox(Character, CFrame.new(0, 0, -3), Vector3.new(4, 4, 6))
	end)
	-- Frame 20: recovery has begun, so the player may cancel out
	:At(20, function()
		Character:SetAttribute("Cancellable", true)
	end)
	-- Nothing runs until Start. Order of :At calls does not matter.
	:Start()

-- Start may run a frame before Play, which is handled: the scheduler waits
-- for the track to actually begin before reading its timeline.
Track:Play()
```

</details>

If the player cancels the swing and the track stops, the scheduler stops with it. Frame 20 never fires, the connection is disconnected, and `Finished` reports that it did not run to completion.

## Reference

### `AddEvent(Event)`

Queues a callback on the shared scheduler. `Event` is a table of `PresetFrame`, `Callback`, and an optional `Args` array.

```luau
PerfectSequencer.AddEvent({
	PresetFrame = 12,
	Callback = function(Target)
		ApplyStun(Target)
	end,
	Args = { Target },
})

PerfectSequencer.Run()
```

Events are inserted in sorted order using a binary search, so queueing costs `O(log n)` and the drain loop stops at the first event that is not yet due. Queueing a thousand events does not cost a thousand comparisons per frame.

An event queued while the scheduler is **already running** counts its delay from the moment it was added, not from when `Run` was called. That is what makes it usable from inside another callback.

> [!NOTE]
> `PresetFrame` is measured at 60fps but ticked against real `DeltaTime`. Frame 30 means half a second, whether or not the game is holding 60fps.

---

### `Run()`

Starts the shared clock. Calling it while already running is a no-op, so it can never stack two connections.

```luau
PerfectSequencer.Run()
print(PerfectSequencer.IsRunning()) -- true
```

The scheduler disconnects itself as soon as the queue empties, then fires [`Completed`](#completed). No idle loop runs in the background between bursts of work.

---

### `Stop()`

Stops the clock early and fires `Completed`. Pending events stay queued rather than being discarded.

```luau
PerfectSequencer.Stop()
```

Note that `Run` resets the clock to zero, so a stopped and restarted scheduler replays each pending event's full delay rather than continuing from where it left off. To discard the queue instead of keeping it, call [`Reset()`](#reset).

---

### `Reset()`

Clears every queued event without stopping the clock.

```luau
PerfectSequencer.Reset()
```

---

### `IsRunning()`

Returns whether the shared clock is currently connected.

```luau
if not PerfectSequencer.IsRunning() then
	PerfectSequencer.Run()
end
```

---

### `GetPendingCount()`

Returns how many events are still queued.

```luau
print(`{PerfectSequencer.GetPendingCount()} events pending`)
```

---

### `Completed`

A signal fired when the queue drains and the clock stops.

```luau
PerfectSequencer.Completed:Connect(function()
	print("every queued event has fired")
end)
```

---

### `ForTrack(Track)`

Returns a `TrackSequencer` locked to an `AnimationTrack`'s timeline. Unlike the shared scheduler, it reads `Track.TimePosition`, so it follows the animation through speed changes and stops when the track does.

```luau
local Sequence = PerfectSequencer.ForTrack(Track)
```

Each call returns an independent scheduler. One per swing is the intended usage. They are cheap and self-disposing.

---

### `TrackSequencer:At(Frame, Callback, Args?)`

Schedules a callback at a frame on the track's timeline. Returns the sequencer, so calls chain.

```luau
Sequence
	:At(8, PlayWindupSound)
	:At(20, ApplyDamage, { Target })
```

Order does not matter. Events are matched against the timeline every frame, not consumed in the order they were added.

> [!NOTE]
> Calling `:At` after the sequencer has finished logs a warning and is ignored, rather than silently doing nothing. A frame that never fires is a bug worth seeing.

---

### `TrackSequencer:Start()`

Begins watching the track. Returns the sequencer, so it chains off `:At`.

```luau
Sequence:Start()
Track:Play()
```

`Start` may legitimately run a frame before `Track:Play()`, so it waits for the track to actually begin rather than assuming it is already playing. If the track never plays within one second, the sequencer cancels itself instead of leaking a connection.

---

### `TrackSequencer:Cancel()`

Stops the sequencer, drops pending events, and fires `Finished(false)`.

```luau
Sequence:Cancel()
```

Cancelling is idempotent. Calling it twice does nothing the second time, and it is called automatically when the track stops or when every event has fired.

---

### `TrackSequencer.Finished`

A signal fired exactly once, with `true` if every event ran and `false` if the sequencer was cancelled with events still pending.

```luau
Sequence.Finished:Connect(function(RanToCompletion: boolean)
	if not RanToCompletion then
		Character:SetAttribute("Attacking", false)
	end
end)
```

This is the hook for cleanup that must happen whether a swing lands or is interrupted.

## Choosing a scheduler

| | `AddEvent` / `Run` | `ForTrack` |
| --- | --- | --- |
| Clock source | real `DeltaTime` | `Track.TimePosition` |
| Follows animation speed | no | yes |
| Survives the track stopping | yes | no, dies with it |
| Instances | one shared queue | one per swing |
| Use for | cooldowns, delayed logic, timed sequences | hitboxes, VFX, sounds tied to keyframes |

Rule of thumb: if the timing is written on an animator's timeline, use `ForTrack`. If it is game logic that happens to be delayed, use `AddEvent`.

## How it behaves

**No dependencies.** The package installs with nothing attached. `Signal` and `Cleanup` are internal modules, so nothing else in your project is touched and no version can drift underneath you.

**Callbacks run on pooled threads.** Dispatch goes through an internal signal that caches a runner coroutine, so scheduling an event does not allocate a thread per callback. A handler that yields simply loses the cached thread and the next dispatch creates a new one.

**A failing callback cannot take the scheduler down.** Every callback is wrapped in `pcall`, and errors are logged rather than swallowed.

**Connections are owned by a cleanup object.** Both schedulers hand their connections to an internal `Cleanup`, so there is no separate disconnect path to forget. It swaps its task list out before running, so a task added during cleanup is not cleaned by that pass and re-entrant calls cannot double-clean.

**Tracing is on in Studio, off in a live game.** Gated on `RunService:IsStudio()`, so a track that never plays is reported while you are developing and stays quiet in production.

## Contributing

```bash
aftman install
wally install

stylua --check src/
selene src/

rojo sourcemap dev.project.json -o sourcemap.json
luau-lsp analyze --platform=roblox --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src/
```

CI runs all four on every push. `globalTypes.d.luau` is fetched by the workflow and is not committed.
