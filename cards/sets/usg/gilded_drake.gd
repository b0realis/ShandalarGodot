extends CardScript
## Gilded Drake — {1}{U} — Creature — Drake (rare, usg).
## Oracle: Flying
##         When this creature enters, exchange control of this creature and up to one target creature an opponent controls. If you don't or can't make an exchange, sacrifice this creature. This ability still resolves if its target becomes illegal.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Gilded Drake", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature enters, exchange control of this creature and up to one target creature an opponent controls. If you don't or can't make an exchange, sacrifice this creature. This ability still resolves if its target becomes illegal.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
