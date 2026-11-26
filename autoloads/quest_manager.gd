extends Node
## Full RPG Quest State Machine managing Main Quests, Side Quests, live step counters,
## rewards, completion history, and guaranteed live Golden Compass target resolution.

signal quest_started(quest_id: String)
signal quest_updated(quest_id: String)
signal quest_completed(quest_id: String)
signal toast_requested(title: String, subtitle: String, color: Color)
signal objective_changed(target_pos: Vector3, target_name: String)

var quests: Dictionary = {}
var active_main_quest_id: String = ""
var active_side_quest_id: String = ""
var completed_quest_ids: Array[String] = []
var active_stage: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func reset_all_quests() -> void:
	quests.clear()
	completed_quest_ids.clear()
	active_main_quest_id = ""
	active_side_quest_id = ""


func reset_stage_quests(stage_num: int) -> void:
	var to_remove: Array[String] = []
	for qid_var in quests.keys():
		var qid: String = String(qid_var)
		var q: Dictionary = quests[qid]
		if int(q.get("stage", 0)) == stage_num:
			to_remove.append(qid)
	for qid in to_remove:
		quests.erase(qid)
		completed_quest_ids.erase(qid)
	setup_stage_quests(stage_num)


func setup_stage_quests(stage_num: int) -> void:
	active_stage = clampi(stage_num, 1, 4)
	active_main_quest_id = ""
	active_side_quest_id = ""

	match active_stage:
		1:
			_register_quest({
				"id": "s1_main",
				"stage": 1,
				"type": "main",
				"title": "Awaken the Golden Path",
				"description": "Speak with Elder Sylvan by the trailhead campfire, gather the Sunlit Shards, clear the corrupted Moss Stalkers, ignite the Ancient Wayshrine, and enter the Grove Portal.",
				"reward_text": "Unseals the Grove Portal to Thornhollow (+250 Score)",
				"steps": [
					{"key": "talk_sylvan", "label": "Speak with Elder Sylvan at the Campfire", "current": 0, "target": 1, "group": "npc_quest", "target_name": "Elder Sylvan"},
					{"key": "collect_shards", "label": "Collect Sunlit Shards in Whispering Woods", "current": 0, "target": 5, "group": "shard", "target_name": "Sunlit Shard"},
					{"key": "defeat_stalkers", "label": "Clear Corrupted Moss Stalkers", "current": 0, "target": 3, "group": "enemy_quest", "target_name": "Moss Stalker"},
					{"key": "ignite_wayshrine_1", "label": "Awaken the Ancient Wayshrine", "current": 0, "target": 1, "group": "wayshrine", "target_name": "Ancient Wayshrine"},
					{"key": "enter_portal_1", "label": "Enter the Unsealed Grove Portal", "current": 0, "target": 1, "group": "portal", "target_name": "Grove Portal"},
				],
			})
			_register_quest({
				"id": "s1_side",
				"stage": 1,
				"type": "side",
				"title": "Lost Lantern Relics",
				"description": "Elder Sylvan spoke of three hidden forest treasure chests tucked in side glades off the lantern trail. Use Compass Pulse [G] to reveal their beacons.",
				"reward_text": "+1 Max Vitality, +1 Healing Herb & +250 Score",
				"steps": [
					{"key": "open_chests_1", "label": "Open Hidden Forest Treasure Chests", "current": 0, "target": 3, "group": "chest", "target_name": "Hidden Chest"},
				],
			}, false)
			active_main_quest_id = "s1_main"
		2:
			_register_quest({
				"id": "s2_main",
				"stage": 2,
				"type": "main",
				"title": "Seals of Thornhollow",
				"description": "Meet the Wandering Cartographer, awaken all three Ancient Rune Pillars across the overgrown courtyards, vanquish the Ruin Guardians, ignite the Wayshrine, and unseal the Boss Sanctum.",
				"reward_text": "Unseals the Heart of the Grove Portal (+350 Score)",
				"steps": [
					{"key": "talk_cartographer", "label": "Speak with the Wandering Cartographer", "current": 0, "target": 1, "group": "npc_quest", "target_name": "Wandering Cartographer"},
					{"key": "activate_pillars", "label": "Activate Ancient Rune Pillars", "current": 0, "target": 3, "group": "rune_pillar", "target_name": "Ancient Rune Pillar"},
					{"key": "defeat_ruin_foes", "label": "Defeat Corrupted Ruin Guardians", "current": 0, "target": 4, "group": "enemy_quest", "target_name": "Ruin Guardian"},
					{"key": "ignite_wayshrine_2", "label": "Ignite the Thornhollow Wayshrine", "current": 0, "target": 1, "group": "wayshrine", "target_name": "Thornhollow Wayshrine"},
					{"key": "enter_portal_2", "label": "Enter the Boss Sanctum Portal", "current": 0, "target": 1, "group": "portal", "target_name": "Sanctum Portal"},
				],
			})
			_register_quest({
				"id": "s2_side",
				"stage": 2,
				"type": "side",
				"title": "Cartographer's Lost Notes",
				"description": "Three carved Lore Runestones lie hidden among Thornhollow's mossy arches. Decipher them to strengthen your blade.",
				"reward_text": "+6 Attack Damage & +300 Score",
				"steps": [
					{"key": "read_runestones", "label": "Read Ancient Lore Runestones", "current": 0, "target": 3, "group": "lore_runestone", "target_name": "Lore Runestone"},
				],
			}, false)
			active_main_quest_id = "s2_main"
		3:
			_register_quest({
				"id": "s3_main",
				"stage": 3,
				"type": "main",
				"title": "Heart of the Grove",
				"description": "Consult the Grove Spirit before the sanctum gate, ignite the pre-boss Wayshrine, defeat Vaelthorn the Corrupted Forest Guardian, and enter the Astral Rift.",
				"reward_text": "Opens the Astral Rift Portal (+500 Score)",
				"steps": [
					{"key": "talk_spirit", "label": "Speak with the Grove Spirit & Ignite Wayshrine", "current": 0, "target": 1, "group": "npc_quest", "target_name": "Grove Spirit"},
					{"key": "defeat_vaelthorn", "label": "Defeat Vaelthorn, Forest Guardian", "current": 0, "target": 1, "group": "boss", "target_name": "Vaelthorn (Boss)"},
					{"key": "enter_portal_3", "label": "Step through the Astral Rift Portal", "current": 0, "target": 1, "group": "portal", "target_name": "Astral Rift Portal"},
				],
			})
			active_main_quest_id = "s3_main"
		4:
			_register_quest({
				"id": "s4_main",
				"stage": 4,
				"type": "main",
				"title": "Crown of the Golden Compass",
				"description": "Receive the Compass Awakening from the Astral Weaver, illuminate the two hidden Astral Light Bridges with Compass Pulse [G], and defeat Aurelius, the Astral Sovereign.",
				"reward_text": "Restores the Forest Heart & Completes the Adventure (+1000 Score)",
				"steps": [
					{"key": "talk_weaver", "label": "Speak with the Astral Weaver", "current": 0, "target": 1, "group": "npc_quest", "target_name": "Astral Weaver"},
					{"key": "illuminate_bridges", "label": "Illuminate Hidden Astral Light Bridges [G]", "current": 0, "target": 2, "group": "astral_bridge", "target_name": "Astral Light Bridge"},
					{"key": "defeat_aurelius", "label": "Defeat Aurelius, the Astral Sovereign", "current": 0, "target": 1, "group": "boss", "target_name": "Aurelius (Final Boss)"},
				],
			})
			active_main_quest_id = "s4_main"

	if not active_main_quest_id.is_empty():
		quest_started.emit(active_main_quest_id)
		var mq: Dictionary = quests[active_main_quest_id]
		_emit_toast("MAIN QUEST", String(mq.get("title", "")), Color(1.0, 0.88, 0.42))


