## 2024-05-22 - [AnimatedSprite2D Loop Signal Trap]
**Learning:** `AnimatedSprite2D.animation_finished` signal is emitted for looping animations in Godot 4. Relying on it to reset state to "idle" causes state thrashing if the agent is actually moving, and prevents optimizations that skip per-frame animation updates.
**Action:** When handling `animation_finished`, always check the agent's current intent/velocity before defaulting to an idle state. Implement a `refresh_animation_state()` helper to handle this transition cleanly.
