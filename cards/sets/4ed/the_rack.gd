extends CardScript
## The Rack — {1} — Artifact (4ed, uncommon; first printed in Antiquities)
## Oracle: As this artifact enters, choose an opponent.
##         At the beginning of the chosen player's upkeep, this artifact
##         deals X damage to that player, where X is 3 minus the number of
##         cards in their hand.
##
## Implementation: in a two-player duel "choose an opponent" has exactly
## one legal choice, so the choice makes itself — but it is still a choice
## LOCKED IN as the artifact enters, so an ETB trigger stamps it into the
## Rack's card-local memory (Cursed Rack's shape) and the upkeep trigger
## reads that instead of "whoever isn't my controller". A Rack that changes
## hands (Steal Artifact, Aladdin) therefore keeps stretching the player it
## chose rather than turning on its caster. Damage = 3 - hand size. Black
## Vise's mirror; see black_vise.gd.


func build() -> CardData:
	return CardData.new("The Rack", "{1}", Mtg.CardType.ARTIFACT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _choose,
			"As The Rack enters, choose an opponent.",
			_is_self)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START,
			_stretch,
			"At the beginning of the chosen player's upkeep, The Rack deals X damage to that player, where X is 3 minus the number of cards in their hand.",
			_is_chosen_players_upkeep)) \
		.oracle("As this artifact enters, choose an opponent.\nAt the beginning of the chosen player's upkeep, this artifact deals X damage to that player, where X is 3 minus the number of cards in their hand.")


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _choose(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	source.memory["victim"] = game.opponent_of(source.controller_id)


## The chosen player's upkeep, falling back to the current opponent for a
## Rack that never made the choice (it was already on the battlefield, or
## its ETB trigger was countered away).
static func _is_chosen_players_upkeep(game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	var victim: int = int(source.memory.get("victim",
		game.opponent_of(source.controller_id)))
	return int(event.data["player"]) == victim


static func _stretch(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var pid: int = event.data["player"]
	var x := 3 - game.players[pid].hand.size()
	if x > 0:
		game.deal_damage(source, TargetRef.player(pid), x)
