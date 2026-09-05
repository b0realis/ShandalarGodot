extends CardScript
## Air Elemental — {3}{U}{U} — Creature — Elemental — 4/4 (Alpha, uncommon)
## Oracle: Flying
##
## Implementation: printed FLYING keyword; combat legality (only flyers and
## reach can block it) is enforced by CombatState.block_illegality.


func build() -> CardData:
	return CardData.new("Air Elemental", "{3}{U}{U}", Mtg.CardType.CREATURE) \
		.pt(4, 4) \
		.with_subtypes(["elemental"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.oracle("Flying")
