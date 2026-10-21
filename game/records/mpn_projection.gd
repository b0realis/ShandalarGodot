class_name MpnProjection
extends MtgGame
## [QoL] Display-only adapter for the duel widgets. Never setup, resolve,
## recalculate, shuffle or execute a recorded action. Only public value copies.
## Unknown characteristics stay absent; local definitions provide print art/cost
## only, never abilities, effects or a replacement for the recorded rules text.

const MAX_VISIBLE := 512
var observation := {}
var rows := {}
var _ids := {}
var _next_id := 0

func _init() -> void:
	players = [MtgPlayer.new(0, "P1", 20), MtgPlayer.new(1, "P2", 20)]

static func refusal(state: Dictionary) -> String:
	if state.get("objects", {}).size() > MAX_VISIBLE or state.get("stack", []).size() > MAX_VISIBLE:
		return "This observation is too large for the graphical table. Use the history view."
	return ""

func local_id(handle: String) -> int:
	if handle == "": return -1
	if not _ids.has(handle):
		_next_id += 1
		_ids[handle] = _next_id
	return _ids[handle]

func ingest(state: Dictionary, headers: Dictionary) -> void:
	observation = state.duplicate(true)
	rows = observation.objects
	# Recreate detached values on each observation: no later row can leave a
	# retired face, attachment, counter or status behind after a backwards seek.
	_instances.clear()
	_ids.clear()
	_next_id = 0
	stack.clear()
	combat.clear()
	damage_pending.clear()
	for pid in 2:
		var player := players[pid]
		var row: Dictionary = state.players[pid]
		player.player_name = headers["Player.P%d" % (pid + 1)]
		player.life = int(row.life)
		player.poison = int(row.get("poison", 0))
		for zone in [player.battlefield, player.phased_out, player.hand,
			player.library, player.graveyard, player.exile, player.ante]: zone.clear()
		player.mana_pool.clear()
		for color in Mtg.ManaColor:
			player.mana_pool.add(Mtg.ManaColor[color], int(row.mana.get(color, 0)))
	for handle in rows:
		var row: Dictionary = rows[handle]
		var card := _card(row)
		_instances[card.id] = card
		var player := players[card.controller_id if row.zone in ["battlefield", "phased_out"] else card.owner_id]
		match row.zone:
			"battlefield": player.battlefield.append(card)
			"phased_out": player.phased_out.append(card)
			"graveyard": player.graveyard.append(card)
			"exile": player.exile.append(card)
			"ante": player.ante.append(card)
			"hand": player.hand.append(card)
			"library": player.library.append(card)
	# Attachment relationships are public, but a malformed cycle is not a
	# reason to lose every card from the display or recurse through a fan.
	for handle in rows:
		var host: Variant = rows[handle].get("attached_to", "")
		if not host is String or not rows.has(host) or host == handle: continue
		var seen := {handle: true}
		var next: Variant = host
		while next is String and rows.has(next) and not seen.has(next):
			seen[next] = true
			next = rows[next].get("attached_to", "")
		if next is String and seen.has(next): continue
		var card := find_instance(local_id(handle))
		var parent := find_instance(local_id(host))
		if card.zone == Mtg.Zone.BATTLEFIELD and parent.zone == Mtg.Zone.BATTLEFIELD:
			card.attached_to = parent.id
			parent.attachments.append(card.id)
	for row in state.stack:
		local_id(row.id)
	for row in state.stack:
		var item := StackItem.new()
		item.id = local_id(row.id)
		item.kind = {"spell": Mtg.StackKind.SPELL, "ability": Mtg.StackKind.ABILITY,
			"trigger": Mtg.StackKind.TRIGGER}.get(row.get("kind", ""), Mtg.StackKind.ABILITY)
		item.controller = clampi(int(row.get("controller", 0)) if row.get("controller", 0) is float or row.get("controller", 0) is int else 0, 0, 1)
		var source: Variant = row.get("source", "")
		item.card = find_instance(local_id(source)) if source is String and rows.has(source) else null
		if item.card == null:
			item.card = CardInstance.new(CardData.new(String(row.name), "", 0), -1, item.controller)
		item.description = String(row.name)
		item.x_value = int(row.x) if row.get("x") is float or row.get("x") is int else 0
		for target in row.targets:
			var ref := _target(target)
			if ref != null: item.targets.append(ref)
		stack.append(item)
	for handle in state.combat.attackers:
		if rows.has(handle) and rows[handle].zone == "battlefield": combat.attackers[local_id(handle)] = true
	for pair in state.combat.blocks:
		if not rows.has(pair[0]) or not rows.has(pair[1]): continue
		if rows[pair[0]].zone != "battlefield" or rows[pair[1]].zone != "battlefield": continue
		var blocker := local_id(pair[0])
		var attacker := local_id(pair[1])
		if not combat.blocks.has(blocker): combat.blocks[blocker] = attacker
		else:
			if not combat.extra_blocks.has(blocker): combat.extra_blocks[blocker] = []
			combat.extra_blocks[blocker].append(attacker)
	active_player = int(state.active)
	priority_player = -1 # never infer priority from the active player
	turn_number = int(state.turn)
	_step_index = Mtg.STEP_ORDER.find(Mtg.Step.get(String(state.step).to_upper(), Mtg.Step.UNTAP))
	# No game-over signal, choice, AI or automatic turn driver is attached.
	game_over = false

