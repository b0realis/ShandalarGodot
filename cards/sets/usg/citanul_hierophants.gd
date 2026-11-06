extends CardScript
## Citanul Hierophants — {3}{G} — Creature — Human Druid (rare, usg).
## Oracle: Creatures you control have "{T}: Add {G}."
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Citanul Hierophants", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["human","druid"])
	c.oracle("Creatures you control have \"{T}: Add {G}.\"")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
