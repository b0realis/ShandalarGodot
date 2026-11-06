extends CardScript
## Priest of Gix — {2}{B} — Creature — Phyrexian Human Cleric Minion (uncommon, usg).
## Oracle: When this creature enters, add {B}{B}{B}.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Priest of Gix", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["phyrexian","human","cleric","minion"])
	c.oracle("When this creature enters, add {B}{B}{B}.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