func _register_quest(data: Dictionary, auto_active: bool = true) -> void:
	var qid: String = String(data["id"])
	data["active"] = auto_active
	data["completed"] = false
	quests[qid] = data


func activate_side_quest(quest_id: String) -> void:
	if not quests.has(quest_id):
		return
	var q: Dictionary = quests[quest_id]
	if bool(q.get("active", false)) or bool(q.get("completed", false)):
		return
	q["active"] = true
	active_side_quest_id = quest_id
	quest_started.emit(quest_id)
	_emit_toast("SIDE QUEST ACCEPTED", String(q.get("title", "")), Color(0.55, 0.95, 0.88))
	if AudioManager:
		AudioManager.play_sfx("quest_start")


func record_progress(step_key: String, amount: int = 1) -> void:
	var changed_any: bool = false
	for qid_var in quests.keys():
		var qid: String = String(qid_var)
		var q: Dictionary = quests[qid]
		if bool(q.get("completed", false)):
			continue
		# Auto-activate side quest if player discovers chests/runestones before talking to NPC
		if not bool(q.get("active", false)) and String(q.get("type", "")) == "side":
			var steps_check: Array = q.get("steps", [])
			for s_var in steps_check:
				var s_dict: Dictionary = s_var
				if String(s_dict.get("key", "")) == step_key:
					q["active"] = true
					active_side_quest_id = qid
					quest_started.emit(qid)
					_emit_toast("SIDE QUEST DISCOVERED", String(q.get("title", "")), Color(0.55, 0.95, 0.88))
					break

		if not bool(q.get("active", false)):
			continue

		var steps: Array = q.get("steps", [])
		var q_modified: bool = false
		for s_var in steps:
			var step: Dictionary = s_var
			if String(step.get("key", "")) == step_key:
				var cur: int = int(step.get("current", 0))
				var tgt: int = int(step.get("target", 1))
				if cur < tgt:
					cur = mini(cur + amount, tgt)
					step["current"] = cur
					q_modified = true
					changed_any = true
					if cur >= tgt and step_key != "enter_portal_1" and step_key != "enter_portal_2" and step_key != "enter_portal_3":
						_emit_toast("OBJECTIVE COMPLETE", String(step.get("label", "")), Color(0.62, 0.98, 0.72))

		if q_modified:
			quest_updated.emit(qid)
			_check_portal_unlock(qid)
			_check_quest_completion(qid)

	if changed_any:
		var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
		var ppos: Vector3 = player.global_position if player else Vector3.ZERO
		var info: Dictionary = get_active_compass_target(ppos)
		objective_changed.emit(info.get("position", Vector3.ZERO), String(info.get("label", "")))