func _card(row: Dictionary) -> CardInstance:
	var types := 0
	if not row.face_down and row.get("types") is Array:
		for type in row.types:
			if type is String: types |= Mtg.CardType.get(type.to_upper(), 0)
	if row.creature: types |= Mtg.CardType.CREATURE
	else: types &= ~Mtg.CardType.CREATURE
	var print_data: CardData = null
	if not row.face_down and CardRegistry.has_card(row.name): print_data = CardRegistry.get_card(row.name)
	var data := CardData.new(row.name, str(print_data.cost) if print_data != null else "", types)
	data.power = int(row.power)
	data.toughness = int(row.toughness)
	data.oracle_text = String(row.rules_text) if not row.face_down and row.get("rules_text") is String else "Rules text not recorded."
	data.set_code = String(row.definition_set) if not row.face_down and row.get("definition_set") is String else ""
	if not row.face_down and row.get("subtypes") is Array:
		for subtype in row.subtypes:
			if subtype is String: data.subtypes.append(subtype)
	var card := CardInstance.new(data, local_id(row.id), int(row.owner))
	card.zone = Mtg.Zone.get(String(row.zone).to_upper(), Mtg.Zone.BATTLEFIELD)
	card.phased_out = row.zone == "phased_out"
	card.controller_id = int(row.controller)
	card.cur_power = int(row.power)
	card.cur_toughness = int(row.toughness)
	card.cur_types = types
	card.cur_subtypes = data.subtypes.duplicate()
	card.tapped = row.tapped
	card.face_down = row.face_down
	card.damage = maxi(0, int(row.damage))
	card.is_token = row.get("token", false) == true
	card.summoning_sick = false # unspecified, not inferred from arrival time
	card.cur_keywords.clear()
	if not row.face_down and row.get("keywords") is Array:
		for key in row.keywords:
			if key is String and Mtg.Keyword.has(key.to_upper()): card.cur_keywords.append(Mtg.Keyword[key.to_upper()])
	card.counters.clear()
	for key in row.counters:
		if MpnCodec._integer(row.counters[key], 0, 1000000): card.counters[key] = int(row.counters[key])
	card.set_meta("mpn_handle", row.id)
	card.set_meta(CardPrintings.META, String(row.printing) if not row.face_down and row.get("printing") is String else "")
	return card

func _target(row: Variant) -> TargetRef:
	if not row is Dictionary: return null
	var ref: TargetRef
	if row.get("player") in ["P1", "P2"]: ref = TargetRef.player(0 if row.player == "P1" else 1)
	elif row.get("object") is String and rows.has(row.object): ref = TargetRef.card(find_instance(local_id(row.object)))
	elif row.get("stack") is String and _ids.has(row.stack):
		ref = TargetRef.new()
		ref.is_ability = true
		ref.ability_id = local_id(row.stack)
	else: return null # unknown/departed targets and unidentifiable damage packets
	ref.amount = int(row.amount) if MpnCodec._integer(row.get("amount"), 0, 1000000) else 1
	return ref
