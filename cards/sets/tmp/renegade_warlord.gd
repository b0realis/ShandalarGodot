extends CardScript
## Renegade Warlord — {4}{R} — Creature — Human Soldier (uncommon, tmp).
## Oracle: First strike
##         Whenever this creature attacks, each other attacking creature gets +1/+0 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Renegade Warlord", "{4}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["human","soldier"])
	c.with_keywords([Mtg.Keyword.FIRST_STRIKE])
	c.oracle("First strike\nWhenever this creature attacks, each other attacking creature gets +1/+0 until end of turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
