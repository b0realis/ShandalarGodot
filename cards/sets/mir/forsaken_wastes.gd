extends CardScript
## Forsaken Wastes — {2}{B} — World Enchantment (rare, mir).
## Oracle: Players can't gain life.
##         At the beginning of each player's upkeep, that player loses 1 life.
##         Whenever this enchantment becomes the target of a spell, that spell's controller loses 5 life.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Forsaken Wastes", "{2}{B}", Mtg.CardType.ENCHANTMENT)
	c.supertypes |= Mtg.Supertype.WORLD
	c.oracle("Players can't gain life.\nAt the beginning of each player's upkeep, that player loses 1 life.\nWhenever this enchantment becomes the target of a spell, that spell's controller loses 5 life.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
