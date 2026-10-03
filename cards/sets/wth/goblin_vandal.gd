extends CardScript
## Goblin Vandal — {R} — Creature — Goblin Rogue (common, wth).
## Oracle: Whenever this creature attacks and isn't blocked, you may pay {R}. If you do, destroy target artifact defending player controls and this creature assigns no combat damage this turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Goblin Vandal", "{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["goblin","rogue"])
	c.oracle("Whenever this creature attacks and isn't blocked, you may pay {R}. If you do, destroy target artifact defending player controls and this creature assigns no combat damage this turn.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
