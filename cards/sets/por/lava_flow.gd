extends CardScript
## Lava Flow — {3}{R}{R} — Sorcery (Portal, 1997).
## Oracle: Destroy target creature or land.

func build() -> CardData:
	var c := CardData.new("Lava Flow", "{3}{R}{R}", Mtg.CardType.SORCERY)
	c.oracle("Destroy target creature or land.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
