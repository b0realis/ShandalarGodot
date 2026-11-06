extends CardScript
## Stern Proctor — {U}{U} — Creature — Human Wizard (uncommon, usg).
## Oracle: When this creature enters, return target artifact or enchantment to its owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Stern Proctor", "{U}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["human","wizard"])
	c.oracle("When this creature enters, return target artifact or enchantment to its owner's hand.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
