extends CardScript
## Burning Cloak — {R} — Sorcery (Portal, 1997).
## Oracle: Target creature gets +2/+0 until end of turn. Burning Cloak deals 2 damage to that creature.

func build() -> CardData:
	var c := CardData.new("Burning Cloak", "{R}", Mtg.CardType.SORCERY)
	c.oracle("Target creature gets +2/+0 until end of turn. Burning Cloak deals 2 damage to that creature.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
