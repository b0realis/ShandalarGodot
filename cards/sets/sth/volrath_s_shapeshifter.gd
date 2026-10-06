extends CardScript
## Volrath's Shapeshifter — {1}{U}{U} — Creature — Phyrexian Shapeshifter (rare, sth).
## Oracle: As long as the top card of your graveyard is a creature card, this creature has the full text of that card and has the text "{2}: Discard a card." (This creature has that card's name, mana cost, color, types, abilities, power, and toughness.)
##         {2}: Discard a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Volrath's Shapeshifter", "{1}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(0, 1)
	c.with_subtypes(["phyrexian","shapeshifter"])
	c.oracle("As long as the top card of your graveyard is a creature card, this creature has the full text of that card and has the text \"{2}: Discard a card.\" (This creature has that card's name, mana cost, color, types, abilities, power, and toughness.)\n{2}: Discard a card.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
