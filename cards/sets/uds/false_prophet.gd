extends CardScript
## False Prophet — {2}{W}{W} — Creature — Human Cleric (rare, uds).
## Oracle: When this creature dies, exile all creatures.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("False Prophet", "{2}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","cleric"])
	c.oracle("When this creature dies, exile all creatures.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
