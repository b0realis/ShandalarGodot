extends CardScript
## Rashida Scalebane — {3}{W}{W} — Legendary Creature — Human Soldier (rare, mir).
## Oracle: {T}: Destroy target attacking or blocking Dragon. It can't be regenerated. You gain life equal to its power.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rashida Scalebane", "{3}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["human","soldier"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("{T}: Destroy target attacking or blocking Dragon. It can't be regenerated. You gain life equal to its power.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
