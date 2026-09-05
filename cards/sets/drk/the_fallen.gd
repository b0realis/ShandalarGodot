extends CardScript
## The Fallen — {1}{B}{B}{B} — Creature — Zombie — 2/3 — (drk, uncommon)
## Oracle: At the beginning of your upkeep, this creature deals 1 damage to
##         each opponent and planeswalker it has dealt damage to this game.
##
## Implementation: "this GAME", not this turn, so the engine's per-turn
## bookkeeping (CardInstance.damaged_players_this_turn, wiped at cleanup)
## is not enough. A second trigger on DAMAGE_DEALT records every player The
## Fallen bites into its own card-local memory, which lasts as long as the
## permanent does — and dies with it, which is right: a Fallen that died
## and came back is a NEW object with no grudges (CR 400.7).
##
## The upkeep trigger then bites everyone on the list again, which is what
## makes it a clock that starts only after it has connected once.
## Planeswalkers do not exist in the 1997 pool.


func build() -> CardData:
	return CardData.new("The Fallen", "{1}{B}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(2, 3) \
		.with_subtypes(["zombie"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DAMAGE_DEALT, _remember,
			"(bookkeeping) remember each opponent this creature has dealt damage to",
			_it_bit_a_player)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _haunt,
			"At the beginning of your upkeep, this creature deals 1 damage to each opponent it has dealt damage to this game.",
			_own_upkeep)) \
		.oracle("At the beginning of your upkeep, this creature deals 1 damage to each "
			+ "opponent and planeswalker it has dealt damage to this game.")


static func _it_bit_a_player(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	if not event.data.has("to_player"):
		return false
	if event.data.get("source") != source:
		return false
	return int(event.data["to_player"]) != source.controller_id


static func _remember(_game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var bitten: Array = source.memory.get("bitten", [])
	var victim := int(event.data["to_player"])
	if not bitten.has(victim):
		bitten.append(victim)
	source.memory["bitten"] = bitten


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _haunt(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	for victim in (source.memory.get("bitten", []) as Array):
		var pid := int(victim)
		if not game.players[pid].has_lost:
			game.deal_damage(source, TargetRef.player(pid), 1)
