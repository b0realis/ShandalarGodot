extends CardScript
## Horn of Greed — {3} — Artifact (rare, sth).
## Oracle: Whenever a player plays a land, that player draws a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Horn of Greed", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("Whenever a player plays a land, that player draws a card.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
