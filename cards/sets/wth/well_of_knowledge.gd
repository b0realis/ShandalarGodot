extends CardScript
## Well of Knowledge — {3} — Artifact (rare, wth).
## Oracle: {2}: Draw a card. Any player may activate this ability but only during their draw step.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Well of Knowledge", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("{2}: Draw a card. Any player may activate this ability but only during their draw step.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
