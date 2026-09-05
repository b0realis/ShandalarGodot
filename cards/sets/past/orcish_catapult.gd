extends CardScript
## Orcish Catapult — {X}{R}{R} — Instant — (past, common)
## Oracle: Randomly distribute X -0/-1 counters among a random number of
##         random target creatures.
##
## Implementation: "a random number of random target creatures", divided
## ([method TargetSpec.at_random] with the count rolled too, plus [method
## EffectBase.divided_among] on X): as the spell is cast (CR 601.2c),
## MtgGame rolls HOW MANY creatures share the load (1..the number on the
## board, and never more than X — every target must get at least one
## counter, CR 601.2d), then WHICH, then drops the X counters into their
## hands at random (each at least one), and logs the lot. On resolution
## each creature still there gets its share as -0/-1 counters, which the
## continuous pipeline reads by name; one that left takes its share with
## it (CR 608.2b — the division was fixed when the spell was cast), and
## the spell fizzles only when every target is gone.
##
## X=0 has nothing to distribute, so it takes no target and resolves doing
## nothing; X>0 with no creature on the battlefield cannot be cast at all
## (a target is required — the 1997 exe's ANY-target test, and mage-go's
## `TargetOneToXCreatures`). The caller supplies no targets; the game
## does, on [member MtgGame.rng], so a seeded duel replays the volley.


func build() -> CardData:
	return CardData.new("Orcish Catapult", "{X}{R}{R}", Mtg.CardType.INSTANT) \
		.spell(CatapultEffect.new()) \
		.oracle("Randomly distribute X -0/-1 counters among a random number of random target creatures.")


class CatapultEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature(
			"a random number of random target creatures").at_random(true)
		divided_among(-1)

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			target: TargetRef, x_value: int = 0) -> void:
		resolve_multi(game, source, controller, [] if target == null else [target], x_value)

	func resolve_multi(game: MtgGame, _source: CardInstance, _controller: int,
			targets: Array, _x_value: int = 0) -> void:
		for ref in targets:
			var victim := game.find_instance(ref.instance_id)
			if victim == null or victim.zone != Mtg.Zone.BATTLEFIELD or not victim.is_creature():
				continue
			if ref.amount > 0:
				game.add_counters(victim, "-0/-1", ref.amount)

	func describe() -> String:
		return "randomly distributes X -0/-1 counters among a random number of random target creatures"
