extends CardScript
## Master Healer — {4}{W} — Creature — Human Cleric (rare, uds).
## Oracle: {T}: Prevent the next 4 damage that would be dealt to any target this turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Master Healer", "{4}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 4)
	c.with_subtypes(["human","cleric"])
	c.oracle("{T}: Prevent the next 4 damage that would be dealt to any target this turn.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
