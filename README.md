# PerfectSequencer

Frame-accurate event scheduling for Roblox.

Two schedulers, deliberately different:

- **`AddEvent` / `Run`**: one shared wall-clock scheduler. Delays are measured in 60fps frames but tick against real `DeltaTime`, so they hold under frame drops.
- **`ForTrack`**: a per-swing scheduler locked to an `AnimationTrack`'s own timeline. It reads `TimePosition`, so it follows the animation through speed changes, and it dies with the track.

## Installation

```toml
[dependencies]
PerfectSequencer = "skatingii/perfect-sequencer@0.1.0"
```

Then `wally install`. The package lands at `Packages/PerfectSequencer`.

### With Rojo

`wally install` writes `Packages/`; point your project at it and sync:

```json
{
  "tree": {
    "ReplicatedStorage": {
      "Packages": { "$path": "Packages" }
    }
  }
}
```

### Without Rojo (Studio Script Sync)

Build the package to a model file and drag it into Studio:

```bash
rojo build default.project.json -o PerfectSequencer.rbxm
```

`sleitnick/signal` must sit beside it, since the package resolves its dependency as a runtime sibling.

### Before it is published

Until the package is on the registry, wally cannot install it: wally 0.3.2 supports neither path nor git dependencies. To use it anyway, build the tree wally would have produced and copy it in:

```bash
wally install
bash scripts/build-package-tree.sh
```

That writes `dist/Packages`, containing the `_Index` layout, the generated link files, and every dependency. Copy `dist/Packages` into your project's `ReplicatedStorage`.

Note that `devsparkle/maid` ships its source under `src/` with its own `default.project.json`, so Rojo turns it into a ModuleScript but a plain file copy does not. Under Studio Script Sync, build the tree to a model first:

```bash
rojo build verify.project.json -o Packages.rbxm
``` When the package is later published, `wally install` produces the same paths, so nothing has to move.

## Shared scheduler

```lua
const PerfectSequencer = require(ReplicatedStorage.Packages.PerfectSequencer)

PerfectSequencer.AddEvent({
	PresetFrame = 12,
	Callback = function(Character)
		ApplyHitbox(Character)
	end,
	Args = { Character },
})

PerfectSequencer.Run()
```

`Run` connects to `PostSimulation` and disconnects itself once the queue empties, then fires `PerfectSequencer.Completed`. Calling `Run` while already running is a no-op, so it never stacks connections.

An event queued *mid-run* counts its delay from the moment it was added, not from the run's start.

### API

| Member | Description |
| --- | --- |
| `AddEvent(Event)` | Queue `{ PresetFrame, Callback, Args? }`. Binary-inserted, so no re-sort. |
| `Run()` | Start the shared clock. No-op if already running. |
| `Reset()` | Clear the queue without stopping. |
| `IsRunning(): boolean` | Whether the clock is connected. |
| `GetPendingCount(): number` | Events still queued. |
| `Completed` | `Signal` fired when the queue drains and the clock stops. |

## Track-locked scheduler

```lua
const Sequence = PerfectSequencer.ForTrack(Track)

Sequence:At(8, function()
	PlaySound("Windup")
end)

Sequence:At(20, function()
	ApplyDamage()
end)

Sequence.Finished:Connect(function(RanToCompletion)
	if not RanToCompletion then
		CleanUpEarly()
	end
end)

Sequence:Start()
Track:Play()
```

`Start()` may run a frame before `Track:Play()`, so it waits for the track to actually begin. If the track never plays within `NeverPlayedTimeout` (1s), the sequencer cancels itself rather than leaking a `PostSimulation` connection.

`Finished` fires exactly once, with `true` if every event ran and `false` if it was cancelled with events still pending.

| Member | Description |
| --- | --- |
| `:At(Frame, Callback, Args?)` | Schedule against the track's timeline. Chainable. |
| `:Start()` | Begin watching the track. Chainable. |
| `:Cancel()` | Stop, drop pending events, fire `Finished(false)`. |
| `.Finished` | `Signal(RanToCompletion: boolean)`. |

## Notes

Callbacks run on pooled threads borrowed from [`sleitnick/signal`](https://sleitnick.github.io/RbxUtil/api/Signal/), and are wrapped in `pcall`. A callback that errors is logged and cannot take the scheduler down with it.

Tracing is on in Studio and off in a live game, gated on `RunService:IsStudio()`.

## Development

```bash
aftman install
wally install
stylua --check src/
selene src/
```
