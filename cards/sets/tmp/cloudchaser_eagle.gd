extends CardScript
## Cloudchaser Eagle — {3}{W} — Creature — Bird (common, tmp).
## Oracle: Flying
##         When this creature enters, destroy target enchantment.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cloudchaser Eagle", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["bird"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature enters, destroy target enchantment.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
