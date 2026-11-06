extends CardScript
## Sporogenesis — {3}{G} — Enchantment (rare, usg).
## Oracle: At the beginning of your upkeep, you may put a fungus counter on target nontoken creature.
##         Whenever a creature with a fungus counter on it dies, create a 1/1 green Saproling creature token for each fungus counter on that creature.
##         When this enchantment leaves the battlefield, remove all fungus counters from all creatures.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sporogenesis", "{3}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, you may put a fungus counter on target nontoken creature.\nWhenever a creature with a fungus counter on it dies, create a 1/1 green Saproling creature token for each fungus counter on that creature.\nWhen this enchantment leaves the battlefield, remove all fungus counters from all creatures.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
