extends CardScript
## Nether Shadow — {B}{B} — Creature — Spirit — 1/1 — (2ed, rare)
## Oracle: Haste
##         At the beginning of your upkeep, if this card is in your
##         graveyard with three or more creature cards above it, you may
##         put this card onto the battlefield.
##
## Implementation: the graveyard is an ordered pile in this engine (cards
## are appended as they arrive), so "three or more creature cards above it"
## is exactly the count of creature cards later in the array. A card in a
## graveyard has no abilities of its own, so the check runs as an upkeep
## sweep from the game side — see MtgGame's graveyard-trigger dispatch.
## That count is an INTERVENING-IF clause, so it is tested both when the
## trigger would go on the stack and again on resolution (CR 603.4), and
## the return itself is a "you may", routed through the owner's
## DecisionAgent (hinted yes — a free 1/1 with haste is almost always
## worth taking).


func build() -> CardData:
	return CardData.new("Nether Shadow", "{B}{B}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["spirit"]) \
		.with_keywords([Mtg.Keyword.HASTE]) \
		.with_graveyard_trigger(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _crawl_back,
			"At the beginning of your upkeep, if this card is in your graveyard with three or more creature cards above it, you may put this card onto the battlefield.",
			_buried_deep_enough)) \
		.oracle("Haste\nAt the beginning of your upkeep, if this card is in your graveyard with three or more creature cards above it, you may put this card onto the battlefield.")


static func _buried_deep_enough(game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	if source.zone != Mtg.Zone.GRAVEYARD:
		return false
	if int(event.data["player"]) != source.owner_id:
		return false
	var pile: Array[CardInstance] = game.players[source.owner_id].graveyard
	var index := pile.find(source)
	if index < 0:
		return false
	var above := 0
	for i in range(index + 1, pile.size()):
		if pile[i].data.is_creature():
			above += 1
	return above >= 3


static func _crawl_back(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	# The "three or more creature cards above it" clause is an
	# INTERVENING IF: it is checked when the ability would trigger AND
	# again on resolution (CR 603.4), so a pile that was disturbed in
	# response leaves the Shadow where it is.
	if not _buried_deep_enough(game, source, event):
		return
	# "you MAY put this card onto the battlefield" — the owner chooses.
	if not game.agents[source.owner_id].choose_yes_no(game, source.owner_id,
			"Return %s from your graveyard to the battlefield?" % source.data.card_name,
			true):
		return
	game.reanimate(source, source.owner_id)
