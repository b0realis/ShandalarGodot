extends CardScript
## Wall of Resistance — {1}{W} — Creature — Wall (common, mir).
## Oracle: Defender (This creature can't attack.)
##         Flying
##         At the beginning of each end step, if this creature was dealt damage this turn, put a +0/+1 counter on it.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wall of Resistance", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(0, 3)
	c.with_subtypes(["wall"])
	c.with_keywords([Mtg.Keyword.DEFENDER, Mtg.Keyword.FLYING])
	c.oracle("Defender (This creature can't attack.)\nFlying\nAt the beginning of each end step, if this creature was dealt damage this turn, put a +0/+1 counter on it.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
