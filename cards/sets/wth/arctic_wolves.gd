extends CardScript
## Arctic Wolves — {3}{G}{G} — Creature — Wolf (uncommon, wth).
## Oracle: Cumulative upkeep {2} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)
##         When this creature enters, draw a card.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Arctic Wolves", "{3}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(4, 5)
	c.with_subtypes(["wolf"])
	c.oracle("Cumulative upkeep {2} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)\nWhen this creature enters, draw a card.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
