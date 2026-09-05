extends CardScript
## Elephant Graveyard — Land — (arn, rare)
## Oracle: {T}: Add {C}.
##         {T}: Regenerate target Elephant.
##
## Implementation: a colourless mana ability plus a filtered
## RegenerateEffect. The filter reads the LIVE elephant subtype, so it is
## an entirely blank card outside a deck that runs War Mammoth and
## friends — Arabian Nights' tribal joke.


func build() -> CardData:
	return CardData.new("Elephant Graveyard", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.C)) \
		.activated(ActivatedAbility.new(
			"", true,
			[RegenerateEffect.new().target_creature("target Elephant", _is_elephant)],
			"{T}: Regenerate target Elephant.")) \
		.oracle("{T}: Add {C}.\n{T}: Regenerate target Elephant.")


static func _is_elephant(inst: CardInstance) -> bool:
	return inst.has_subtype("elephant")
