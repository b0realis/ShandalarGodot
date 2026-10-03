extends CardScript
## Meddle — {1}{U} — Instant (uncommon, mir).
## Oracle: If target spell has only one target and that target is a creature, change that spell's target to another creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Meddle", "{1}{U}", Mtg.CardType.INSTANT)
	c.oracle("If target spell has only one target and that target is a creature, change that spell's target to another creature.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
