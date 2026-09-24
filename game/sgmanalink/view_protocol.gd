class_name SgViewProtocol
extends RefCounted
## [QoL] Validate untrusted host DTOs before the client UI indexes any field.
## No object/resource decoding or unconstrained UI arrays.


static func text(value: Variant, limit := 128) -> bool:
	if not value is String or value.length() > limit:
		return false
	for character in value:
		var code: int = character.unicode_at(0)
		if (code < 32 and code != 10) or code == 127 or (code >= 0x80 and code <= 0x9f) \
			or code in [0x202a, 0x202b, 0x202c, 0x202d, 0x202e, 0x2066, 0x2067, 0x2068, 0x2069]:
			return false
	return true


static func valid(message: Dictionary) -> bool:
	# Every field below arrives from another computer with an unknown type,
	# and GDScript raises on `5 == "welcome"` rather than answering false.
	# Match on text only, and read each field through a typed check.
	if not message.get("type") is String:
		return false
	match message.type:
		"welcome":
			return SgProtocol.exact(message, ["type", "v", "resume", "seq", "guest", "build"]) \
				and SgProtocol.integer(message.v, SgProtocol.VERSION, SgProtocol.VERSION) and SgProtocol.token(message.resume) \
				and SgProtocol.integer(message.seq) and text(message.guest, 40) and SgProtocol.token(message.build)
		"ack":
			return SgProtocol.exact(message, ["type", "seq", "ok", "error"]) \
				and SgProtocol.integer(message.seq, 1) and message.ok is bool and text(message.error, 512)
		"fatal":
			return SgProtocol.exact(message, ["type", "error"]) and text(message.error, 512)
		"state":
			var fields := ["type", "rooms", "room"]
			if message.has("tournament"):
				fields.append("tournament")
				if not SgTournamentProtocol.view(message.tournament): return false
			if not SgProtocol.exact(message, fields) \
				or not message.rooms is Array or message.rooms.size() > SgLocalServer.MAX_ROOMS or not room(message.room):
				return false
			for item in message.rooms:
				if not item is Dictionary or not SgProtocol.exact(item, ["id", "name", "host", "open", "decks", "deck"]) \
					or not SgProtocol.short_text(item.id, 16) or not SgProtocol.short_text(item.name) \
					or not text(item.host, 40) or not item.open is bool \
					or not item.decks in SgProtocol.DECK_RULES or not text(item.deck, 128):
					return false
			return true
	return false


static func pair(value: Variant, booleans := false) -> bool:
	if not value is Array or value.size() != 2:
		return false
	for item in value:
		if (booleans and not item is bool) or (not booleans and not text(item, 40)):
			return false
	return true


