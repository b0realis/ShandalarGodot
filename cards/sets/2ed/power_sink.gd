extends CardScript
## Power Sink — {X}{U} — Instant — (2ed, common)
## Oracle: Counter target spell unless its controller pays {X}. If that
##         player doesn't, they tap all lands with mana abilities they
##         control and lose all unspent mana.
##
## Implementation: the full card. Refusing (or failing) the {X} counters
## the spell AND strips the caster's board — the second half is what makes
## Power Sink far better than a plain Mana Leak.
##
## The rent is a real QUESTION, asked of the paying seat through its own
## DecisionAgent: the human seat is held open on it (docs/duel-todo.md
## §1.3) and every other seat answers for itself. The `hint` below is
## only the default answer, not a decision the engine takes.


func build() -> CardData:
	return CardData.new("Power Sink", "{X}{U}", Mtg.CardType.INSTANT) \
		.spell(PowerSinkEffect.new()) \
		.oracle("Counter target spell unless its controller pays {X}. If that player doesn't, they tap all lands with mana abilities they control and lose all unspent mana.")


class PowerSinkEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.spell()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, x_value: int = 0) -> void:
		var spell := game.find_instance(target.instance_id)
		if spell == null or spell.zone != Mtg.Zone.STACK:
			return
		var item := game.find_stack_item(spell)
		var victim := spell.owner_id if item == null else item.controller
		var toll := ManaCost.parse("{%d}" % x_value)
		if x_value <= 0 or (game.can_afford_cost(victim, toll)
				and game.agents[victim].choose_yes_no(game, victim,
					"Pay {%d} to save %s?" % [x_value, spell.data.card_name], true)
				and game.try_pay(victim, toll)):
			return
		game.counter_spell(spell)
		for inst in game.players[victim].battlefield.duplicate():
			if not inst.cur_mana_abilities.is_empty() and inst.is_land() \
					and not inst.tapped:
				game.tap_permanent(inst)
		game.players[victim].mana_pool.clear()
		game.log_line("%s loses all unspent mana" % game.players[victim].player_name)

	func describe() -> String:
		return "counters target spell unless its controller pays {X}, and strips their mana if they don't"
