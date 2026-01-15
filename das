[1mdiff --git a/Scripts/InteractPrompt.gd b/Scripts/InteractPrompt.gd[m
[1mnew file mode 100644[m
[1mindex 0000000..dfe713e[m
[1m--- /dev/null[m
[1m+++ b/Scripts/InteractPrompt.gd[m
[36m@@ -0,0 +1,21 @@[m
[32m+[m[32mextends Node2D[m
[32m+[m[32mclass_name InteractPrompt[m
[32m+[m
[32m+[m[32m@export_range(0.0, 64.0, 0.5) var bob_height: float = 6.0[m
[32m+[m[32m@export_range(0.0, 10.0, 0.1) var bob_speed: float = 2.0[m
[32m+[m
[32m+[m[32mvar _base_position: Vector2[m
[32m+[m[32mvar _time: float = 0.0[m
[32m+[m
[32m+[m
[32m+[m[32mfunc _ready() -> void:[m
[32m+[m	[32m_base_position = global_position[m
[32m+[m
[32m+[m
[32m+[m[32mfunc _process(delta: float) -> void:[m
[32m+[m	[32m_time += delta[m
[32m+[m	[32mglobal_position = _base_position + Vector2(0, sin(_time * bob_speed) * bob_height)[m
[32m+[m
[32m+[m
[32m+[m[32mfunc set_base_position(position: Vector2) -> void:[m
[32m+[m	[32m_base_position = position[m
[1mdiff --git a/Scripts/Interactable.gd b/Scripts/Interactable.gd[m
[1mnew file mode 100644[m
[1mindex 0000000..deaaba0[m
[1m--- /dev/null[m
[1m+++ b/Scripts/Interactable.gd[m
[36m@@ -0,0 +1,81 @@[m
[32m+[m[32mextends Area2D[m
[32m+[m[32mclass_name Interactable[m
[32m+[m
[32m+[m[32msignal interaction_started(interactor: Node2D)[m
[32m+[m[32msignal interaction_finished(interactor: Node2D)[m
[32m+[m
[32m+[m[32m@export var interaction_time: float = 0.0[m
[32m+[m[32m@export var one_shot: bool = false[m
[32m+[m[32m@export var requires_same_team: bool = false[m
[32m+[m[32m@export var allows_neutral: bool = true[m
[32m+[m[32m@export var priority: int = 0[m
[32m+[m[32m@export var icon_type: StringName = &""[m
[32m+[m[32m@export var prompt_anchor: Node2D[m
[32m+[m
[32m+[m[32mvar _disabled: bool = false[m
[32m+[m[32mvar _active_interactor: Node2D = null[m
[32m+[m
[32m+[m
[32m+[m[32mfunc can_interact(interactor: Node2D) -> bool:[m
[32m+[m	[32mif _disabled:[m
[32m+[m		[32mreturn false[m
[32m+[m	[32mif _active_interactor != null and _active_interactor != interactor:[m
[32m+[m		[32mreturn false[m
[32m+[m
[32m+[m	[32mvar interactor_team := _get_team_id(interactor)[m
[32m+[m	[32mif not allows_neutral and interactor_team == 0:[m
[32m+[m		[32mreturn false[m
[32m+[m
[32m+[m	[32mif requires_same_team:[m
[32m+[m		[32mvar owner_team := _get_team_id(get_parent())[m
[32m+[m		[32mif interactor_team != owner_team:[m
[32m+[m			[32mreturn false[m
[32m+[m
[32m+[m	[32mreturn true[m
[32m+[m
[32m+[m
[32m+[m[32mfunc begin_interact(interactor: Node2D) -> void:[m
[32m+[m	[32mif _active_interactor != null:[m
[32m+[m		[32mreturn[m
[32m+[m	[32mif not can_interact(interactor):[m
[32m+[m		[32mreturn[m
[32m+[m
[32m+[m	[32m_active_interactor = interactor[m
[32m+[m	[32minteraction_started.emit(interactor)[m
[32m+[m
[32m+[m
[32m+[m[32mfunc finish_interact(interactor: Node2D) -> void:[m
[32m+[m	[32mif _active_interactor != interactor:[m
[32m+[m		[32mreturn[m
[32m+[m
[32m+[m	[32m_active_interactor = null[m
[32m+[m	[32mif one_shot:[m
[32m+[m		[32m_disable_interaction()[m
[32m+[m	[32minteraction_finished.emit(interactor)[m
[32m+[m
[32m+[m
[32m+[m[32mfunc get_interaction_time() -> float:[m
[32m+[m	[32mreturn interaction_time[m
[32m+[m
[32m+[m
[32m+[m[32mfunc get_prompt_position() -> Vector2:[m
[32m+[m	[32mvar anchor := prompt_anchor[m
[32m+[m	[32mif anchor == null:[m
[32m+[m		[32manchor = get_node_or_null("PromptAnchor") as Node2D[m
[32m+[m	[32mif is_instance_valid(anchor):[m
[32m+[m		[32mreturn anchor.global_position[m
[32m+[m	[32mif get_parent() is Node2D:[m
[32m+[m		[32mreturn (get_parent() as Node2D).global_position[m
[32m+[m	[32mreturn global_position[m
[32m+[m
[32m+[m
[32m+[m[32mfunc _get_team_id(entity: Node) -> int:[m
[32m+[m	[32mif entity is AgentBase:[m
[32m+[m		[32mreturn (entity as AgentBase).player[m
[32m+[m	[32mreturn 0[m
[32m+[m
[32m+[m
[32m+[m[32mfunc _disable_interaction() -> void:[m
[32m+[m	[32m_disabled = true[m
[32m+[m	[32mset_deferred("monitoring", false)[m
[32m+[m	[32mset_deferred("monitorable", false)[m
[1mdiff --git a/Scripts/PlayerInteractor.gd b/Scripts/PlayerInteractor.gd[m
[1mnew file mode 100644[m
[1mindex 0000000..da43f76[m
[1m--- /dev/null[m
[1m+++ b/Scripts/PlayerInteractor.gd[m
[36m@@ -0,0 +1,219 @@[m
[32m+[m[32mextends Node2D[m
[32m+[m[32mclass_name PlayerInteractor[m
[32m+[m
[32m+[m[32msignal target_changed(target: Interactable)[m
[32m+[m[32msignal interaction_started(target: Interactable)[m
[32m+[m[32msignal interaction_finished(target: Interactable)[m
[32m+[m
[32m+[m[32m@export var sensor: Area2D[m
[32m+[m[32m@export var prompt_scene: PackedScene[m
[32m+[m[32m@export var prompt_parent: Node[m
[32m+[m[32m@export var movement: AgentMovement[m
[32m+[m[32m@export var animation: AgentAnimate[m
[32m+[m[32m@export var interact_action: StringName = &"interact"[m
[32m+[m[32m@export var freeze_movement: bool = true[m
[32m+[m[32m@export var use_interactable_timing: bool = false[m
[32m+[m
[32m+[m[32mvar _nearby: Array[Interactable] = [][m
[32m+[m[32mvar _current_target: Interactable = null[m
[32m+[m[32mvar _prompt: Node2D = null[m
[32m+[m[32mvar _interaction_timer: Timer[m
[32m+[m[32mvar _is_interacting: bool = false[m
[32m+[m
[32m+[m
[32m+[m[32mfunc _ready() -> void:[m
[32m+[m	[32m_interaction_timer = Timer.new()[m
[32m+[m	[32m_interaction_timer.one_shot = true[m
[32m+[m	[32m_interaction_timer.timeout.connect(_on_interaction_timeout)[m
[32m+[m	[32madd_child(_interaction_timer)[m
[32m+[m
[32m+[m	[32mif sensor == null:[m
[32m+[m		[32msensor = get_node_or_null("Sensor") as Area2D[m
[32m+[m	[32mif sensor == null:[m
[32m+[m		[32msensor = get_node_or_null("Area2D") as Area2D[m
[32m+[m
[32m+[m	[32mif is_instance_valid(sensor):[m
[32m+[m		[32msensor.area_entered.connect(_on_area_entered)[m
[32m+[m		[32msensor.area_exited.connect(_on_area_exited)[m
[32m+[m
[32m+[m	[32m_setup_prompt()[m
[32m+[m
[32m+[m
[32m+[m[32mfunc _process(_delta: float) -> void:[m
[32m+[m	[32mif _is_interacting:[m
[32m+[m		[32m_update_prompt()[m
[32m+[m		[32mreturn[m
[32m+[m
[32m+[m	[32mvar best := _select_best_target()[m
[32m+[m	[32mif best != _current_target:[m
[32m+[m		[32m_set_target(best)[m
[32m+[m	[32m_update_prompt()[m
[32m+[m
[32m+[m
[32m+[m[32mfunc _unhandled_input(event: InputEvent) -> void:[m
[32m+[m	[32mif event.is_action_pressed(interact_action):[m
[32m+[m		[32m_try_start_interaction()[m
[32m+[m
[32m+[m
[32m+[m[32mfunc _setup_prompt() -> void:[m
[32m+[m	[32mif prompt_scene == null:[m
[32m+[m		[32mreturn[m
[32m+[m
[32m+[m	[32m_prompt = prompt_scene.instantiate() as Node2D[m
[32m+[m	[32mif _prompt == null:[m
[32m+[m		[32mreturn[m
[32m+[m
[32m+[m	[32mif prompt_parent != null:[m
[32m+[m		[32mprompt_parent.add_child(_prompt)[m
[32m+[m	[32melse:[m
[32m+[m		[32madd_child(_prompt)[m
[32m+[m	[32m_prompt.hide()[m
[32m+[m
[32m+[m
[32m+[m[32mfunc _select_best_target() -> Interactable:[m
[32m+[m	[32mif _nearby.is_empty():[m
[32m+[m		[32mreturn null[m
[32m+[m
[32m+[m	[32mvar owner_node := _get_interactor_node()[m
[32m+[m	[32mif owner_node == null:[m
[32m+[m		[32mreturn null[m
[32m+[m
[32m+[m	[32mvar best: Interactable = null[m
[32m+[m	[32mvar best_priority := -999999[m
[32m+[m	[32mvar best_dist := INF[m
[32m+[m
[32m+[m	[32mfor candidate in _nearby:[m
[32m+[m		[32mif not is_instance_valid(candidate):[m
[32m+[m			[32mcontinue[m
[32m+[m		[32mif not candidate.can_interact(owner_node):[m
[32m+[m			[32mcontinue[m
[32m+[m		[32mvar priority := candidate.priority[m
[32m+[m		[32mvar dist := owner_node.global_position.distance_squared_to(candidate.global_position)[m
[32m+[m		[32mif priority > best_priority or (priority == best_priority and dist < best_dist):[m
[32m+[m			[32mbest = candidate[m
[32m+[m			[32mbest_priority = priority[m
[32m+[m			[32mbest_dist = dist[m
[32m+[m
[32m+[m	[32mreturn best[m
[32m+[m
[32m+[m
[32m+[m[32mfunc _set_target(target: Interactable) -> void:[m
[32m+[m	[32m_current_target = target[m
[32m+[m	[32mif _current_target == null:[m
[32m+[m		[32m_hide_prompt()[m
[32m+[m	[32melse:[m
[32m+[m		[32m_show_prompt()[m
[32m+[m	[32mtarget_changed.emit(_current_target)[m
[32m+[m
[32m+[m
[32m+[m[32mfunc _update_prompt() -> void:[m
[32m+[m	[32mif _prompt == null:[m
[32m+[m		[32mreturn[m
[32m+[m	[32mif _current_target == null or not is_instance_valid(_current_target):[m
[32m+[m		[32m_hide_prompt()[m
[32m+[m		[32mreturn[m
[32m+[m
[32m+[m	[32mvar anchor_position := _current_target.get_prompt_position()[m
[32m+[m	[32mif _prompt.has_method("set_base_position"):[m
[32m+[m		[32m_prompt.call("set_base_position", anchor_position)[m
[32m+[m	[32melse:[m
[32m+[m		[32m_prompt.global_position = anchor_position[m
[32m+[m	[32m_show_prompt()[m
[32m+[m
[32m+[m
[32m+[m[32mfunc _show_prompt() -> void:[m
[32m+[m	[32mif _prompt == null:[m
[32m+[m		[32mreturn[m
[32m+[m	[32m_prompt.show()[m
[32m+[m
[32m+[m
[32m+[m[32mfunc _hide_prompt() -> void:[m
[32m+[m	[32mif _prompt == null:[m
[32m+[m		[32mreturn[m
[32m+[m	[32m_prompt.hide()[m
[32m+[m
[32m+[m
[32m+[m[32mfunc _try_start_interaction() -> void:[m
[32m+[m	[32mif _is_interacting:[m
[32m+[m		[32mreturn[m
[32m+[m	[32mif _current_target == null or not is_instance_valid(_current_target):[m
[32m+[m		[32mreturn[m
[32m+[m
[32m+[m	[32mvar owner_node := _get_interactor_node()[m
[32m+[m	[32mif owner_node == null:[m
[32m+[m		[32mreturn[m
[32m+[m	[32mif not _current_target.can_interact(owner_node):[m
[32m+[m		[32mreturn[m
[32m+[m
[32m+[m	[32m_is_interacting = true[m
[32m+[m	[32mif freeze_movement and is_instance_valid(movement):[m
[32m+[m		[32mmovement.freeze(owner_node)[m
[32m+[m
[32m+[m	[32m_current_target.begin_interact(owner_node)[m
[32m+[m	[32minteraction_started.emit(_current_target)[m
[32m+[m
[32m+[m	[32mif use_interactable_timing:[m
[32m+[m		[32m_current_target.interaction_finished.connect(_on_target_finished, CONNECT_ONE_SHOT)[m
[32m+[m	[32melse:[m
[32m+[m		[32mvar duration := _current_target.get_interaction_time()[m
[32m+[m		[32mif duration <= 0.0:[m
[32m+[m			[32m_finish_interaction()[m
[32m+[m		[32melse:[m
[32m+[m			[32m_interaction_timer.start(duration)[m
[32m+[m
[32m+[m
[32m+[m[32mfunc _finish_interaction() -> void:[m
[32m+[m	[32mif not _is_interacting:[m
[32m+[m		[32mreturn[m
[32m+[m	[32m_is_interacting = false[m
[32m+[m
[32m+[m	[32mvar owner_node := _get_interactor_node()[m
[32m+[m	[32mif freeze_movement and is_instance_valid(movement):[m
[32m+[m		[32mmovement.un_freeze()[m
[32m+[m
[32m+[m	[32mif _current_target != null and is_instance_valid(_current_target) and owner_node != null:[m
[32m+[m		[32m_current_target.finish_interact(owner_node)[m
[32m+[m	[32minteraction_finished.emit(_current_target)[m
[32m+[m
[32m+[m
[32m+[m[32mfunc _finalize_interaction() -> void:[m
[32m+[m	[32mif not _is_interacting:[m
[32m+[m		[32mreturn[m
[32m+[m	[32m_is_interacting = false[m
[32m+[m
[32m+[m	[32mif freeze_movement and is_instance_valid(movement):[m
[32m+[m		[32mmovement.un_freeze()[m
[32m+[m	[32minteraction_finished.emit(_current_target)[m
[32m+[m
[32m+[m
[32m+[m[32mfunc _on_interaction_timeout() -> void:[m
[32m+[m	[32m_finish_interaction()[m
[32m+[m
[32m+[m
[32m+[m[32mfunc _on_target_finished(_interactor: Node2D) -> void:[m
[32m+[m	[32m_finalize_interaction()[m
[32m+[m
[32m+[m
[32m+[m[32mfunc _on_area_entered(area: Area2D) -> void:[m
[32m+[m	[32mif area is Interactable:[m
[32m+[m		[32mvar interactable := area as Interactable[m
[32m+[m		[32mif not _nearby.has(interactable):[m
[32m+[m			[32m_nearby.append(interactable)[m
[32m+[m
[32m+[m
[32m+[m[32mfunc _on_area_exited(area: Area2D) -> void:[m
[32m+[m	[32mif area is Interactable:[m
[32m+[m		[32mvar interactable := area as Interactable[m
[32m+[m		[32m_nearby.erase(interactable)[m
[32m+[m
[32m+[m	[32mif _is_interacting:[m
[32m+[m		[32mreturn[m
[32m+[m
[32m+[m	[32mif _current_target == area:[m
[32m+[m		[32m_set_target(_select_best_target())[m
[32m+[m
[32m+[m
[32m+[m[32mfunc _get_interactor_node() -> Node2D:[m
[32m+[m	[32mif get_parent() is Node2D:[m
[32m+[m		[32mreturn get_parent() as Node2D[m
[32m+[m	[32mreturn self[m
[1mdiff --git a/project.godot b/project.godot[m
[1mindex 02797ba..68d01bc 100644[m
[1m--- a/project.godot[m
[1m+++ b/project.godot[m
[36m@@ -70,6 +70,11 @@[m [mbuild={[m
 "events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":32,"location":0,"echo":false,"script":null)[m
 ][m
 }[m
[32m+[m[32minteract={[m
[32m+[m[32m"deadzone": 0.2,[m
[32m+[m[32m"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":69,"key_label":0,"unicode":101,"location":0,"echo":false,"script":null)[m
[32m+[m[32m][m
[32m+[m[32m}[m
 click={[m
 "deadzone": 0.2,[m
 "events": [Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":1,"canceled":false,"pressed":false,"double_click":false,"script":null)[m
