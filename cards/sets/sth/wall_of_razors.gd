extends CardScript
## Wall of Razors — {1}{R} — Creature — Wall (uncommon, sth).
## Oracle: Defender (This creature can't attack.)
##         First strike
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wall of Razors", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(4, 1)
	c.with_subtypes(["wall"])
	c.with_keywords([Mtg.Keyword.DEFENDER, Mtg.Keyword.FIRST_STRIKE])
	c.oracle("Defender (This creature can't attack.)\nFirst strike")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
