extends CardScript
## Mishra's Workshop — Land — (atq, rare)
## Oracle: {T}: Add {C}{C}{C}. Spend this mana only to cast artifact spells.
##
## Implementation: the pool now keeps RESTRICTED mana in its own keyed
## bucket (CR 106.6) — three colorless that only an artifact spell may
## spend, and that the payment routine spends FIRST so it isn't wasted.


func build() -> CardData:
	return CardData.new("Mishra's Workshop", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.C, 3).with_restriction("artifact")) \
		.oracle("{T}: Add {C}{C}{C}. Spend this mana only to cast artifact spells.")
