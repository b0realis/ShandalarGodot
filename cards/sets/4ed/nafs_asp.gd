extends CardScript
## Nafs Asp — {G} — Creature — Snake — 1/1 — (4ed, common)
## Oracle: Whenever this creature deals damage to a player, that player
##         loses 1 life at the beginning of their next draw step unless
##         they pay {1} before that draw step.
##
## Implementation: the bite creates a DELAYED triggered ability (CR
## 603.7a — MtgGame.schedule_delayed_trigger) that fires at the bitten
## player's next draw step, independent of the Asp: killing the Asp
## afterwards cancels nothing. Each bite is its own debt — two hits mean
## two triggers, and two life unless both are paid.
##
## "Unless they pay {1} before that draw step": the entry carries a
## settlement (settle_cost {1}, settle_by the bitten player), which that
## player may pay off any time they have priority before the draw step
## through MtgGame.settle_delayed_trigger — from a mana pool they would
## otherwise lose, or lands about to untap. Left unpaid until the trigger
## resolves, they are asked once more to pay {1} as it resolves — the
## reference implementations' window (mage-go's `TryPayMana` at the draw
## step, XMage's DoUnlessCostPaid) and the one a heuristic seat uses —
## through the engine's triggered-payment path (floating mana first,
## then auto-tapped lands); otherwise they lose the life. The 1997
## game's line for the loss is `@NAFS_ASP` (`Program/prompts.txt:611`):
## "Naf's Asp takes 1 life!".


func build() -> CardData:
	return CardData.new("Nafs Asp", "{G}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["snake"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DAMAGE_DEALT, _bite,
			"Whenever this creature deals damage to a player, that player loses 1 life at the beginning of their next draw step unless they pay {1}.",
			_my_damage_to_a_player)) \
		.oracle("Whenever this creature deals damage to a player, that player loses 1 life at the beginning of their next draw step unless they pay {1} before that draw step.")


static func _my_damage_to_a_player(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	return event.data.get("source") == source and event.data.has("to_player")


static func _bite(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var bitten := int(event.data["to_player"])
	var entry := game.schedule_delayed_trigger(TriggeredAbility.new(
		Mtg.EventType.DRAW_STEP, _collect.bind(bitten),
		"At the beginning of the bitten player's next draw step, they lose 1 life unless they pay {1}.",
		_draw_step_of.bind(bitten)), source.controller_id, source, false, {},
		"Nafs Asp's bite: pay {1} or lose 1 life at your next draw step")
	entry["settle_cost"] = ManaCost.parse("{1}")
	entry["settle_by"] = bitten


static func _draw_step_of(_game: MtgGame, _source: CardInstance, event: GameEvent,
		bitten: int) -> bool:
	return int(event.data["player"]) == bitten


static func _collect(game: MtgGame, _source: CardInstance, _event: GameEvent,
		bitten: int) -> void:
	var toll := ManaCost.parse("{1}")
	var can := game.can_afford_cost(bitten, toll)
	if can and game.agents[bitten].choose_yes_no(game, bitten,
			"Pay {1} to Nafs Asp?", true) and game.try_pay(bitten, toll):
		return
	game.log_line("Naf's Asp takes 1 life!")
	game.adjust_life(bitten, -1)
