extends CardScript
## Flesh Reaver — {1}{B} — Creature — Phyrexian Horror (uncommon, usg).
## Oracle: Whenever this creature deals damage to a creature or opponent, this creature deals that much damage to you.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Flesh Reaver", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["phyrexian","horror"])
	c.oracle("Whenever this creature deals damage to a creature or opponent, this creature deals that much damage to you.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
