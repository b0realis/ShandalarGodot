extends CardScript
## Keeper of the Dead — {B}{B} — Creature — Human Wizard (uncommon, exo).
## Oracle: {B}, {T}: Choose target opponent who has at least two fewer creature cards in their graveyard than you do as you activate this ability. Destroy target nonblack creature that player controls.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Keeper of the Dead", "{B}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["human","wizard"])
	c.oracle("{B}, {T}: Choose target opponent who has at least two fewer creature cards in their graveyard than you do as you activate this ability. Destroy target nonblack creature that player controls.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
