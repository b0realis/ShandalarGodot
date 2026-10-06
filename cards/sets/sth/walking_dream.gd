extends CardScript
## Walking Dream — {3}{U} — Creature — Illusion (uncommon, sth).
## Oracle: This creature can't be blocked.
##         This creature doesn't untap during your untap step if an opponent controls two or more creatures.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Walking Dream", "{3}{U}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["illusion"])
	c.oracle("This creature can't be blocked.\nThis creature doesn't untap during your untap step if an opponent controls two or more creatures.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
