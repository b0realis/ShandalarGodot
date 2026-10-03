extends CardScript
## Coral Fighters — {1}{U} — Creature — Merfolk Soldier (uncommon, mir).
## Oracle: Whenever this creature attacks and isn't blocked, look at the top card of defending player's library. You may put that card on the bottom of that player's library.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Coral Fighters", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["merfolk","soldier"])
	c.oracle("Whenever this creature attacks and isn't blocked, look at the top card of defending player's library. You may put that card on the bottom of that player's library.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
