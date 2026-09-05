extends CardScript
## Faerie Dragon — {2}{G}{G} — Creature — Dragon — 1/3 — (past, common)
## Oracle: Flying
##         {1}{G}{G}: Play a random effect.
##
## `Duel.hlp`, MicroProse Clarification: *"If the effect requires a target,
## the targeting is also random."* — and in the 1997 game (the routine at
## 0x4735C0, `src/cards/promo.c` `card_faerie_dragon`) EVERY one of the
## twenty effects takes a creature: Berserk, Tawnos's Wand, Bloodlust, the
## five Laces, Lightning Bolt, Jump, Giant Growth, Helm of Chatzuk, Hurr
## Jackal, Twiddle, Pradesh Gypsies, Unsummon, Rod of Ruin, Sorceress
## Queen, Swords to Plowshares, Orcish Catapult (one -0/-1 counter). The
## exe rolls the creature AS THE ABILITY IS ACTIVATED — any creature, the
## Dragon itself included — puts it on the ability as its one target, and
## cancels on resolution if it is no longer a legal creature.
##
## Implementation: the ability's effect names a "random target creature"
## through [method TargetSpec.at_random]: MtgGame rolls the creature when
## the ability is put on the stack (CR 601.2c), logs it, and the ability
## fizzles if it is gone by resolution (CR 608.2b) — exactly the exe's
## cancel. Resolution then rolls the effect on
## [RandomCreatureEffectTable] (the twenty above, in `@FAERIEDRAGON_MESSAGES`
## order) and plays it on that creature. A caller may not supply a target;
## the game does, on [member MtgGame.rng], so a seeded duel replays it.
##
## The exe rolled the effect index at activation and kept it hidden until
## resolution; rolling it at resolution instead is invisible to both
## players (nothing could read or respond to it) and keeps stack items
## carrying only targets and X.


func build() -> CardData:
	return CardData.new("Faerie Dragon", "{2}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(1, 3) \
		.with_subtypes(["dragon"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.activated(ActivatedAbility.new("{1}{G}{G}", false, [RandomEffectPlay.new()],
			"{1}{G}{G}: Play a random effect.")) \
		.oracle("Flying\n{1}{G}{G}: Play a random effect.")


class RandomEffectPlay extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature("random target creature").at_random()

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		if target == null:
			return
		var victim := game.find_instance(target.instance_id)
		if victim == null or victim.zone != Mtg.Zone.BATTLEFIELD or not victim.is_creature():
			return
		RandomCreatureEffectTable.play_random(game, source, controller, victim)

	func describe() -> String:
		return "plays a random effect on a random creature"
