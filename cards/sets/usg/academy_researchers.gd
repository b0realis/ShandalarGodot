extends CardScript
## Academy Researchers — {1}{U}{U} — Creature — Human Wizard (uncommon, usg).
## Oracle: When this creature enters, you may put an Aura card from your hand onto the battlefield attached to this creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Academy Researchers", "{1}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","wizard"])
	c.oracle("When this creature enters, you may put an Aura card from your hand onto the battlefield attached to this creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
