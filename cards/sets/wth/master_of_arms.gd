extends CardScript
## Master of Arms — {2}{W} — Creature — Human Soldier (uncommon, wth).
## Oracle: First strike
##         {1}{W}: Tap target creature blocking this creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Master of Arms", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","soldier"])
	c.with_keywords([Mtg.Keyword.FIRST_STRIKE])
	c.oracle("First strike\n{1}{W}: Tap target creature blocking this creature.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
