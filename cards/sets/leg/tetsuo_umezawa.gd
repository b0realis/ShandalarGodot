extends CardScript
## Tetsuo Umezawa — {U}{B}{R} — Legendary Creature — Human Archer — 3/3 — (leg, rare)
## Oracle: Tetsuo Umezawa can't be the target of Aura spells.
##         {U}{B}{B}{R}, {T}: Destroy target tapped or blocking creature.
##
## Implementation: the CardData "can't be the target of Aura spells" flag
## (TargetSpec refuses aura spells aimed at him, while abilities and
## ordinary spells still work) plus a filtered DestroyEffect whose target
## must be tapped OR currently declared as a blocker.


func build() -> CardData:
	var spec := TargetSpec.creature("target tapped or blocking creature")
	spec.with_game_filter(_tapped_or_blocking)
	return CardData.new("Tetsuo Umezawa", "{U}{B}{R}", Mtg.CardType.CREATURE) \
		.pt(3, 3) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "archer"]) \
		.with_no_aura_targeting() \
		.activated(ActivatedAbility.new(
			"{U}{B}{B}{R}", true, [DestroyEffect.new(spec)],
			"{U}{B}{B}{R}, {T}: Destroy target tapped or blocking creature.")) \
		.oracle("Tetsuo Umezawa can't be the target of Aura spells.\n{U}{B}{B}{R}, "
			+ "{T}: Destroy target tapped or blocking creature.")


static func _tapped_or_blocking(game: MtgGame, inst: CardInstance) -> bool:
	return inst.tapped or game.combat.blocks.has(inst.id)
