extends CardScript
## Argothian Enchantress — {1}{G} — Creature — Human Druid (rare, usg).
## Oracle: Shroud (This creature can't be the target of spells or abilities.)
##         Whenever you cast an enchantment spell, draw a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Argothian Enchantress", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(0, 1)
	c.with_subtypes(["human","druid"])
	c.oracle("Shroud (This creature can't be the target of spells or abilities.)\nWhenever you cast an enchantment spell, draw a card.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
