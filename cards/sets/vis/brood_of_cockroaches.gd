extends CardScript
## Brood of Cockroaches — {1}{B} — Creature — Insect (uncommon, vis).
## Oracle: When this creature is put into your graveyard from the battlefield, at the beginning of the next end step, you lose 1 life and return this card to your hand.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Brood of Cockroaches", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["insect"])
	c.oracle("When this creature is put into your graveyard from the battlefield, at the beginning of the next end step, you lose 1 life and return this card to your hand.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
