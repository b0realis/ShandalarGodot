extends CardScript
## Maddening Imp — {2}{B} — Creature — Imp (rare, tmp).
## Oracle: Flying
##         {T}: Non-Wall creatures the active player controls attack this turn if able. At the beginning of the next end step, destroy each of those creatures that didn't attack this turn. Activate only during an opponent's turn and only before combat.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Maddening Imp", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["imp"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{T}: Non-Wall creatures the active player controls attack this turn if able. At the beginning of the next end step, destroy each of those creatures that didn't attack this turn. Activate only during an opponent's turn and only before combat.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
