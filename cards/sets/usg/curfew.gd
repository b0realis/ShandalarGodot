extends CardScript
## Curfew — {U} — Instant (common, usg).
## Oracle: Each player returns a creature they control to its owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Curfew", "{U}", Mtg.CardType.INSTANT)
	c.oracle("Each player returns a creature they control to its owner's hand.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
