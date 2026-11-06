extends CardScript
## Wall of Glare — {1}{W} — Creature — Wall (common, uds).
## Oracle: Defender (This creature can't attack.)
##         This creature can block any number of creatures.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wall of Glare", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(0, 5)
	c.with_subtypes(["wall"])
	c.with_keywords([Mtg.Keyword.DEFENDER])
	c.oracle("Defender (This creature can't attack.)\nThis creature can block any number of creatures.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
