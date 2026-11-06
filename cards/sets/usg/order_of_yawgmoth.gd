extends CardScript
## Order of Yawgmoth — {2}{B}{B} — Creature — Phyrexian Zombie Knight (uncommon, usg).
## Oracle: Fear (This creature can't be blocked except by artifact creatures and/or black creatures.)
##         Whenever this creature deals damage to a player, that player discards a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Order of Yawgmoth", "{2}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["phyrexian","zombie","knight"])
	c.with_keywords([Mtg.Keyword.FEAR])
	c.oracle("Fear (This creature can't be blocked except by artifact creatures and/or black creatures.)\nWhenever this creature deals damage to a player, that player discards a card.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
