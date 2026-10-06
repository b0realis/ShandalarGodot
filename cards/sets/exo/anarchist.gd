extends CardScript
## Anarchist — {4}{R} — Creature — Human Wizard (common, exo).
## Oracle: When this creature enters, you may return target sorcery card from your graveyard to your hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Anarchist", "{4}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","wizard"])
	c.oracle("When this creature enters, you may return target sorcery card from your graveyard to your hand.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
