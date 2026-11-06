extends CardScript
## Solidarity — {3}{W} — Instant (common, uds).
## Oracle: Creatures you control get +0/+5 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Solidarity", "{3}{W}", Mtg.CardType.INSTANT)
	c.oracle("Creatures you control get +0/+5 until end of turn.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
