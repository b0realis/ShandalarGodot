extends CardScript
## Wall of Nets — {1}{W}{W} — Creature — Wall (rare, exo).
## Oracle: Defender (This creature can't attack.)
##         At end of combat, exile all creatures blocked by this creature.
##         When this creature leaves the battlefield, return all cards exiled with it to the battlefield under their owners' control.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wall of Nets", "{1}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(0, 7)
	c.with_subtypes(["wall"])
	c.with_keywords([Mtg.Keyword.DEFENDER])
	c.oracle("Defender (This creature can't attack.)\nAt end of combat, exile all creatures blocked by this creature.\nWhen this creature leaves the battlefield, return all cards exiled with it to the battlefield under their owners' control.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
