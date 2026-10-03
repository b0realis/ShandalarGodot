extends CardScript
## Hall of Gemstone — {1}{G}{G} — World Enchantment (rare, mir).
## Oracle: At the beginning of each player's upkeep, that player chooses a color. Until end of turn, lands tapped for mana produce mana of the chosen color instead of any other color.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hall of Gemstone", "{1}{G}{G}", Mtg.CardType.ENCHANTMENT)
	c.supertypes |= Mtg.Supertype.WORLD
	c.oracle("At the beginning of each player's upkeep, that player chooses a color. Until end of turn, lands tapped for mana produce mana of the chosen color instead of any other color.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
