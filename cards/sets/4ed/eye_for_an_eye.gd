extends CardScript
## Eye for an Eye — {W}{W} — Instant — (4ed, rare)
## Oracle: The next time a source of your choice would deal damage to you
##         this turn, instead that source deals that much damage to you and
##         Eye for an Eye deals that much damage to that source's controller.
##
## Implementation: the same one-shot player-side replacement Forcefield and
## Dark Sphere use, but this one PREVENTS NOTHING — the printed replacement
## says the damage still hits you, and adds a second, equal blow aimed at
## whoever owns the source. The handler deals the mirror damage and returns
## -1, so the original carries on through every ordinary gate: a Circle of
## Protection put up in response still saves you from your half and the
## other half lands anyway.
##
## The mirror's SOURCE is the Eye itself (which is in the graveyard by
## then, and does not need to be anywhere in particular — CR 608.2h), so it
## is a WHITE source and their Circle of Protection: White answers it.
##
## `Duel.hlp` names Eye for an Eye among the effects legal in the 1997
## damage-prevention window (topic **Combat**), so the effect is marked as
## one of the prevention family even though it prevents nothing — which is
## exactly the original's own classification.


func build() -> CardData:
	return CardData.new("Eye for an Eye", "{W}{W}", Mtg.CardType.INSTANT) \
		.spell(MirrorEffect.new()) \
		.oracle("The next time a source of your choice would deal damage to you "
			+ "this turn, instead that source deals that much damage to you and Eye "
			+ "for an Eye deals that much damage to that source's controller.")


class MirrorEffect extends EffectBase:
	func _init() -> void:
		is_damage_prevention = true   # `Duel.hlp` lists it in the window

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var candidates: Array[CardInstance] = []
		for inst in game.players[game.opponent_of(controller)].battlefield:
			candidates.append(inst)
		for item in game.stack:
			if item.card != null and item.card != source \
					and item.card.zone == Mtg.Zone.STACK \
					and not candidates.has(item.card):
				candidates.append(item.card)
		if candidates.is_empty():
			game.log_line("Eye for an Eye finds no source to watch")
			return
		var pick := game.agents[controller].choose_card(game, controller,
			candidates, "Choose a source for Eye for an Eye")
		if pick == null or not candidates.has(pick):
			pick = candidates[0]
		game.players[controller].damage_replacements.append({
			"desc": "Eye for an Eye",
			"filter": MirrorEffect._from_that_source.bind(pick.id),
			"apply": MirrorEffect._reflect.bind(source),
		})
		game.log_line("Eye for an Eye watches %s" % pick.data.card_name)

	static func _from_that_source(_game: MtgGame, packet: DamagePacket,
			chosen_id: int) -> bool:
		return packet.source_id() == chosen_id

	## The damage still lands on you; an equal blow goes back at whoever
	## controls the source.
	static func _reflect(game: MtgGame, packet: DamagePacket,
			eye: CardInstance) -> int:
		var back := packet.remaining()
		var culprit: int = packet.source.controller_id
		game.deal_damage(eye, TargetRef.player(culprit), back)
		return -1   # your half carries on through the ordinary gates

	func describe() -> String:
		return "the next damage to you is mirrored back at its controller"
