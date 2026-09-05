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
static func _available_colors(game: MtgGame, source: CardInstance) -> Array[int]:
	var found := 0
	var enemy := game.opponent_of(source.controller_id)
	for inst in game.players[enemy].battlefield:
		if not inst.is_land():
			continue
		for ability in inst.cur_mana_abilities:
			for pair in ability.produces:
				if int(pair[0]) != Mtg.ManaColor.C:
					found |= int(pair[0])
	var out: Array[int] = []
	for c in Mtg.WUBRG:
		if (found & c) != 0:
			out.append(c)
	return out


static func _borrowed_amount(game: MtgGame, source: CardInstance) -> int:
	return 0 if _available_colors(game, source).is_empty() else 1
