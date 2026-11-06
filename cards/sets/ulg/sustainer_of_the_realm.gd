extends CardScript
## Sustainer of the Realm — {2}{W}{W} — Creature — Angel (uncommon, ulg).
## Oracle: Flying
##         Whenever this creature blocks, it gets +0/+2 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sustainer of the Realm", "{2}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["angel"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhenever this creature blocks, it gets +0/+2 until end of turn.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
