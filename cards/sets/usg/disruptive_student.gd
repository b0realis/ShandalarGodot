extends CardScript
## Disruptive Student — {2}{U} — Creature — Human Wizard (common, usg).
## Oracle: {T}: Counter target spell unless its controller pays {1}.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Disruptive Student", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","wizard"])
	c.oracle("{T}: Counter target spell unless its controller pays {1}.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
