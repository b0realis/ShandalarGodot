extends CardScript
## Tainted Specter — {3}{B} — Creature — Specter (rare, mir).
## Oracle: Flying
##         {1}{B}{B}, {T}: Target player discards a card unless they put a card from their hand on top of their library. If that player discards a card this way, this creature deals 1 damage to each creature and each player. Activate only as a sorcery.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tainted Specter", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["specter"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{1}{B}{B}, {T}: Target player discards a card unless they put a card from their hand on top of their library. If that player discards a card this way, this creature deals 1 damage to each creature and each player. Activate only as a sorcery.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
