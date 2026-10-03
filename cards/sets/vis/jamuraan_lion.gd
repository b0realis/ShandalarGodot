extends CardScript
## Jamuraan Lion — {2}{W} — Creature — Cat (common, vis).
## Oracle: {W}, {T}: Target creature can't block this turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Jamuraan Lion", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(3, 1)
	c.with_subtypes(["cat"])
	c.oracle("{W}, {T}: Target creature can't block this turn.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
