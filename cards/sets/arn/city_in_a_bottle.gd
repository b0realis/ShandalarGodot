extends CardScript
## City in a Bottle — {2} — Artifact — (arn, rare)
## Oracle: Whenever one or more other nontoken permanents with a name
##         originally printed in the Arabian Nights expansion are on the
##         battlefield, their controllers sacrifice them.
##         Players can't cast spells or play lands with a name originally
##         printed in the Arabian Nights expansion.
##
## Implementation: "originally printed in Arabian Nights" is a fact about
## the card NAME, answered by CardRegistry.originally_printed_in() against
## the Scryfall snapshot — twenty-four Arabian cards (Erg Raiders, Bird
## Maiden, Desert Twister ...) ship in other set folders, and basic lands
## that appear in the Arabian data were printed in Alpha, so they stay.
## Two triggers cover the sweep (the
## Bottle's own arrival clears the board; anything Arabian that enters
## afterwards is sacrificed on the spot) and the ban is a real play veto
## radiated to both players (CardData.play_ban).


func build() -> CardData:
	return CardData.new("City in a Bottle", "{2}", Mtg.CardType.ARTIFACT) \
		.bans_playing(_is_arabian) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _sweep_arabia,
			"Whenever one or more other nontoken Arabian Nights permanents are on the battlefield, their controllers sacrifice them.",
			_is_self)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _sacrifice_the_newcomer,
			"An Arabian Nights permanent that arrives is sacrificed by its controller.",
			_is_another_arabian)) \
		.oracle("Whenever one or more other nontoken permanents with a name originally printed in the Arabian Nights expansion are on the battlefield, their controllers sacrifice them.\nPlayers can't cast spells or play lands with a name originally printed in the Arabian Nights expansion.")


static func _is_arabian(_game: MtgGame, _pid: int, data: CardData) -> bool:
	return CardRegistry.originally_printed_in(data.card_name, "arn")


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _is_another_arabian(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	var arrival: CardInstance = event.data.get("instance")
	return arrival != null and arrival != source and not arrival.is_token \
		and CardRegistry.originally_printed_in(arrival.data.card_name, "arn")


static func _sweep_arabia(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var doomed: Array[CardInstance] = []
	for inst in game.all_battlefield():
		if inst == source or inst.is_token:
			continue
		if CardRegistry.originally_printed_in(inst.data.card_name, "arn"):
			doomed.append(inst)
	for inst in doomed:
		if inst.zone == Mtg.Zone.BATTLEFIELD:
			game.sacrifice_permanent(inst)


static func _sacrifice_the_newcomer(game: MtgGame, _source: CardInstance,
		event: GameEvent) -> void:
	var arrival: CardInstance = event.data.get("instance")
	if arrival != null and arrival.zone == Mtg.Zone.BATTLEFIELD:
		game.sacrifice_permanent(arrival)
