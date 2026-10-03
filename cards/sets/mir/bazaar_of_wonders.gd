extends CardScript
## Bazaar of Wonders — {3}{U}{U} — World Enchantment (rare, mir).
## Oracle: When this enchantment enters, exile all graveyards.
##         Whenever a player casts a spell, counter it if a card with the same name is in a graveyard or a nontoken permanent with the same name is on the battlefield.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bazaar of Wonders", "{3}{U}{U}", Mtg.CardType.ENCHANTMENT)
	c.supertypes |= Mtg.Supertype.WORLD
	c.oracle("When this enchantment enters, exile all graveyards.\nWhenever a player casts a spell, counter it if a card with the same name is in a graveyard or a nontoken permanent with the same name is on the battlefield.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
