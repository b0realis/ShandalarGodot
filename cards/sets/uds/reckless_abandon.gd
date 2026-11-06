extends CardScript
## Reckless Abandon — {R} — Sorcery (common, uds).
## Oracle: As an additional cost to cast this spell, sacrifice a creature.
##         Reckless Abandon deals 4 damage to any target.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Reckless Abandon", "{R}", Mtg.CardType.SORCERY)
	c.oracle("As an additional cost to cast this spell, sacrifice a creature.\nReckless Abandon deals 4 damage to any target.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