func _check_portal_unlock(qid: String) -> void:
	if not quests.has(qid):
		return
	var q: Dictionary = quests[qid]
	if String(q.get("type", "")) != "main":
		return
	if is_stage_portal_ready(int(q.get("stage", active_stage))):
		for p_var in get_tree().get_nodes_in_group("portal"):
			var portal: Node = p_var
			if portal and is_instance_valid(portal) and portal.has_method("awaken_portal"):
				portal.awaken_portal()


func is_stage_portal_ready(stage_num: int) -> bool:
	var qid: String = "s%d_main" % stage_num
	if not quests.has(qid):
		return true
	var q: Dictionary = quests[qid]
	var steps: Array = q.get("steps", [])
	for s_var in steps:
		var step: Dictionary = s_var
		var k: String = String(step.get("key", ""))
		if k.begins_with("enter_portal"):
			continue
		if int(step.get("current", 0)) < int(step.get("target", 1)):
			return false
	return true


func _check_quest_completion(qid: String) -> void:
	var q: Dictionary = quests[qid]
	if bool(q.get("completed", false)):
		return
	var steps: Array = q.get("steps", [])
	for s_var in steps:
		var step: Dictionary = s_var
		if int(step.get("current", 0)) < int(step.get("target", 1)):
			return

	q["completed"] = true
	if not (qid in completed_quest_ids):
		completed_quest_ids.append(qid)
	quest_completed.emit(qid)
	if AudioManager:
		AudioManager.play_sfx("quest_complete")

	match qid:
		"s1_side":
			GameManager.upgrade_max_vitality(1)
			GameManager.add_herbs(1)
			GameManager.add_score(250)
			_emit_toast("UPGRADE UNLOCKED", "Lost Lantern Relics: +1 Max Vitality & +1 Herb!", Color(1.0, 0.86, 0.36))
		"s2_side":
			GameManager.upgrade_attack_damage(6)
			GameManager.add_score(300)
			_emit_toast("UPGRADE UNLOCKED", "Cartographer's Notes: +6 Attack Power!", Color(1.0, 0.86, 0.36))
		"s1_main":
			GameManager.add_score(250)
			_emit_toast("QUEST COMPLETED", String(q.get("title", "")), Color(1.0, 0.9, 0.45))
		"s2_main":
			GameManager.add_score(350)
			_emit_toast("QUEST COMPLETED", String(q.get("title", "")), Color(1.0, 0.9, 0.45))
		"s3_main":
			GameManager.add_score(500)
			_emit_toast("QUEST COMPLETED", String(q.get("title", "")), Color(1.0, 0.9, 0.45))
		"s4_main":
			GameManager.add_score(1000)
			_emit_toast("FOREST HEART RESTORED", "Crown of the Golden Compass Completed!", Color(1.0, 0.92, 0.48))


