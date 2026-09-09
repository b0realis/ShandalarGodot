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
## "As this enchantment enters, you lose life equal to your life total" is
## a REPLACEMENT effect (CR 614.1c): it is applied AS the enchantment
## enters, uses no stack, and there is no moment at which the Lich is on
## the battlefield and the life has not been paid. So it lives in
## CardData.as_it_enters — the hook MtgGame._put_on_battlefield runs once
## the permanent is on the battlefield (its own statics already published
## by the recalculation above it, so the 0 life total does not end the
## game) but before state-based actions and before any ENTERS_BATTLEFIELD
## trigger sees it.
##
## IT USED TO BE A TRIGGER (fixed 2026-09-09, found while moving Phantasmal
## Terrain onto the same hook). A trigger is a stack object, so BOTH
## PLAYERS HELD PRIORITY over a Lich that was already on the battlefield
## with its bargain live and its price unpaid — twenty life still standing
## and "you don't lose the game for having 0 or less life" already true.
## What that window bought, reproduced: seat at 2 life, Lich cast, a
## Lightning Bolt at its controller IN RESPONSE. The damage trigger below
## fed the Lich three permanents, and then "lose life equal to your life
## total" resolved against a life total of -1 — a loss of -1 is a GAIN of
## 1, which the card's own second static turns into a CARD DRAW. The Lich
## finished at -1 life holding an extra card where the rules leave it at
## -3 holding none. The price is paid as it enters now, so the earliest
## Bolt is the one that lands afterwards, and the amount can only ever be
## the life total the enchantment arrived on.


func build() -> CardData:
	return CardData.new("Lich", "{B}{B}{B}{B}", Mtg.CardType.ENCHANTMENT) \
		.as_it_enters(_pay_your_life) \
		.static_ability(StaticAbility.new(_the_bargain,
			"You don't lose the game for having 0 or less life. If you would gain life, draw that many cards instead.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DAMAGE_DEALT, _feed_the_lich,
			"Whenever you're dealt damage, sacrifice that many nontoken permanents. If you can't, you lose the game.",
			_damage_to_my_controller)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.LEAVES_BATTLEFIELD, _the_reckoning,
			"When this enchantment is put into a graveyard from the battlefield, you lose the game.",
			_is_self_in_a_graveyard)) \
		.oracle("As this enchantment enters, you lose life equal to your life total.\nYou don't lose the game for having 0 or less life.\nIf you would gain life, draw that many cards instead.\nWhenever you're dealt damage, sacrifice that many nontoken permanents. If you can't, you lose the game.\nWhen this enchantment is put into a graveyard from the battlefield, you lose the game.")


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


## THE PRICE (CR 614.1c), paid as the enchantment arrives: the bargain
## above is already published by then, so 0 life is survivable, and nothing
## has held priority over a Lich that had not paid.
static func _pay_your_life(game: MtgGame, _source: CardInstance,
		controller: int) -> void:
	game.adjust_life(controller, -game.players[controller].life)


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
