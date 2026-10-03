extends CardScript
## Quirion Elves — {1}{G} — Creature — Elf Druid (common, mir).
## Oracle: As this creature enters, choose a color.
##         {T}: Add {G}.
##         {T}: Add one mana of the chosen color.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Quirion Elves", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["elf","druid"])
	c.oracle("As this creature enters, choose a color.\n{T}: Add {G}.\n{T}: Add one mana of the chosen color.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
