extends CardScript
## Keeper of the Beasts — {G}{G} — Creature — Human Wizard (uncommon, exo).
## Oracle: {G}, {T}: Choose target opponent who controls more creatures than you do as you activate this ability. Create a 2/2 green Beast creature token.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Keeper of the Beasts", "{G}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["human","wizard"])
	c.oracle("{G}, {T}: Choose target opponent who controls more creatures than you do as you activate this ability. Create a 2/2 green Beast creature token.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
