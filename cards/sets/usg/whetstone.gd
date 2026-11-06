extends CardScript
## Whetstone — {3} — Artifact (rare, usg).
## Oracle: {3}: Each player mills two cards.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Whetstone", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("{3}: Each player mills two cards.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
