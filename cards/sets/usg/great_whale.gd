extends CardScript
## Great Whale — {5}{U}{U} — Creature — Whale (rare, usg).
## Oracle: When this creature enters, untap up to seven lands.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Great Whale", "{5}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(5, 5)
	c.with_subtypes(["whale"])
	c.oracle("When this creature enters, untap up to seven lands.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
