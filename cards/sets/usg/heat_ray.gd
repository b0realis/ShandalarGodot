extends CardScript
## Heat Ray — {X}{R} — Instant (common, usg).
## Oracle: Heat Ray deals X damage to target creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Heat Ray", "{X}{R}", Mtg.CardType.INSTANT)
	c.oracle("Heat Ray deals X damage to target creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
