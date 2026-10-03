extends CardScript
## Urborg Stalker — {3}{B} — Creature — Horror (rare, wth).
## Oracle: At the beginning of each player's upkeep, if that player controls a nonblack, nonland permanent, this creature deals 1 damage to that player.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Urborg Stalker", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 4)
	c.with_subtypes(["horror"])
	c.oracle("At the beginning of each player's upkeep, if that player controls a nonblack, nonland permanent, this creature deals 1 damage to that player.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
