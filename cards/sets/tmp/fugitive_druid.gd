extends CardScript
## Fugitive Druid — {3}{G} — Creature — Human Druid (rare, tmp).
## Oracle: Whenever this creature becomes the target of an Aura spell, you draw a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fugitive Druid", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["human","druid"])
	c.oracle("Whenever this creature becomes the target of an Aura spell, you draw a card.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
