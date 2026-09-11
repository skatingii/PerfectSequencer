# Changelog

## 0.1.0

First release.

### Added

- `AddEvent` and `Run`, a shared scheduler whose delays are measured in 60fps frames but ticked against real `DeltaTime`. Events are inserted with a binary search and the drain loop stops at the first event that is not due.
- `ForTrack`, a per-swing scheduler locked to an `AnimationTrack`'s own timeline. It follows the animation through speed changes, waits for the track to actually begin rather than assuming `Start` runs after `Play`, and cancels itself if the track never plays.
- `Completed` and `Finished` signals for queue drain and per-swing completion. `Finished` reports whether the sequencer ran to completion or was cancelled with events pending.
- `Stop`, `Reset`, `IsRunning` and `GetPendingCount` on the shared scheduler.

### Notes

- No dependencies. `Signal` and `Cleanup` are internal.
- Callbacks run on a reused runner coroutine and are wrapped in `pcall`, so a failing callback cannot stop the scheduler.
- Tracing is gated on `RunService:IsStudio()`.
- 29 tests run on every push via Lute, covering the queue, signal and cleanup logic. `TrackSequencer` and the entry point touch `RunService` and `AnimationTrack`, so they are not covered outside Roblox.
