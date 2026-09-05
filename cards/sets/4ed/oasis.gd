extends CardScript
## Oasis — Land — (4ed, uncommon)
## Oracle: {T}: Prevent the next 1 damage that would be dealt to target
##         creature this turn.
##
## Implementation: a land whose only ability is a shield — the same
## amount-based prevention pool Samite Healer fills, so it stacks with
## itself and with every other prevention effect.


func build() -> CardData:
	return CardData.new("Oasis", "", Mtg.CardType.LAND) \
		.activated(ActivatedAbility.new("", true,
			[PreventDamageEffect.new(1).target_creature()],
			"{T}: Prevent the next 1 damage that would be dealt to target creature this turn.")) \
		.oracle("{T}: Prevent the next 1 damage that would be dealt to target creature this turn.")
