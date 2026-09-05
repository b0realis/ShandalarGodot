extends CardScript
## Birds of Paradise — {G} — Creature — Bird — 0/1 (2ed, rare)
## Oracle: Flying
##         {T}: Add one mana of any color.
##
## Implementation: five ManaAbility options (one per color), chosen by the
## ability_index argument of MtgGame.tap_for_mana — the same pattern dual
## lands use (see tundra.gd). Summoning sickness applies (creature).


func build() -> CardData:
	return CardData.new("Birds of Paradise", "{G}", Mtg.CardType.CREATURE) \
		.pt(0, 1) \
		.with_subtypes(["bird"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.mana(ManaAbility.new(Mtg.ManaColor.W)) \
		.mana(ManaAbility.new(Mtg.ManaColor.U)) \
		.mana(ManaAbility.new(Mtg.ManaColor.B)) \
		.mana(ManaAbility.new(Mtg.ManaColor.R)) \
		.mana(ManaAbility.new(Mtg.ManaColor.G)) \
		.oracle("Flying\n{T}: Add one mana of any color.")
