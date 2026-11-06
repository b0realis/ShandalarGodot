extends CardScript
## Rain of Filth — {B} — Instant (uncommon, usg).
## Oracle: Until end of turn, lands you control gain "Sacrifice this land: Add {B}."
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rain of Filth", "{B}", Mtg.CardType.INSTANT)
	c.oracle("Until end of turn, lands you control gain \"Sacrifice this land: Add {B}.\"")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
