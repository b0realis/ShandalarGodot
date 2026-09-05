extends CardScript
## Nicol Bolas — {2}{U}{U}{B}{B}{R}{R} — Legendary Creature — Elder Dragon — 7/7 — (leg, rare)
## Oracle: Flying
##         At the beginning of your upkeep, sacrifice Nicol Bolas unless
##         you pay {U}{B}{R}.
##         Whenever Nicol Bolas deals damage to an opponent, that player
##         discards their hand.
##
## Implementation: the cycle's upkeep rent plus a DAMAGE_DEALT trigger
## gated on the source being Bolas and the victim being an opponent —
## ANY damage counts, combat or otherwise. Seven flying damage and an
## empty hand is, in practice, the game.


func build() -> CardData:
	return CardData.new("Nicol Bolas", "{2}{U}{U}{B}{B}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(7, 7) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["elder", "dragon"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _rent,
			"At the beginning of your upkeep, sacrifice Nicol Bolas unless you pay {U}{B}{R}.",
			_own_upkeep)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DAMAGE_DEALT, _wipe_hand,
			"Whenever Nicol Bolas deals damage to an opponent, that player discards "
			+ "their hand.",
			_hit_an_opponent)) \
		.oracle("Flying\nAt the beginning of your upkeep, sacrifice Nicol Bolas "
			+ "unless you pay {U}{B}{R}.\nWhenever Nicol Bolas deals damage to an "
			+ "opponent, that player discards their hand.")


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _rent(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	var cost := ManaCost.parse("{U}{B}{R}")
	if game.can_afford_cost(pid, cost) \
			and game.agents[pid].choose_yes_no(game, pid,
				"Pay {U}{B}{R} to keep Nicol Bolas?", true) \
			and game.try_pay(pid, cost):
		return
	game.sacrifice_permanent(source)


static func _hit_an_opponent(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	if event.data.get("source") != source:
		return false
	if not event.data.has("to_player"):
		return false
	return int(event.data["to_player"]) != source.controller_id


static func _wipe_hand(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	game.discard_hand(int(event.data["to_player"]))
