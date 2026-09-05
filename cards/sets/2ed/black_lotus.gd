extends CardScript
## Black Lotus — {0} — Artifact (2ed, rare; Power Nine)
## Oracle: {T}, Sacrifice this artifact: Add three mana of any one color.
##
## Implementation: five ManaAbility options (one per color, chosen by
## ability index in tap_for_mana), each producing three mana and marked
## with_sacrifice() — the engine taps, adds the mana, then puts the Lotus
## in the graveyard as part of the cost. Costs {0}, so it can be cast off
## an empty pool. Restricted in Shandalar's deck rules (deck validation —
## docs/ROADMAP.md).


func build() -> CardData:
	return CardData.new("Black Lotus", "{0}", Mtg.CardType.ARTIFACT) \
		.mana(ManaAbility.new(Mtg.ManaColor.W, 3).with_sacrifice()) \
		.mana(ManaAbility.new(Mtg.ManaColor.U, 3).with_sacrifice()) \
		.mana(ManaAbility.new(Mtg.ManaColor.B, 3).with_sacrifice()) \
		.mana(ManaAbility.new(Mtg.ManaColor.R, 3).with_sacrifice()) \
		.mana(ManaAbility.new(Mtg.ManaColor.G, 3).with_sacrifice()) \
		.oracle("{T}, Sacrifice this artifact: Add three mana of any one color.")
