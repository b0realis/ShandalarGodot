extends CardScript
## Skyshroud War Beast — {1}{G} — Creature — Beast (rare, exo).
## Oracle: Trample
##         As this creature enters, choose an opponent.
##         Skyshroud War Beast's power and toughness are each equal to the number of nonbasic lands the chosen player controls.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Skyshroud War Beast", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["beast"])
	c.with_keywords([Mtg.Keyword.TRAMPLE])
	c.oracle("Trample\nAs this creature enters, choose an opponent.\nSkyshroud War Beast's power and toughness are each equal to the number of nonbasic lands the chosen player controls.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
