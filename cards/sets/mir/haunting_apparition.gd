extends CardScript
## Haunting Apparition — {1}{U}{B} — Creature — Spirit (uncommon, mir).
## Oracle: Flying
##         As this creature enters, choose an opponent.
##         Haunting Apparition's power is equal to 1 plus the number of green creature cards in the chosen player's graveyard.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Haunting Apparition", "{1}{U}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["spirit"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nAs this creature enters, choose an opponent.\nHaunting Apparition's power is equal to 1 plus the number of green creature cards in the chosen player's graveyard.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
