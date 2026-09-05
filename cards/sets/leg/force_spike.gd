extends CardScript
## Force Spike — {U} — Instant — (leg, common)
## Oracle: Counter target spell unless its controller pays {1}.
##
## Implementation: a card-local effect. On resolution the spell's
## CONTROLLER (from its stack item, not its owner) is offered {1} through
## MtgGame.try_pay — which spends floating mana first and then auto-taps
## lands, so "tapped out" really means countered. Declining or being
## unable to pay counters the spell (CR 701.5a).


func build() -> CardData:
	return CardData.new("Force Spike", "{U}", Mtg.CardType.INSTANT) \
		.spell(ForceSpikeEffect.new()) \
		.oracle("Counter target spell unless its controller pays {1}.")


class ForceSpikeEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.spell()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var spell := game.find_instance(target.instance_id)
		if spell == null or spell.zone != Mtg.Zone.STACK:
			return
		var caster := -1
		for item in game.stack:
			if item.kind == Mtg.StackKind.SPELL and item.card == spell:
				caster = item.controller
				break
		if caster == -1:
			return
		var toll := ManaCost.parse("{1}")
		if game.can_afford_cost(caster, toll) \
				and game.agents[caster].choose_yes_no(game, caster,
					"Pay {1} or %s is countered?" % spell.data.card_name, true) \
				and game.try_pay(caster, toll):
			game.log_line("%s pays {1} and keeps %s" % [
				game.players[caster].player_name, spell.data.card_name])
			return
		game.counter_spell(spell)

	func describe() -> String:
		return "counters target spell unless its controller pays {1}"
