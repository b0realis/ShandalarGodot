extends CardScript
## Unseen Walker — {1}{G} — Creature — Dryad (uncommon, mir).
## Oracle: Forestwalk (This creature can't be blocked as long as defending player controls a Forest.)
##         {1}{G}{G}: Target creature gains forestwalk until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Unseen Walker", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["dryad"])
	c.with_landwalk(["forest"])
	c.oracle("Forestwalk (This creature can't be blocked as long as defending player controls a Forest.)\n{1}{G}{G}: Target creature gains forestwalk until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
