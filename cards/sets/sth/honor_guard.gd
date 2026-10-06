extends CardScript
## Honor Guard — {W} — Creature — Human Soldier (common, sth).
## Oracle: {W}: This creature gets +0/+1 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Honor Guard", "{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","soldier"])
	c.oracle("{W}: This creature gets +0/+1 until end of turn.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
