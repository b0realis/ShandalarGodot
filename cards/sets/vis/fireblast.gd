extends CardScript
## Fireblast — {4}{R}{R} — Instant (common, vis).
## Oracle: You may sacrifice two Mountains rather than pay this spell's mana cost.
##         Fireblast deals 4 damage to any target.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fireblast", "{4}{R}{R}", Mtg.CardType.INSTANT)
	c.oracle("You may sacrifice two Mountains rather than pay this spell's mana cost.\nFireblast deals 4 damage to any target.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
