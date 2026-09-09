extends CardScript
## Black Vise — {1} — Artifact (2ed, uncommon)
## Oracle: As this artifact enters, choose an opponent.
##         At the beginning of the chosen player's upkeep, this artifact
##         deals X damage to that player, where X is the number of cards in
##         their hand minus 4.
##
## Implementation: a CR 614.1c REPLACEMENT (CardData.as_it_enters) stamps
## the chosen opponent into the Vise's card-local memory (in a duel there
## is exactly one, so the choice makes itself — the same shape as Cursed
## Rack), and the upkeep trigger fires on THAT player rather than on
## "whoever isn't my controller". The difference is visible the moment the
## Vise changes hands (Steal Artifact, Aladdin): the choice was locked in
## as it entered, so a stolen Vise keeps squeezing the player it chose
## instead of turning on its caster.
##
## Damage = hand size - 4 (zero or negative = nothing). The mirror of The
## Rack (the_rack.gd, 4ed) — together the era's famous "Rack-Vise" squeeze.
##
## WHICH IS WHY IT IS NOT AN ARRIVAL TRIGGER (fixed 2026-09-09, with Lich,
## Jihad, The Rack and Cursed Rack). A trigger goes on the stack, and an
## Aladdin activated IN THAT WINDOW took the Vise before the choice was
## stamped — so the choice was then made from the THIEF'S seat and named
## the Vise's own caster. Locked in as it enters, the theft can no longer
## reach the choice, which is exactly what the printed line says.


func build() -> CardData:
	return CardData.new("Black Vise", "{1}", Mtg.CardType.ARTIFACT) \
		.as_it_enters(_choose) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START,
			_squeeze,
			"At the beginning of the chosen player's upkeep, Black Vise deals X damage to that player, where X is the number of cards in their hand minus 4.",
			_is_chosen_players_upkeep)) \
		.oracle("As this artifact enters, choose an opponent.\nAt the beginning of the chosen player's upkeep, this artifact deals X damage to that player, where X is the number of cards in their hand minus 4.")


## THE CHOICE (CR 614.1c), made as the Vise arrives and never afterwards.
static func _choose(game: MtgGame, source: CardInstance, controller: int) -> void:
	source.memory["victim"] = game.opponent_of(controller)


## The chosen player's upkeep. A Vise that never made the choice (put onto
## the battlefield by a path that never ran the hook above) has no memory
## to read and falls back to the current opponent.
static func _is_chosen_players_upkeep(game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	var victim: int = int(source.memory.get("victim",
		game.opponent_of(source.controller_id)))
	return int(event.data["player"]) == victim


static func _squeeze(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var pid: int = event.data["player"]
	var x := game.players[pid].hand.size() - 4
	if x > 0:
		game.deal_damage(source, TargetRef.player(pid), x)