static func room(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if value.is_empty():
		return true
	var fields := ["id", "name", "seat", "names", "revision", "ready", "connected", "game", "deck_names", "deck"]
	# THE OPEN TABLE (2026-09-18): the table's deck rule and the assigned
	# deck's name. Optional in the DTO so a seat view built by hand stays valid.
	if value.has("decks") or value.has("fixed_deck"):
		fields.append_array(["decks", "fixed_deck"])
		if not value.get("decks") in SgProtocol.DECK_RULES or not text(value.get("fixed_deck"), 128): return false
	if value.has("bots"):
		fields.append("bots")
		if not value.bots is Array or value.bots.size() != 2: return false
		for bot in value.bots:
			if not bot is Dictionary or (not bot.is_empty() and not SgBotPlayer.valid(bot)): return false
	if value.has("tournament"):
		fields.append("tournament")
		if not SgTournamentProtocol.context(value.tournament): return false
	if not SgProtocol.exact(value, fields) \
		or not SgProtocol.short_text(value.id, 16) or not SgProtocol.short_text(value.name) \
		or not SgProtocol.integer(value.seat, 0, 1) or not SgProtocol.integer(value.revision) \
		or not pair(value.names) or not pair(value.ready, true) or not pair(value.connected, true) \
		or not game(value.game) or not SgProtocol.names(value.deck_names, 2) or value.deck_names.size() != 2 \
		or not deck(value.deck):
		return false
	return value.game.is_empty() or value.game.mode != "damage" or value.game.actor != value.seat \
		or not value.game.damage_request.is_empty()


## A face's live activated abilities: a cost string and a regeneration
## flag each, bounded like the rest of the face.
static func abilities(value: Variant) -> bool:
	if not value is Array or value.size() > 64: return false
	for row in value:
		if not row is Dictionary or not SgProtocol.exact(row, ["cost", "regen"]) \
				or not text(row.cost, 128) or not row.regen is bool:
			return false
	return true


static func cards(value: Variant) -> bool:
	if not value is Array or value.size() > SgProtocol.MAX_CARDS:
		return false
	for card in value:
		if not card is Dictionary or not SgProtocol.exact(card, ["id", "name", "rules", "land",
			"power", "toughness", "print_power", "print_toughness", "tapped", "sick", "damage",
			"attacking", "blocking", "playable",
			"creature", "owner", "controller", "masked", "types", "colors", "keywords", "subtypes", "counters",
			"protection", "landwalk", "rampage", "prevention", "regeneration", "chosen", "shield", "attached", "abilities", "actions", "exile_playable", "text_effects", "warded"] + (["printing"] if card.has("printing") else [])) \
			or not SgProtocol.short_text(card.id, 16) or not card_name(card.name) \
			or not text(card.rules, 4096) \
			or not text(card.shield, 128) \
			or not text(card.blocking, 16) \
			or (card.blocking != "" and not SgProtocol.short_text(card.blocking, 16)) \
			or not text(card.chosen, 128) or not text(card.attached, 16) \
			or (card.attached != "" and not SgProtocol.short_text(card.attached, 16)) \
			or not SgProtocol.indices(card.keywords, 64) or not SgProtocol.names(card.subtypes, 64) \
			or not SgProtocol.names(card.landwalk, 64) or not counters(card.counters) or not options(card.actions) \
			or not text_effects(card.text_effects) or (card.masked and not card.text_effects.is_empty()) \
			or not abilities(card.abilities) or (card.masked and not card.abilities.is_empty()):
			return false
		for key in ["land", "tapped", "sick", "attacking", "playable", "creature", "masked", "exile_playable", "warded"]:
			if not card[key] is bool:
				return false
		# A masked face carries no ward: the board badges nothing on a
		# face-down card, and the flag would name what the mask hides.
		if card.masked and card.warded: return false
		var printing: Variant = card.get("printing", "")
		if not SgProtocol.literal(printing, "") and (card.masked or not DeckPrintings.valid_id(printing)): return false
		# ...and no PRINTED pair, for the same reason: the print is the
		# identity a face-down card exists to withhold.
		if card.masked and (card.print_power != 0 or card.print_toughness != 0): return false
		for key in ["power", "toughness", "print_power", "print_toughness", "damage", "rampage", "prevention", "regeneration"]:
			if not SgProtocol.integer(card[key], -1000000 if key.ends_with("power") or key.ends_with("toughness") else 0, 1000000):
				return false
		for key in ["types", "colors", "protection"]:
			if not SgProtocol.integer(card[key], 0, 65535): return false
		for keyword in card.keywords:
			if not SgProtocol.integer(keyword, 0, Mtg.Keyword.size() - 1): return false
		if not SgProtocol.integer(card.owner, 0, 1) or not SgProtocol.integer(card.controller, 0, 1): return false
		# A named shield without a shield left to spend is not a state the
		# referee can be in; the board would draw a reminder for nothing.
		if card.shield != "" and int(card.prevention) <= 0: return false
	return true


static func text_effects(value: Variant) -> bool:
	if not value is Array or value.size() > SgProtocol.MAX_CARDS:
		return false
	for effect in value:
		if not effect is Dictionary or not effect.get("kind") is String:
			return false
		var circle: bool = effect.kind == "circle_color"
		if not SgProtocol.exact(effect, ["kind", "to"] if circle else ["kind", "from", "to"]):
			return false
		if effect.kind == "land_type":
			if not effect.from is String or not effect.to is String \
					or not Mtg.BASIC_LAND_COLORS.has(effect.from) or not Mtg.BASIC_LAND_COLORS.has(effect.to):
				return false
		elif effect.kind in ["color_word", "mana_color", "circle_color"]:
			var colors: Array = Mtg.ManaColor.values() if effect.kind == "mana_color" else Array(Mtg.WUBRG)
			for key in (["to"] if circle else ["from", "to"]):
				if not SgProtocol.integer(effect[key], 1, 32) or not colors.has(int(effect[key])):
					return false
		else:
			return false
	return true


static func game(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if value.is_empty():
		return true
	if not SgProtocol.exact(value, ["players", "hand", "stack", "mode", "actor", "active", "turn",
		"step", "first", "winner", "draw", "discard_count", "damage_request", "choice", "announcement", "information", "specials", "presentation", "journal"]) \
		or not value.players is Array or value.players.size() != 2 or not cards(value.hand) \
		or not value.stack is Array or value.stack.size() > SgProtocol.MAX_CARDS \
		or value.mode not in ["priority", "opening", "attack", "block", "discard", "damage", "finished", "choice"] \
		or value.step not in Mtg.Step or not value.draw is bool \
		or not SgProtocol.integer(value.discard_count, 0, SgProtocol.MAX_CARDS) or not SgProtocol.integer(value.turn, 0, 1000000) \
		or not damage(value.damage_request) or not choice(value.choice) or not announcement(value.announcement) or not information(value.information) \
		or not labels(value.specials, SgProtocol.MAX_CARDS) or not presentation(value.presentation) or not journal(value.journal) \
		or value.presentation.chain.size() != value.stack.size():
		return false
	for key in ["actor", "winner", "active", "first"]:
		if not SgProtocol.integer(value[key], -1 if key in ["actor", "winner"] else 0, 1):
			return false
	for i in 2:
		var player: Variant = value.players[i]
		if not player is Dictionary or not SgProtocol.exact(player, ["seat", "life", "hand_count",
			"library_count", "mana", "kept", "battlefield", "graveyard", "deck_name", "mana_colors", "revealed", "top", "exile", "ante"]) \
			or not SgProtocol.integer(player.seat, i, i) \
			or not SgProtocol.integer(player.life, -1000000, 1000000) or not player.kept is bool \
			or not cards(player.battlefield) or not cards(player.graveyard) or not cards(player.revealed) \
			or not cards(player.exile) or not cards(player.ante) or not text(player.top, 128) \
			or not text(player.deck_name, 128) or not numbers(player.mana_colors, 6) or player.mana_colors.size() != 6:
			return false
		for key in ["hand_count", "library_count", "mana"]:
			if not SgProtocol.integer(player[key], 0, 1000000 if key == "mana" else SgProtocol.MAX_CARDS):
				return false
	for item in value.stack:
		if not item is Dictionary or not SgProtocol.exact(item, ["name", "controller", "details", "x", "targets"]) \
			or not text(item.name, 128) or not SgProtocol.integer(item.controller, 0, 1) \
			or not text(item.details, 4096) or not SgProtocol.integer(item.x, 0, 1000) \
			or not labels(item.targets, SgProtocol.MAX_CARDS):
			return false
	if value.mode == "damage":
		if value.presentation.assignment.is_empty(): return false
		var found := false
		for player in value.players:
			for card in player.battlefield:
				if card.id == value.presentation.assignment.source: found = true
		if not found: return false
	return linked_cards(value)


static func _zone_cards(index: Dictionary, values: Array, zone: String) -> bool:
	var seen := {}
	for card in values:
		if seen.has(card.id): return false
		seen[card.id] = true
		if index.has(card.id) and (index[card.id].zone != zone or index[card.id].card != card): return false
		index[card.id] = {"zone": zone, "card": card}
	return true


static func linked_cards(value: Dictionary) -> bool:
	# Physical zones cannot alias a handle. Own revealed hands and stack-source
	# faces may repeat a card, but must describe the same object consistently.
	var index := {}
	if not value.hand.is_empty():
		var owner := int(value.hand[0].owner)
		for card in value.hand:
			if int(card.owner) != owner: return false
		if not _zone_cards(index, value.hand, "hand/%d" % owner): return false
	for seat in 2:
		for zone in ["battlefield", "graveyard", "exile", "ante", "revealed"]:
			if not _zone_cards(index, value.players[seat][zone],
				"%s/%d" % ["hand" if zone == "revealed" else zone, seat]): return false
	var objects := {}
	for row in value.presentation.chain:
		if objects.has(row.id): return false
		objects[row.id] = true
		if not row.face.is_empty():
			if index.has(row.face.id):
				if index[row.face.id].card != row.face: return false
			else: index[row.face.id] = {"zone":"stack", "card":row.face}
	for row in value.presentation.packets:
		if objects.has(row.id): return false
		objects[row.id] = true
	for id in objects:
		if index.has(id): return false
	for row in value.presentation.cards:
		if not index.has(row.id): return false
	for entry in index.values():
		if entry.card.blocking != "" and not index.has(entry.card.blocking): return false
		# An attachment is a link the board draws between two cards it holds:
		# the aura gets no slot of its own and its HOST draws it again. A host
		# this view never carried would take the aura off the board entirely.
		if entry.card.attached != "" and not index.has(entry.card.attached): return false
	for pair_value in value.presentation.blocks:
		if not index.has(pair_value[0]) or (pair_value[1] != "" and not index.has(pair_value[1])): return false
	for band in value.presentation.bands:
		for id in band:
			if not index.has(id): return false
	for id in value.presentation.attackable + value.presentation.blocked:
		if not index.has(id): return false
	for row in value.presentation.blockable:
		if not index.has(row[0]): return false
		for id in row[1]:
			if not index.has(id): return false
	if not value.damage_request.is_empty():
		for target in value.damage_request.targets:
			if target.id != "player" and not index.has(target.id): return false
	return true


static func journal(value: Variant) -> bool:
	if not value is Array or value.size() > SgJournal.LIMIT: return false
	var serial := 0
	for entry in value:
		if not entry is Dictionary or not SgProtocol.exact(entry, ["serial", "turn", "step", "pid", "kind", "text"]) \
			or not SgProtocol.integer(entry.serial, serial + 1) or (serial > 0 and entry.serial != serial + 1) \
			or not SgProtocol.integer(entry.turn) or not SgProtocol.integer(entry.step, 0, Mtg.Step.size() - 1) \
			or not SgProtocol.integer(entry.pid, -1, 1) or not SgProtocol.short_text(entry.kind, 16) or not text(entry.text, 512): return false
		serial = int(entry.serial)
	return true


static func damage(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if value.is_empty():
		return true
	if not SgProtocol.exact(value, ["source", "amount", "targets"]) \
		or not text(value.source, 128) or not SgProtocol.integer(value.amount, 0, 1000000) \
		or not value.targets is Array or value.targets.size() > SgProtocol.MAX_CARDS:
		return false
	for target in value.targets:
		if not target is Dictionary or not SgProtocol.exact(target, ["id", "name", "lethal"]) \
			or not SgProtocol.short_text(target.id, 16) or not text(target.name, 128) \
			or not SgProtocol.integer(target.lethal, 0, 1000000):
			return false
	return true


static func deck(value: Variant) -> bool:
	return value is Dictionary and (value.is_empty() or (SgProtocol.exact(value, ["name", "cards", "sideboard"] + (["printings"] if value.has("printings") else [])) \
		and text(value.name, 128) and SgProtocol.names(value.cards, 250) and SgProtocol.names(value.sideboard, 250) \
		and DeckPrintings.valid_map(value.get("printings", {}), value.cards + value.sideboard)))


static func card_name(value: Variant) -> bool:
	return text(value, 128) and not value.is_empty() and not value.contains("..") \
		and not value.contains("/") and not value.contains("\\")


static func numbers(value: Variant, maximum: int) -> bool:
	if not value is Array or value.size() > maximum: return false
	for item in value:
		if not SgProtocol.integer(item, 0, 1000000): return false
	return true


static func counters(value: Variant) -> bool:
	if not value is Dictionary or value.size() > 64: return false
	for key in value:
		if not text(key, 64) or not SgProtocol.integer(value[key], 0, 1000000): return false
	return true


static func options(value: Variant) -> bool:
	if not value is Array or value.size() > 64: return false
	for option in value:
		if not option is Dictionary or not SgProtocol.exact(option, ["kind", "index", "label", "x", "modes"]) \
			or option.kind not in ["spell", "ability", "mana"] or not SgProtocol.integer(option.index, 0, 63) \
			or not text(option.label, 4096) or not option.x is bool or not SgProtocol.names(option.modes, 64): return false
	return true


static func choice(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	return SgProtocol.exact(value, ["prompt", "source", "options", "count", "cancel", "information"]) \
		and text(value.prompt, 4096) and text(value.source, 128) and labels(value.options, 4096) \
		and SgProtocol.integer(value.count, 0, mini(SgProtocol.MAX_CARDS, value.options.size())) \
		and value.cancel is bool and information(value.information)


static func information(value: Variant) -> bool:
	if not value is Array or value.size() > 64: return false
	for item in value:
		if not item is Dictionary or not SgProtocol.exact(item, ["title", "cards"]) \
			or not text(item.title, 4096) or not SgProtocol.names(item.cards, SgProtocol.MAX_CARDS): return false
	return true


static func labels(value: Variant, maximum: int) -> bool:
	if not value is Array or value.size() > maximum: return false
	for item in value:
		if not text(item, 4096): return false
	return true


static func announcement(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	if not SgProtocol.exact(value, ["name", "kind", "x", "slots"]) or not text(value.name, 128) \
		or value.kind not in ["spell", "ability", "mana"] or not SgProtocol.integer(value.x, 0, 1000) \
		or not value.slots is Array or value.slots.size() > 64: return false
	for slot in value.slots:
		if not slot is Dictionary or not SgProtocol.exact(slot, ["label", "kind", "min", "max", "divided", "targets"]) \
			or not SgProtocol.integer(slot.kind, 0, TargetSpec.Kind.size() - 1) \
			or not text(slot.label, 4096) or not slot.targets is Array or slot.targets.size() > SgProtocol.MAX_CARDS: return false
		for key in ["min", "max", "divided"]:
			if not SgProtocol.integer(slot[key], 0, 1000000): return false
		for target in slot.targets:
			if not target is Dictionary or not SgProtocol.exact(target, ["id", "label"]) \
				or not SgProtocol.short_text(target.id, 16) or not text(target.label, 4096): return false
	return true


static func target_reference(value: Variant) -> bool:
	return value is Dictionary and (value.is_empty() or (SgProtocol.exact(value, ["kind", "id", "amount"]) \
		and value.kind in ["card", "player", "ability", "damage"] and SgProtocol.short_text(value.id, 16) \
		and (value.kind != "player" or value.id in ["0", "1"]) and SgProtocol.integer(value.amount, 0, 1000000)))


static func pairs(value: Variant, amounts := false, departed_target := false) -> bool:
	if not value is Array or value.size() > SgProtocol.MAX_CARDS: return false
	for pair_value in value:
		if not pair_value is Array or pair_value.size() != 2 or not SgProtocol.short_text(pair_value[0], 16): return false
		if amounts:
			if not SgProtocol.integer(pair_value[1], 0, 1000000): return false
		elif not (departed_target and SgProtocol.literal(pair_value[1], "")) and not SgProtocol.short_text(pair_value[1], 16): return false
	return true


static func block_matrix(value: Variant) -> bool:
	# Bound rows and columns separately: legal relationships are not cards.
	if not value is Array or value.size() > SgProtocol.MAX_CARDS: return false
	var seen := {}
	for row in value:
		if not row is Array or row.size() != 2 or not SgProtocol.short_text(row[0], 16) \
			or not SgProtocol.handles(row[1]) or seen.has(row[0]): return false
		seen[row[0]] = true
		var columns := {}
		for column in row[1]:
			if columns.has(column): return false
			columns[column] = true
	return true


static func presentation(value: Variant) -> bool:
	if not value is Dictionary or not SgProtocol.exact(value, ["priority", "toss", "order", "rules", "cues",
		"cards", "players", "chain", "packets", "bands", "blocks", "blocked", "attackable", "blockable", "events",
		"assignment", "targets", "prevention", "regeneration", "doomed", "draft", "respond", "floating",
		"untap_capped"]): return false
	for key in ["priority", "toss"]:
		if not SgProtocol.integer(value[key], 0, 1): return false
	for key in ["order", "prevention", "regeneration", "respond", "floating", "untap_capped"]:
		if not value[key] is bool: return false
	if not value.rules is Dictionary or not SgProtocol.exact(value.rules, SgDuelPresentation.RULES): return false
	for key in SgDuelPresentation.RULES:
		if not value.rules[key] is bool: return false
	for key in ["cues", "cards", "players", "chain", "packets", "bands", "targets", "events"]:
		if not value[key] is Array or value[key].size() > SgProtocol.MAX_CARDS: return false
	if value.players.size() != 2 or value.cues.size() > 64: return false
	if not SgProtocol.handles(value.blocked) or not SgProtocol.handles(value.attackable) \
		or not SgProtocol.handles(value.doomed) \
		or not pairs(value.blocks, false, true) or not block_matrix(value.blockable): return false
	for cue in value.cues:
		if not cue is Dictionary or not SgProtocol.exact(cue, ["serial", "cue"]) or not SgProtocol.integer(cue.serial, 1): return false
		if cue.cue not in SgDuelPresentation.CUES and cue.cue not in DuelAudio.LAND_PAIR_SOUNDS.values() \
			and cue.cue not in DuelAudio.LAND_SOLO_SOUNDS.values(): return false
	if value.events.size() > 64: return false
	for event in value.events:
		if not event is Dictionary or not SgProtocol.exact(event, ["serial", "kind", "card", "sacrificed"]) \
			or not SgProtocol.integer(event.serial, 1) or event.kind not in ["draw", "dies"] \
			or not SgProtocol.short_text(event.card, 16) or not event.sacrificed is bool: return false
	for player in value.players:
		if not player is Dictionary or not SgProtocol.exact(player, ["poison", "lands", "extra_lands",
			"unlimited_lands", "hand_revealed", "color", "damage_effects"]) \
			or not SgProtocol.integer(player.poison) or not SgProtocol.integer(player.lands) \
			or not SgProtocol.integer(player.extra_lands) or not player.unlimited_lands is bool \
			or not player.hand_revealed is bool or not labels(player.damage_effects, 64) \
			or player.color not in ["white", "blue", "black", "red", "green"]: return false
	for card in value.cards:
		if not card is Dictionary or not SgProtocol.exact(card, ["id", "flags", "abilities", "castable"]) \
			or not SgProtocol.short_text(card.id, 16) or not card.castable is bool or not card.flags is Dictionary \
			or not SgProtocol.exact(card.flags, SgDuelPresentation.FLAGS) or not card.abilities is Array or card.abilities.size() > 64: return false
		for key in SgDuelPresentation.FLAGS:
			if key in SgDuelPresentation.COUNTED_FLAGS:
				if not SgProtocol.integer(card.flags[key], -1, SgProtocol.MAX_CARDS): return false
			elif not card.flags[key] is bool: return false
		for ability in card.abilities:
			if not ability is Dictionary or not SgProtocol.exact(ability, ["kind", "index", "cost", "budget"]) \
				or ability.kind not in ["spell", "ability", "mana"] or not SgProtocol.integer(ability.index, 0, 63) \
				or not text(ability.cost, 128) or not SgProtocol.integer(ability.budget, 0, 1000): return false
	for item in value.chain:
		if not item is Dictionary or not SgProtocol.exact(item, ["id", "kind", "face", "refs"]) \
			or not SgProtocol.short_text(item.id, 16) or not SgProtocol.integer(item.kind, 0, 2) \
			or not item.face is Dictionary or (not item.face.is_empty() and not cards([item.face])) \
			or not item.refs is Array or item.refs.size() > SgProtocol.MAX_CARDS: return false
		for ref in item.refs:
			if not target_reference(ref): return false
	for packet in value.packets:
		if not packet is Dictionary or not SgProtocol.exact(packet, ["id", "source", "target", "amount", "combat"]) \
			or not SgProtocol.short_text(packet.id, 16) or not text(packet.source, 16) \
			or not target_reference(packet.target) or packet.target.is_empty() or not SgProtocol.integer(packet.amount) or not packet.combat is bool: return false
	for band in value.bands:
		if not SgProtocol.handles(band): return false
	for target in value.targets:
		if not target is Dictionary or not SgProtocol.exact(target, ["token", "ref"]) \
			or not SgProtocol.short_text(target.token, 16) or not target_reference(target.ref): return false
	if not value.draft is Dictionary: return false
	if not value.draft.is_empty() and (not SgProtocol.exact(value.draft, ["card", "kind", "index", "x", "mode", "reachable"]) \
		or not value.draft.reachable is bool \
		or not SgProtocol.short_text(value.draft.card, 16) or value.draft.kind not in ["spell", "ability", "mana"] \
		or not SgProtocol.integer(value.draft.index, 0, 63) or not SgProtocol.integer(value.draft.x, 0, 1000) \
		or not SgProtocol.integer(value.draft.mode, 0, 63)): return false
	if not value.assignment is Dictionary: return false
	return value.assignment.is_empty() or (SgProtocol.exact(value.assignment, ["source", "assigner", "amount",
		"targets", "trample", "assigned"]) \
		and SgProtocol.short_text(value.assignment.source, 16) and SgProtocol.integer(value.assignment.assigner, 0, 1) \
		and SgProtocol.integer(value.assignment.amount, 0, 1000000) and SgProtocol.handles(value.assignment.targets) \
		and value.assignment.trample is bool and pairs(value.assignment.assigned, true))
