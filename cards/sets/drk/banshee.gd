extends CardScript
## Banshee — {2}{B}{B} — Creature — Spirit — 0/1 — (drk, uncommon)
## Oracle: {X}, {T}: This creature deals half X damage, rounded down, to any
##         target, and half X damage, rounded up, to you.
##
## Implementation: one ability, two damage events from the same source. The
## halves are the printed rounding — down for the victim, up for you — so an
## ODD X always costs you one more than it costs them, and X=1 is a pure
## point of self-damage. The two events are separate packets, so a Circle of
## Protection: Black answers either half on its own.
##
## `@BANSHEE`, `Program/promptsX2.txt:18`, is `Select target creature or
## player.` — the original's "any target".


func build() -> CardData:
	return CardData.new("Banshee", "{2}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(0, 1) \
		.with_subtypes(["spirit"]) \
		.activated(ActivatedAbility.new("{X}", true, [WailEffect.new()],
			"{X}, {T}: This creature deals half X damage, rounded down, to any target, and half X damage, rounded up, to you.")) \
		.oracle("{X}, {T}: This creature deals half X damage, rounded down, to any "
			+ "target, and half X damage, rounded up, to you.")


class WailEffect extends EffectBase:
	func _init() -> void:
		# `@BANSHEE` entry 1, Program/promptsX2.txt:20.
		target_spec = TargetSpec.any_target()

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			target: TargetRef, x_value: int = 0) -> void:
		if x_value <= 0:
			return
		var theirs: int = x_value / 2          # rounded down
		var mine: int = x_value - theirs       # rounded up
		if theirs > 0:
			game.deal_damage(source, target, theirs)
		if mine > 0:
			game.deal_damage(source, TargetRef.player(controller), mine)

	func describe() -> String:
		return "deals half X to any target and half X to you"
