extends CardScript
## Price of Progress — {1}{R} — Instant (uncommon, exo).
## Oracle: Price of Progress deals damage to each player equal to twice the number of nonbasic lands that player controls.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Price of Progress", "{1}{R}", Mtg.CardType.INSTANT)
	c.oracle("Price of Progress deals damage to each player equal to twice the number of nonbasic lands that player controls.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
