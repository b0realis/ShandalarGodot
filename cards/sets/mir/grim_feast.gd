extends CardScript
## Grim Feast — {1}{B}{G} — Enchantment (rare, mir).
## Oracle: At the beginning of your upkeep, this enchantment deals 1 damage to you.
##         Whenever a creature is put into an opponent's graveyard from the battlefield, you gain life equal to its toughness.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Grim Feast", "{1}{B}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, this enchantment deals 1 damage to you.\nWhenever a creature is put into an opponent's graveyard from the battlefield, you gain life equal to its toughness.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
