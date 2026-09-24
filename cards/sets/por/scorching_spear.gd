extends CardScript
## Scorching Spear — {R} — Sorcery (Portal, 1997).
## Oracle: Scorching Spear deals 1 damage to any target.

func build() -> CardData:
	var c := CardData.new("Scorching Spear", "{R}", Mtg.CardType.SORCERY)
	c.oracle("Scorching Spear deals 1 damage to any target.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
