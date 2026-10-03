extends CardScript
## Cone of Flame — {3}{R}{R} — Sorcery (uncommon, wth).
## Oracle: Cone of Flame deals 1 damage to any target, 2 damage to another target, and 3 damage to a third target.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cone of Flame", "{3}{R}{R}", Mtg.CardType.SORCERY)
	c.oracle("Cone of Flame deals 1 damage to any target, 2 damage to another target, and 3 damage to a third target.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
