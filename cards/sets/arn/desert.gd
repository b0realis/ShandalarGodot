extends CardScript
## Desert — Land — Desert — (arn, common)
## Oracle: {T}: Add {C}.
##         {T}: This land deals 1 damage to target attacking creature.
##         Activate only during the end of combat step.
##
## Implementation: a colourless mana ability plus a step-restricted ping
## (ActivatedAbility.during_step) aimed at a declared attacker. Firing at
## END OF COMBAT means it finishes off anything a blocker wounded — and,
## being a land, it does so for free every turn. Its Desert subtype is
## what Desert Nomads' desertwalk and damage shield read.


func build() -> CardData:
	var shot := DamageEffect.new(1)
	shot.target_spec = TargetSpec.creature("target attacking creature") \
		.with_game_filter(_is_attacking)
	return CardData.new("Desert", "", Mtg.CardType.LAND) \
		.with_subtypes(["desert"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.C)) \
		.activated(ActivatedAbility.new(
			"", true, [shot],
			"{T}: Desert deals 1 damage to target attacking creature. Activate only "
			+ "during the end of combat step.") \
			.during_step(Mtg.Step.COMBAT_END)) \
		.oracle("{T}: Add {C}.\n{T}: This land deals 1 damage to target attacking "
			+ "creature. Activate only during the end of combat step.")


static func _is_attacking(game: MtgGame, inst: CardInstance) -> bool:
	return game.combat.attackers.has(inst.id)
