extends CardScript
## Retromancer — {2}{R}{R} — Creature — Lizard Shaman (common, usg).
## Oracle: Whenever this creature becomes the target of a spell or ability, this creature deals 3 damage to that spell or ability's controller.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Retromancer", "{2}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["lizard","shaman"])
	c.oracle("Whenever this creature becomes the target of a spell or ability, this creature deals 3 damage to that spell or ability's controller.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
