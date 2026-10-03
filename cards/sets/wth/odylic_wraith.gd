extends CardScript
## Odylic Wraith — {3}{B} — Creature — Wraith (uncommon, wth).
## Oracle: Swampwalk (This creature can't be blocked as long as defending player controls a Swamp.)
##         Whenever this creature deals damage to a player, that player discards a card.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Odylic Wraith", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["wraith"])
	c.with_landwalk(["swamp"])
	c.oracle("Swampwalk (This creature can't be blocked as long as defending player controls a Swamp.)\nWhenever this creature deals damage to a player, that player discards a card.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
