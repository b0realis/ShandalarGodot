extends CardScript
## Fellwar Stone — {2} — Artifact — (4ed, uncommon)
## Oracle: {T}: Add one mana of any color that a land an opponent controls
##         could produce.
##
## Implementation: a CHOICE mana ability (ManaAbility.with_color_choice) that
## reads the opponent's LIVE lands each time it is tapped — so a Blood Moon or
## an Evil Presence really does change what the Stone makes. "ANY color that a
## land an opponent controls could produce" is the controller's choice among
## every colour on offer, and this card's job is only to take the CENSUS:
## MtgGame.tap_for_mana does the asking, because a mana ability never uses the
## stack (CR 605.3a) and the activation itself is the only place the duel can
## be held open for the answer (docs/duel-todo.md §1.3). With no coloured land
## opposite, the ability produces NO mana at all — a paired dynamic amount of
## zero — rather than quietly making colourless.


func build() -> CardData:
	return CardData.new("Fellwar Stone", "{2}", Mtg.CardType.ARTIFACT) \
		.mana(ManaAbility.new(Mtg.ManaColor.C) \
			.with_color_choice(_available_colors) \
			.with_dynamic_amount(_borrowed_amount)) \
		.oracle("{T}: Add one mana of any color that a land an opponent controls could produce.")


## Every colour an opponent's lands could make right now, in WUBRG order.
## "Could produce" (CR 106.7) is what each mana ability WOULD make if it
## resolved now: a Gem Bazaar's chosen colour (not the white its first
## entry spells out), a Reflecting Pool's census, and nothing from an
## ability that would make no mana at all (campaign 2026-10, w1-11).
static func _available_colors(game: MtgGame, source: CardInstance) -> Array[int]:
	var found := 0
	var enemy := game.opponent_of(source.controller_id)
	for inst in game.players[enemy].battlefield:
		if not inst.is_land() or not game.is_present(inst):
			continue
		for ability: ManaAbility in inst.cur_mana_abilities:
			for color in _could_produce(game, inst, ability):
				if int(color) != Mtg.ManaColor.C:
					found |= int(color)
	var out: Array[int] = []
	for c in Mtg.WUBRG:
		if (found & c) != 0:
			out.append(c)
	return out


## The colours [param ability] of [param land] would add if it resolved
## now — its first entry rewritten by a colour choice or a dynamic colour,
## and dropped when its dynamic amount is zero; later entries as printed.
static func _could_produce(game: MtgGame, land: CardInstance, ability: ManaAbility) -> Array:
	var out: Array = []
	for i in ability.produces.size():
		if i > 0:
			if int(ability.produces[i][1]) > 0: out.append(int(ability.produces[i][0]))
			continue
		if ability.dynamic_amount.is_valid() and ability.amount_for(game, land) <= 0:
			continue
		if ability.color_options.is_valid():
			out.append_array(ability.color_options.call(game, land))
		elif ability.dynamic_color.is_valid():
			out.append(int(ability.dynamic_color.call(game, land)))
		elif int(ability.produces[0][1]) > 0:
			out.append(int(ability.produces[0][0]))
	return out


static func _borrowed_amount(game: MtgGame, source: CardInstance) -> int:
	return 0 if _available_colors(game, source).is_empty() else 1
