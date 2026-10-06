extends CardScript
## Wall of Diffusion — {1}{R} — Creature — Wall (common, tmp).
## Oracle: Defender (This creature can't attack.)
##         This creature can block creatures with shadow as though it had shadow.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wall of Diffusion", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(0, 5)
	c.with_subtypes(["wall"])
	c.with_keywords([Mtg.Keyword.DEFENDER])
	c.oracle("Defender (This creature can't attack.)\nThis creature can block creatures with shadow as though it had shadow.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
