extends CardScript
## Goblin War Cry — {2}{R} — Sorcery (Portal Second Age, 1998).
## Oracle: Target opponent chooses a creature they control. Other creatures they control can't block this turn.

func build() -> CardData:
	var c := CardData.new("Goblin War Cry", "{2}{R}", Mtg.CardType.SORCERY)
	c.oracle("Target opponent chooses a creature they control. Other creatures they control can't block this turn.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
