extends CardScript
## Wall of Roots — {1}{G} — Creature — Plant Wall (common, mir).
## Oracle: Defender
##         Put a -0/-1 counter on this creature: Add {G}. Activate only once each turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wall of Roots", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(0, 5)
	c.with_subtypes(["plant","wall"])
	c.with_keywords([Mtg.Keyword.DEFENDER])
	c.oracle("Defender\nPut a -0/-1 counter on this creature: Add {G}. Activate only once each turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
