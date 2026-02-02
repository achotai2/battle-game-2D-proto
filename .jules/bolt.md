## 2024-05-22 - [AnimatedSprite2D Loop Signal Trap]
**Learning:** `AnimatedSprite2D.animation_finished` signal is emitted for looping animations in Godot 4. Relying on it to reset state to "idle" causes state thrashing if the agent is actually moving, and prevents optimizations that skip per-frame animation updates.
**Action:** When handling `animation_finished`, always check the agent's current intent/velocity before defaulting to an idle state. Implement a `refresh_animation_state()` helper to handle this transition cleanly.

## 2024-05-23 - [Minion Pathfinding Math]
**Learning:** `MinionPathfinding.tick()` runs every physics frame for every unit. Using `distance_to()` (sqrt) for stuck detection and arrival checks accumulates significant overhead.
**Action:** Always prefer `distance_squared_to()` for threshold checks. Only compute `sqrt` if the value is needed for linear scaling (e.g. arrival slowing) and the unit is actually within range.

## 2024-05-24 - [Target Selection Redundancy]
**Learning:** `AgentTracking._reselect_target` typically uses an O(N) loop where `_is_better(candidate, best)` re-calculates the metric (e.g., distance) for the *current best* candidate on every comparison. This results in redundant Vector math and property access.
**Action:** Cache the "score" (e.g., distance squared) of the current best candidate in the selection loop. For the common "Nearest" case, implement a fast path that avoids the `_is_better` function call overhead entirely.
