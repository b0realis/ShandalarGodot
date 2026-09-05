extends CardScript
## Goblin Polka Band — {R}{R} — Creature — Goblin — 1/1 — (past, common)
## Oracle: {2}, {T}, Pay {R} for each target: Tap any number of random
##         target creatures. Goblins tapped in this way do not untap during
##         their controllers' next untap phases.
##
## Implementation: X is the number of targets and is paid in RED — the
## ability uses ActivatedAbility.with_colored_x, so three targets really
## cost {2}{R}{R}{R} plus the tap. The targets themselves are "random
## target creatures" ([method TargetSpec.at_random] + [method
## EffectBase.x_targets]): MtgGame rolls X distinct creatures — ANY
## creatures, tapped ones and the Band itself included — as the ability is
## put on the stack (CR 601.2c), logs them, and each one still there on
## resolution is tapped (CR 608.2b: one that left is skipped, the rest go
## on). A rolled creature that is already tapped, or the Band itself once
## its {T} is paid, simply wastes that {R}. Goblins tapped this way skip
## their controller's next untap step ([member CardInstance.skip_next_untap]).
## The caller supplies no targets; the game does, on [member MtgGame.rng].
## With X=0 the ability takes no target and resolves doing nothing.
##
## 1997 vs. Oracle: the 1997 exe rolled the victims on RESOLUTION —
## Manalink, `src/cards/promo.c` `card_goblin_polka_band`: *"Choose the
## targets. This is done during resolution in the original version."* —
## so nobody could respond to the specific creatures picked. The card
## says "target"; targets are chosen when the ability is activated, so
## that is where the roll is made here.


func build() -> CardData:
	return CardData.new("Goblin Polka Band", "{R}{R}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["goblin"]) \
		.activated(ActivatedAbility.new("{X}{2}", true, [PolkaEffect.new()],
			"{2}, {T}, Pay {R} for each target: Tap any number of random target creatures.") \
			.with_colored_x(Mtg.ManaColor.R)) \
		.oracle("{2}, {T}, Pay {R} for each target: Tap any number of random target creatures. Goblins tapped in this way do not untap during their controllers' next untap phases.")


class PolkaEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature("random target creatures").at_random()
		x_targets()

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			target: TargetRef, x_value: int = 0) -> void:
		resolve_multi(game, source, controller, [] if target == null else [target], x_value)

	func resolve_multi(game: MtgGame, _source: CardInstance, _controller: int,
			targets: Array, _x_value: int = 0) -> void:
		for ref in targets:
			var victim := game.find_instance(ref.instance_id)
			if victim == null or victim.zone != Mtg.Zone.BATTLEFIELD or not victim.is_creature():
				continue
			if victim.tapped:
				continue   # already tapped: that {R} bought nothing
			var was_goblin: bool = victim.has_subtype("goblin")
			game.tap_permanent(victim)
			if was_goblin:
				victim.skip_next_untap = true   # "Goblins tapped in this way"

	func describe() -> String:
		return "taps X random target creatures"
