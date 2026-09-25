extends CardScript
## Goblin War Strike — {R} — Sorcery (Portal Second Age, 1998).
## Oracle: Goblin War Strike deals damage to target player or planeswalker equal to the number of Goblins you control.

func build() -> CardData:
	var c := CardData.new("Goblin War Strike", "{R}", Mtg.CardType.SORCERY)
	c.oracle("Goblin War Strike deals damage to target player or planeswalker equal to the number of Goblins you control.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
