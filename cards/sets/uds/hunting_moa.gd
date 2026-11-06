extends CardScript
## Hunting Moa — {2}{G} — Creature — Bird Beast (uncommon, uds).
## Oracle: Echo {2}{G} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
##         When this creature enters or dies, put a +1/+1 counter on target creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hunting Moa", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["bird","beast"])
	c.oracle("Echo {2}{G} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)\nWhen this creature enters or dies, put a +1/+1 counter on target creature.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
