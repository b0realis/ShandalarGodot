class_name SgCardPresentation
extends RefCounted
## [QoL] Detached, render-only cards for the shared MiniCard/CardPreview widgets.
## Never a host CardInstance or rules game. A local printed definition is used
## only for a named card already disclosed in the seat-filtered, validated DTO.


static func make(card: Dictionary, seat: int, zone: int, existing: CardInstance = null) -> CardInstance:
	var data: CardData = CardRegistry.get_card(card.name) if CardRegistry.has_card(card.name) else null
	if data == null or card.masked:
		# Tokens and masked creatures need no executable definition from a host.
		# The PRINT is still theirs: a token has no registry entry to read it
		# from, and both the board's P/T ink and the enlarged card's pair and
		# type line ask the definition rather than the live values. A masked
		# face sends zeros and no subtypes, so the mask keeps everything.
		data = CardData.new(card.name, "", int(card.types)).oracle(card.rules) \
			.pt(int(card.print_power), int(card.print_toughness)) \
			.with_subtypes(card.subtypes)
	# Numeric ids are UI-local, not the referee's instance ids. Keep the opaque
	# handle separately; never manufacture a command by guessing an engine id.
	var instance := existing if existing != null else CardInstance.new(data, -1, seat)
	instance.data = data
	instance.printed_data = data
	instance.zone = zone
	instance.cur_power = int(card.power)
	instance.cur_toughness = int(card.toughness)
	instance.tapped = card.tapped
	instance.damage = int(card.damage)
	instance.summoning_sick = card.sick
	instance.owner_id = int(card.owner)
	instance.controller_id = int(card.controller)
	instance.cur_types = int(card.types)
	instance.cur_colors = int(card.colors)
	instance.cur_keywords.assign(card.keywords)
	instance.cur_subtypes.assign(card.subtypes)
	instance.cur_landwalk.assign(card.landwalk)
	instance.cur_protection = int(card.protection)
	instance.cur_rampage = int(card.rampage)
	instance.counters = card.counters.duplicate()
	instance.prevention = int(card.prevention)
	# The definition the shield came from, so the board can fan its reminder
	# behind the creature exactly as the local duel does. A name only: the
	# host's own CardInstance and its Callables never cross the wire.
	instance.prevention_source = CardRegistry.get_card(card.shield) \
		if CardRegistry.has_card(card.shield) else null
	instance.regeneration_shields = int(card.regeneration)
	# The LIVE activated abilities, so the board's cost badges and its
	# regeneration mark follow grants and silences (Zombie Master,
	# Titania's Song) as they do locally. A cost and a flag each — the
	# ability itself never crosses, and these are never activated here.
	instance.cur_activated_abilities.clear()
	for row in card.abilities:
		var effects: Array = [RegenerateEffect.new()] if row.regen else []
		instance.cur_activated_abilities.append(ActivatedAbility.new(String(row.cost), false, effects))
	# PROTECTION FROM ARTIFACTS (Artifact Ward) is the two source-filtered
	# clauses the badge reads by their `desc`, so the same two descs are
	# rebuilt here. The filters are inert stand-ins of the engine's arity:
	# this projection never deals damage or checks a target, and the host's
	# own Callables never cross the wire.
	instance.cur_damage_immunity.clear()
	instance.cur_target_bans.clear()
	if card.warded:
		instance.cur_damage_immunity.append({"desc": "artifact sources",
			"filter": func(_game: MtgGame, _source: CardInstance) -> bool: return false})
		instance.cur_target_bans.append({"desc": "artifact sources",
			"filter": func(_game: MtgGame, _targeting: CardInstance, _spec: TargetSpec) -> bool: return false})
	instance.face_down = card.masked
	instance.set_meta(CardPrintings.META, "" if card.masked else String(card.get("printing", "")))
	var effects: Array = card.text_effects.duplicate(true)
	for effect in effects:
		# JSON numbers arrive as floats; normalize color enum keys for hover text.
		if effect.kind != "land_type":
			effect.to = int(effect.to)
			if effect.has("from"): effect.from = int(effect.from)
	instance.set_meta("sg_text_effects", effects)
	instance.set_meta("sg_handle", card.id)
	return instance
