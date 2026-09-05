extends CardScript
## Mana Drain — {U}{U} — Instant — (leg, uncommon)
## Oracle: Counter target spell. At the beginning of your next main phase,
##         add an amount of {C} equal to that spell's mana value.
##
## Implementation: the counter is the ordinary CounterEffect; the payout is
## a DELAYED action (MtgGame.schedule_next_main_phase_action, new) rather
## than a trigger, because "the beginning of your next main phase" is a
## moment the engine's step machine already passes through and nothing else
## in the pool listens for it.
##
## The mana value is read BEFORE the spell is countered, which is the only
## order that works: a countered spell is in a graveyard, where its X is
## gone (CR 202.3b makes X zero anywhere but the stack) — so an X spell
## countered for {X}=5 really does pay out five, and an X spell countered
## for nothing pays out its printed pips alone.
##
## mage-go implements this with an upkeep trigger instead, and says so in a
## comment: *"no EvtMainPhase event exists in the engine"*. Ours has the
## moment, so it uses it.


func build() -> CardData:
	return CardData.new("Mana Drain", "{U}{U}", Mtg.CardType.INSTANT) \
		.spell(DrainEffect.new()) \
		.oracle("Counter target spell. At the beginning of your next main phase, "
			+ "add an amount of {C} equal to that spell's mana value.")


class DrainEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.spell()

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var spell := game.find_instance(target.instance_id)
		if spell == null:
			return
		# Read it while the spell is still ON THE STACK, X and all.
		var value := spell.data.cost.mana_value()
		var item := game.find_stack_item(spell)
		if item != null and spell.data.cost.has_x:
			value += item.x_value * spell.data.cost.x_count
		game.counter_spell(spell)
		if value <= 0:
			return
		# A WEAKREF, NOT `game`. The lambda below outlives this call — the
		# game holds it in `_next_main_actions` until the next main phase —
		# so capturing `game` directly makes the game own a Callable that
		# owns the game. A duel that ENDS with the payout still pending
		# then leaks the whole MtgGame (found 2026-09-04 by the AI pass,
		# whose counterspell fix made this the first card in the pool to
		# actually cast Mana Drain: "115 ObjectDB instances were leaked at
		# exit"). Invisible for as long as nothing ever cast it.
		var weak: WeakRef = weakref(game)
		game.schedule_next_main_phase_action(controller, func() -> void:
			var g: MtgGame = weak.get_ref()
			if g == null:
				return
			g.players[controller].mana_pool.add(Mtg.ManaColor.C, value)
			g.log_line("Mana Drain pays out %d colorless" % value))

	func describe() -> String:
		return "counters a spell and pays its mana value back next main phase"
