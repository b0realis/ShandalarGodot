extends CardScript
## Rootwater Mystic — {U} — Creature — Merfolk Wizard (common, exo).
## Oracle: {1}{U}: Look at the top card of target player's library.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rootwater Mystic", "{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["merfolk","wizard"])
	c.oracle("{1}{U}: Look at the top card of target player's library.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
