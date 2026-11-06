extends CardScript
## Karmic Guide — {3}{W}{W} — Creature — Angel Spirit (rare, ulg).
## Oracle: Flying, protection from black
##         Echo {3}{W}{W} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
##         When this creature enters, return target creature card from your graveyard to the battlefield.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Karmic Guide", "{3}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["angel","spirit"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.with_protection_from(Mtg.ManaColor.B)
	c.oracle("Flying, protection from black\nEcho {3}{W}{W} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)\nWhen this creature enters, return target creature card from your graveyard to the battlefield.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
