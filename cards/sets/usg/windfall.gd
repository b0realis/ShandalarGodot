extends CardScript
## Windfall — {2}{U} — Sorcery (uncommon, usg).
## Oracle: Each player discards their hand, then draws cards equal to the greatest number of cards a player discarded this way.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Windfall", "{2}{U}", Mtg.CardType.SORCERY)
	c.oracle("Each player discards their hand, then draws cards equal to the greatest number of cards a player discarded this way.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
