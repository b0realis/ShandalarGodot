extends CardScript
## Scare Tactics — {B} — Instant (common, exo).
## Oracle: Creatures you control get +1/+0 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Scare Tactics", "{B}", Mtg.CardType.INSTANT)
	c.oracle("Creatures you control get +1/+0 until end of turn.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
