extends CardScript
## Reprocess — {2}{B}{B} — Sorcery (rare, usg).
## Oracle: Sacrifice any number of artifacts, creatures, and/or lands. Draw a card for each permanent sacrificed this way.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Reprocess", "{2}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Sacrifice any number of artifacts, creatures, and/or lands. Draw a card for each permanent sacrificed this way.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
