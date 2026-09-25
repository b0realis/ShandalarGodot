extends CardScript
## Dakmor Plague — {3}{B}{B} — Sorcery (Portal Second Age, 1998).
## Oracle: Dakmor Plague deals 3 damage to each creature and each player.

func build() -> CardData:
	var c := CardData.new("Dakmor Plague", "{3}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Dakmor Plague deals 3 damage to each creature and each player.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
