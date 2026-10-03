extends CardScript
## Jolt — {2}{U} — Instant (common, mir).
## Oracle: You may tap or untap target artifact, creature, or land.
##         Draw a card at the beginning of the next turn's upkeep.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Jolt", "{2}{U}", Mtg.CardType.INSTANT)
	c.oracle("You may tap or untap target artifact, creature, or land.\nDraw a card at the beginning of the next turn's upkeep.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
