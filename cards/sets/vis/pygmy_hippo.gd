extends CardScript
## Pygmy Hippo — {G}{U} — Creature — Hippo (rare, vis).
## Oracle: Whenever this creature attacks and isn't blocked, you may have defending player activate a mana ability of each land they control and lose all unspent mana. If you do, this creature assigns no combat damage this turn and at the beginning of your next main phase this turn, you add an amount of {C} equal to the amount of mana that player lost this way.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Pygmy Hippo", "{G}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["hippo"])
	c.oracle("Whenever this creature attacks and isn't blocked, you may have defending player activate a mana ability of each land they control and lose all unspent mana. If you do, this creature assigns no combat damage this turn and at the beginning of your next main phase this turn, you add an amount of {C} equal to the amount of mana that player lost this way.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
