extends CardScript
## Unyaro Griffin — {3}{W} — Creature — Griffin (uncommon, mir).
## Oracle: Flying
##         Sacrifice this creature: Counter target red instant or sorcery spell.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Unyaro Griffin", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["griffin"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nSacrifice this creature: Counter target red instant or sorcery spell.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
