extends CardScript
## Multani, Maro-Sorcerer — {4}{G}{G} — Legendary Creature — Elemental Sorcerer (rare, ulg).
## Oracle: Shroud (This creature can't be the target of spells or abilities.)
##         Multani's power and toughness are each equal to the total number of cards in all players' hands.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Multani, Maro-Sorcerer", "{4}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["elemental","sorcerer"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("Shroud (This creature can't be the target of spells or abilities.)\nMultani's power and toughness are each equal to the total number of cards in all players' hands.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
