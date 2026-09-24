extends CardScript
## Snapping Drake — {3}{U} — Creature — Drake (Portal, 1997).
## Oracle: Flying (This creature can't be blocked except by creatures with flying or reach.)

func build() -> CardData:
	var c := CardData.new("Snapping Drake", "{3}{U}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying (This creature can't be blocked except by creatures with flying or reach.)")
	return c
