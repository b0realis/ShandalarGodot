extends CardScript
## Lich — {B}{B}{B}{B} — Enchantment — (2ed, rare)
## Oracle: As this enchantment enters, you lose life equal to your life total.
##         You don't lose the game for having 0 or less life.
##         If you would gain life, draw that many cards instead.
##         Whenever you're dealt damage, sacrifice that many nontoken
##         permanents. If you can't, you lose the game.
##         When this enchantment is put into a graveyard from the
##         battlefield, you lose the game.
##
## Implementation: every clause. Two of them are player-level statics the
## continuous pipeline rebuilds each pass (cant_lose_to_life,
## life_gain_becomes_draw), so they vanish the instant the Lich does — at
## which point the last clause kills you anyway.
##
## The choice on resolution is the acting seat's own, asked through their
## DecisionAgent: a human seat is held open on it (docs/duel-todo.md
## §1.3) and every other seat answers for itself. The value the card
## computes is only the HINT, and the candidates are pre-sorted for it.


func build() -> CardData:
	return CardData.new("Lich", "{B}{B}{B}{B}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_the_bargain,
			"You don't lose the game for having 0 or less life. If you would gain life, draw that many cards instead.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _pay_your_life,
			"As this enchantment enters, you lose life equal to your life total.",
			_is_self)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DAMAGE_DEALT, _feed_the_lich,
			"Whenever you're dealt damage, sacrifice that many nontoken permanents. If you can't, you lose the game.",
			_damage_to_my_controller)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.LEAVES_BATTLEFIELD, _the_reckoning,
			"When this enchantment is put into a graveyard from the battlefield, you lose the game.",
			_is_self_in_a_graveyard)) \
		.oracle("As this enchantment enters, you lose life equal to your life total.\nYou don't lose the game for having 0 or less life.\nIf you would gain life, draw that many cards instead.\nWhenever you're dealt damage, sacrifice that many nontoken permanents. If you can't, you lose the game.\nWhen this enchantment is put into a graveyard from the battlefield, you lose the game.")


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


## "Put into a graveyard from the battlefield" — NOT any departure: a
## bounced or exiled Lich costs you nothing but the enchantment (the
## leave-event is dispatched after the zone change, so the zone is live).
static func _is_self_in_a_graveyard(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source \
		and source.zone == Mtg.Zone.GRAVEYARD


static func _the_bargain(game: MtgGame, source: CardInstance) -> void:
	var p := game.players[source.controller_id]
	p.cant_lose_to_life = true
	p.life_gain_becomes_draw = true


static func _pay_your_life(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var pid := source.controller_id
	game.adjust_life(pid, -game.players[pid].life)


static func _damage_to_my_controller(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	return event.data.has("to_player") \
		and int(event.data["to_player"]) == source.controller_id


static func _feed_the_lich(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var pid := source.controller_id
	var owed := int(event.data["amount"])
	for _i in owed:
		var fodder: Array[CardInstance] = []
		for inst in game.players[pid].battlefield:
			if not inst.is_token:
				fodder.append(inst)
		if fodder.is_empty():
			game.lose_game(pid, "the Lich went unfed")
			return
		fodder.sort_custom(Lich_cheapest_first)
		var chosen := game.agents[pid].choose_card(game, pid, fodder,
			"Sacrifice a permanent to the Lich")
		if chosen == null or not fodder.has(chosen):
			chosen = fodder[0]
		game.sacrifice_permanent(chosen)


static func Lich_cheapest_first(a: CardInstance, b: CardInstance) -> bool:
	return a.data.cost.mana_value() < b.data.cost.mana_value()


static func _the_reckoning(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	game.lose_game(source.controller_id, "the Lich left the battlefield")
