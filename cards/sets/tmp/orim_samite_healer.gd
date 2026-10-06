extends CardScript
## Orim, Samite Healer — {1}{W}{W} — Legendary Creature — Human Cleric (rare, tmp).
## Oracle: {T}: Prevent the next 3 damage that would be dealt to any target this turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Orim, Samite Healer", "{1}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 3)
	c.with_subtypes(["human","cleric"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("{T}: Prevent the next 3 damage that would be dealt to any target this turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
