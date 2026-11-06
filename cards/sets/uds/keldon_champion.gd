extends CardScript
## Keldon Champion — {2}{R}{R} — Creature — Human Barbarian (uncommon, uds).
## Oracle: Haste
##         Echo {2}{R}{R} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
##         When this creature enters, it deals 3 damage to target player or planeswalker.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Keldon Champion", "{2}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["human","barbarian"])
	c.with_keywords([Mtg.Keyword.HASTE])
	c.oracle("Haste\nEcho {2}{R}{R} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)\nWhen this creature enters, it deals 3 damage to target player or planeswalker.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
