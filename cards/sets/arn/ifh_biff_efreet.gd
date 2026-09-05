extends CardScript
## Ifh-Bíff Efreet — {2}{G}{G} — Creature — Efreet — 3/3 — (arn, rare)
## Oracle: Flying
##         {G}: This creature deals 1 damage to each creature with flying
##         and each player. Any player may activate this ability.
##
## Implementation: printed flying plus a symmetric sweeper marked
## .anyone_activated() — the engine drops the control requirement, so an
## opponent with a Forest can point the Efreet's own ability at its
## controller. Six activations kill everybody, including the Efreet.


func build() -> CardData:
	return CardData.new("Ifh-Bíff Efreet", "{2}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(3, 3) \
		.with_subtypes(["efreet"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.activated(ActivatedAbility.new(
			"{G}", false,
			[DamageAllEffect.new(1, "each creature with flying", _has_flying) \
				.and_each_player()],
			"{G}: Ifh-Bíff Efreet deals 1 damage to each creature with flying and "
			+ "each player. Any player may activate this ability.") \
			.anyone_activated()) \
		.oracle("Flying\n{G}: This creature deals 1 damage to each creature with "
			+ "flying and each player. Any player may activate this ability.")


static func _has_flying(inst: CardInstance) -> bool:
	return inst.has_keyword(Mtg.Keyword.FLYING)
