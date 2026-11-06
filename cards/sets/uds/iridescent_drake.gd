extends CardScript
## Iridescent Drake — {3}{U} — Creature — Drake (uncommon, uds).
## Oracle: Flying
##         When this creature enters, put target Aura card from a graveyard onto the battlefield under your control attached to this creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Iridescent Drake", "{3}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature enters, put target Aura card from a graveyard onto the battlefield under your control attached to this creature.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
