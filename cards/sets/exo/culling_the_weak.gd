extends CardScript
## Culling the Weak — {B} — Instant (common, exo).
## Oracle: As an additional cost to cast this spell, sacrifice a creature.
##         Add {B}{B}{B}{B}.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Culling the Weak", "{B}", Mtg.CardType.INSTANT)
	c.oracle("As an additional cost to cast this spell, sacrifice a creature.\nAdd {B}{B}{B}{B}.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
