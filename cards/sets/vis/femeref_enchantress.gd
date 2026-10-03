extends CardScript
## Femeref Enchantress — {G}{W} — Creature — Human Druid (rare, vis).
## Oracle: Whenever an enchantment is put into a graveyard from the battlefield, draw a card.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Femeref Enchantress", "{G}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["human","druid"])
	c.oracle("Whenever an enchantment is put into a graveyard from the battlefield, draw a card.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
