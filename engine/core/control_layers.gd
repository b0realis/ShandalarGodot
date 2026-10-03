extends RefCounted
## Timestamp-ordered control effects, separate from ownership. Durations
## expire even while a newer effect overrides them (CR 611.2, 613.1b).
## All storage belongs to the game so held choices/search can rewind it.

static func add(g: MtgGame, victim: CardInstance, pid: int, kind := "permanent",
		source: CardInstance = null, tapped := false, power_cap := false,
		control_bound := true) -> void:
	# CR 702.26e: a control change made while the permanent is phased out
	# never includes it — not even once it has phased back in.
	if not g.is_present(victim): return
	if victim.controller_id != pid and victim.cur_cant_change_control: return
	g._rec(g, &"_control_layers")
	var row: Dictionary = g._control_layers.get(victim.id, {})
	if row.is_empty() or int(row.stamp) != victim.layer_timestamp:
		row = {"stamp": victim.layer_timestamp, "base": victim.controller_id, "effects": []}
	var effect := {"pid": pid, "kind": kind, "turn": g.turn_number}
	if source != null:
		effect.merge({"source": source.id, "stamp": source.layer_timestamp,
			"control": source.control_sequence, "untap": source.untap_sequence,
			"tapped": tapped, "power": power_cap, "control_bound": control_bound})
	row.effects.append(effect)
	g._control_layers[victim.id] = row

static func _live(g: MtgGame, victim: CardInstance, e: Dictionary) -> bool:
	if not e.has("source"): return true
	var s := g.find_instance(int(e.source))
	if s == null or s.zone != Mtg.Zone.BATTLEFIELD or s.phased_out or s.layer_timestamp != int(e.stamp): return false
	if e.kind == "aura": return s.attached_to == victim.id
	if bool(e.control_bound) and s.control_sequence != int(e.control): return false
	if bool(e.tapped) and (not s.tapped or s.untap_sequence != int(e.untap)): return false
	# "...and that creature's power remains <= this one's" (Old Man of the
	# Sea) TRACKS THE VICTIM: it ends when the victim phases out (702.26f) —
	# and a broken duration never revives (refresh drops it).
	if bool(e.power) and victim.phased_out: return false
	return not bool(e.power) or victim.cur_power <= s.cur_power

static func refresh(g: MtgGame, cleanup := false) -> bool:
	if g._refreshing_control: return false
	g._refreshing_control = true
	var changed := false
	# A control change can end another duration. A broken duration never
	# revives, so this reaches a fixed point even for mutually held sources.
	var repeat := true
	while repeat:
		repeat = false
		# Auras are continuous effects, including those attached without
		# casting and those moved by Crown of the Ages. Register each new
		# attachment once, after all previously registered control effects.
		for aura in g.all_battlefield():
			if not aura.data.aura_steals or aura.attached_to == -1: continue
			var host := g.find_instance(aura.attached_to)
			if host == null or host.zone != Mtg.Zone.BATTLEFIELD: continue
			var present := false
			for e in g._control_layers.get(host.id, {}).get("effects", []):
				if e.get("kind") == "aura" and e.get("source") == aura.id and e.get("stamp") == aura.layer_timestamp:
					present = true
			if not present: add(g, host, aura.controller_id, "aura", aura)
		for id in g._control_layers.keys():
			var row: Dictionary = g._control_layers[id]
			var victim := g.find_instance(int(id))
			if victim == null or victim.zone != Mtg.Zone.BATTLEFIELD or victim.layer_timestamp != int(row.stamp):
				g._rec(g, &"_control_layers")
				g._control_layers.erase(id)
				continue
			var effects: Array = []
			for e in row.effects:
				if not _live(g, victim, e) or (cleanup and e.kind == "eot"): continue
				effects.append(e)
			if effects.size() != row.effects.size():
				g._rec(g, &"_control_layers")
				row.effects = effects
			var pid := int(row.base)
			var leash := -1
			var tapped := false
			var capped := false
			for e in effects:
				pid = int(e.pid)
				if e.kind == "aura": pid = g.find_instance(int(e.source)).controller_id
				if e.kind == "leash":
					leash = int(e.source)
					tapped = bool(e.tapped)
					capped = bool(e.power)
			for field in [&"controlled_via", &"leash_needs_tapped", &"leash_power_capped"]: g._rec(victim, field)
			victim.controlled_via = leash
			victim.leash_needs_tapped = tapped
			victim.leash_power_capped = capped
			if not victim.phased_out and victim.controller_id != pid and not victim.cur_cant_change_control:
				g._set_controller(victim, pid)
				changed = true
				repeat = true
			if effects.is_empty() and victim.controller_id == pid:
				g._rec(g, &"_control_layers")
				g._control_layers.erase(id)
	g._refreshing_control = false
	return changed
