extends CardScript
## Talas Warrior — {1}{U}{U} — Creature — Human Pirate Warrior — 2/2 (Portal Second Age, 1998).
## Oracle: This creature can't be blocked.

func build() -> CardData:
	var c := CardData.new("Talas Warrior", "{1}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","pirate","warrior"])
	c.oracle("This creature can't be blocked.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
