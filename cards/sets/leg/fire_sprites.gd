extends CardScript
## Fire Sprites — {1}{G} — Creature — Faerie — 1/1 — (leg, common)
## Oracle: Flying
##         {G}, {T}: Add {R}.
##
## Implementation: printed flying plus a COSTED mana ability that filters
## green into red (Apprentice Wizard's shape). A 1/1 flier that fixes a
## red splash in a green deck — Legends' idea of a mana elf.


func build() -> CardData:
	return CardData.new("Fire Sprites", "{1}{G}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["faerie"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.mana(ManaAbility.new(Mtg.ManaColor.R).with_mana_cost("{G}")) \
		.oracle("Flying\n{G}, {T}: Add {R}.")
