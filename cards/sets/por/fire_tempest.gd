extends CardScript
## Fire Tempest — {5}{R}{R} — Sorcery (Portal, 1997).
## Oracle: Fire Tempest deals 6 damage to each creature and each player.

func build() -> CardData:
	var c := CardData.new("Fire Tempest", "{5}{R}{R}", Mtg.CardType.SORCERY)
	c.oracle("Fire Tempest deals 6 damage to each creature and each player.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
