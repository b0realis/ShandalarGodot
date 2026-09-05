extends CardScript
## All Hallow's Eve — {2}{B}{B} — Sorcery — (leg, rare)
## Oracle: Exile All Hallow's Eve with two scream counters on it.
##         At the beginning of your upkeep, if this card is exiled with a
##         scream counter on it, remove a scream counter from it. If there
##         are no more scream counters on it, put it into your graveyard and
##         each player returns all creature cards from their graveyard to
##         the battlefield.
##
## Implementation: the spell exiles ITSELF on resolution
## (CardInstance.exile_after_resolution, the same door "Exile Recall" uses)
## with two counters on it, and then keeps ticking from EXILE — which is
## what CardData.exile_triggers (new) is for: the sibling of the graveyard
## crawl, reached by the same turn-based UPKEEP_START pass, so nothing on
## the dispatcher's hot path changes.
##
## Two counters means two upkeeps of waiting: it comes down on your third
## turn after casting, which is the printed price for the biggest mass
## reanimation in the pool.
##
## EACH player gets their creatures back, and each under their OWN control
## (MtgGame.reanimate with the card's owner). Casting it is a decision about
## whose graveyard is fuller — the card is a bomb and a gift at once.
##
## The permanents arrive one after another with no priority in between, so
## a Nether Shadow that comes back cannot be answered before the next one
## lands; that is the ordinary way a mass effect resolves.


func build() -> CardData:
	return CardData.new("All Hallow's Eve", "{2}{B}{B}", Mtg.CardType.SORCERY) \
		.spell(ExileSelfEffect.new()) \
		.with_exile_trigger(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _scream,
			"At the beginning of your upkeep, remove a scream counter. With none left, each player returns all creature cards from their graveyard to the battlefield.",
			_your_upkeep_while_screaming)) \
		.oracle("Exile All Hallow's Eve with two scream counters on it.\nAt the "
			+ "beginning of your upkeep, if this card is exiled with a scream "
			+ "counter on it, remove a scream counter from it. If there are no more "
			+ "scream counters on it, put it into your graveyard and each player "
			+ "returns all creature cards from their graveyard to the battlefield.")


## The intervening "if" (CR 603.4): exiled, and still screaming.
static func _your_upkeep_while_screaming(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	return int(event.data["player"]) == source.owner_id \
		and source.zone == Mtg.Zone.EXILE \
		and int(source.counters.get("scream", 0)) > 0


static func _scream(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	# Checked again on resolution — the intervening "if" is asked twice.
	var left := int(source.counters.get("scream", 0))
	if source.zone != Mtg.Zone.EXILE or left <= 0:
		return
	left -= 1
	source.counters["scream"] = left
	game.log_line("All Hallow's Eve screams (%d left)" % left)
	if left > 0:
		return
	source.counters.erase("scream")
	game.return_from_exile_to_graveyard(source)
	for pid in [source.owner_id, game.opponent_of(source.owner_id)]:
		for card in game.players[pid].graveyard.duplicate():
			if card != source and card.data.is_creature():
				game.reanimate(card, pid)


class ExileSelfEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source == null:
			return
		source.counters["scream"] = 2
		source.exile_after_resolution = true
		game.log_line("All Hallow's Eve is exiled with two scream counters")

	func describe() -> String:
		return "exiles itself with two scream counters"