func _emit_toast(title: String, subtitle: String, color: Color) -> void:
	toast_requested.emit(title, subtitle, color)
	GameManager.post_toast(title, subtitle, color)


func get_active_main_quest() -> Dictionary:
	if not active_main_quest_id.is_empty() and quests.has(active_main_quest_id):
		return quests[active_main_quest_id]
	return {}


func get_active_side_quest() -> Dictionary:
	if not active_side_quest_id.is_empty() and quests.has(active_side_quest_id):
		return quests[active_side_quest_id]
	return {}


func get_all_completed_quests() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for qid in completed_quest_ids:
		if quests.has(qid):
			out.append(quests[qid])
	return out


func get_active_compass_target(player_pos: Vector3) -> Dictionary:
	## ALWAYS returns a valid 3D position + label for the Golden Compass HUD (never "--m").
	var mq: Dictionary = get_active_main_quest()
	if not mq.is_empty():
		var steps: Array = mq.get("steps", [])
		for s_var in steps:
			var step: Dictionary = s_var
			if int(step.get("current", 0)) < int(step.get("target", 1)):
				var grp: String = String(step.get("group", ""))
				var lbl: String = String(step.get("target_name", "Objective"))
				var found: Node3D = _find_nearest_active_in_group(grp, player_pos)
				if found:
					var custom_lbl: String = String(found.get("compass_label")) if ("compass_label" in found) else lbl
					return {"valid": true, "position": found.global_position, "label": custom_lbl, "group": grp}

	# Fallback scan across all known world landmark groups so compass NEVER fails
	for fallback_cfg in [
		["boss", "Stage Boss"],
		["portal", "Stage Portal"],
		["wayshrine", "Ancient Wayshrine"],
		["npc_quest", "Guide NPC"],
		["shard", "Sunlit Shard"],
		["chest", "Treasure Chest"],
	]:
		var grp_f: String = String(fallback_cfg[0])
		var lbl_f: String = String(fallback_cfg[1])
		var node_f: Node3D = _find_nearest_active_in_group(grp_f, player_pos)
		if node_f:
			var c_lbl: String = String(node_f.get("compass_label")) if ("compass_label" in node_f) else lbl_f
			return {"valid": true, "position": node_f.global_position, "label": c_lbl, "group": grp_f}

	return {"valid": true, "position": player_pos + Vector3(0.0, 0.0, -55.0), "label": "Northern Trail", "group": "fallback"}


func _find_nearest_active_in_group(group_name: String, from_pos: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d: float = 1e12
	for n_var in get_tree().get_nodes_in_group(group_name):
		var n: Node3D = n_var as Node3D
		if not n or not is_instance_valid(n) or not n.is_inside_tree():
			continue
		if n.has_method("is_compass_eligible") and not bool(n.is_compass_eligible()):
			continue
		if n.has_method("is_activated") and bool(n.is_activated()):
			continue
		if "is_defeated" in n and bool(n.get("is_defeated")):
			continue
		if "is_opened" in n and bool(n.get("is_opened")):
			continue
		if "is_collected" in n and bool(n.get("is_collected")):
			continue
		var d: float = from_pos.distance_squared_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best
