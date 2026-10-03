extends CardScript
## Mana Web — {3} — Artifact (rare, wth).
## Oracle: Whenever a land an opponent controls is tapped for mana, tap all lands that player controls that could produce any type of mana that land could produce.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mana Web", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("Whenever a land an opponent controls is tapped for mana, tap all lands that player controls that could produce any type of mana that land could produce.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
