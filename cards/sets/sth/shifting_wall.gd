extends CardScript
## Shifting Wall — {X} — Artifact Creature — Wall (uncommon, sth).
## Oracle: Defender (This creature can't attack.)
##         This creature enters with X +1/+1 counters on it.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shifting Wall", "{X}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(0, 0)
	c.with_subtypes(["wall"])
	c.with_keywords([Mtg.Keyword.DEFENDER])
	c.oracle("Defender (This creature can't attack.)\nThis creature enters with X +1/+1 counters on it.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
