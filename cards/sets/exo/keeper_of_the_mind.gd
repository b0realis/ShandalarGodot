extends CardScript
## Keeper of the Mind — {U}{U} — Creature — Human Wizard (uncommon, exo).
## Oracle: {U}, {T}: Choose target opponent who has at least two more cards in hand than you do as you activate this ability. Draw a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Keeper of the Mind", "{U}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["human","wizard"])
	c.oracle("{U}, {T}: Choose target opponent who has at least two more cards in hand than you do as you activate this ability. Draw a card.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
