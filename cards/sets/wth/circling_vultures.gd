extends CardScript
## Circling Vultures — {B} — Creature — Bird (uncommon, wth).
## Oracle: Flying
##         You may discard this card any time you could cast an instant.
##         At the beginning of your upkeep, sacrifice this creature unless you exile the top creature card of your graveyard.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Circling Vultures", "{B}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["bird"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nYou may discard this card any time you could cast an instant.\nAt the beginning of your upkeep, sacrifice this creature unless you exile the top creature card of your graveyard.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
