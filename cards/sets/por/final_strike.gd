extends CardScript
## Final Strike — {2}{B}{B} — Sorcery (Portal, 1997).
## Oracle: As an additional cost to cast this spell, sacrifice a creature.
## Oracle: Final Strike deals damage to target opponent or planeswalker equal to the sacrificed creature's power.

func build() -> CardData:
	var c := CardData.new("Final Strike", "{2}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("As an additional cost to cast this spell, sacrifice a creature.\nFinal Strike deals damage to target opponent or planeswalker equal to the sacrificed creature's power.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
