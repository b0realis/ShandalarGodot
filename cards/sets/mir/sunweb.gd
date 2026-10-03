extends CardScript
## Sunweb — {3}{W} — Creature — Wall (rare, mir).
## Oracle: Defender (This creature can't attack.)
##         Flying
##         This creature can't block creatures with power 2 or less.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sunweb", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(5, 6)
	c.with_subtypes(["wall"])
	c.with_keywords([Mtg.Keyword.DEFENDER, Mtg.Keyword.FLYING])
	c.oracle("Defender (This creature can't attack.)\nFlying\nThis creature can't block creatures with power 2 or less.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
