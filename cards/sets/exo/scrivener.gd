extends CardScript
## Scrivener — {4}{U} — Creature — Human Wizard (uncommon, exo).
## Oracle: When this creature enters, you may return target instant card from your graveyard to your hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Scrivener", "{4}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","wizard"])
	c.oracle("When this creature enters, you may return target instant card from your graveyard to your hand.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
