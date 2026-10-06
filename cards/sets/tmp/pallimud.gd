extends CardScript
## Pallimud — {2}{R} — Creature — Beast (rare, tmp).
## Oracle: As this creature enters, choose an opponent.
##         Pallimud's power is equal to the number of tapped lands the chosen player controls.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Pallimud", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(0, 3)
	c.with_subtypes(["beast"])
	c.oracle("As this creature enters, choose an opponent.\nPallimud's power is equal to the number of tapped lands the chosen player controls.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
