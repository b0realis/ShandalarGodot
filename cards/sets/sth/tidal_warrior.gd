extends CardScript
## Tidal Warrior — {U} — Creature — Merfolk Warrior (common, sth).
## Oracle: {T}: Target land becomes an Island until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tidal Warrior", "{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["merfolk","warrior"])
	c.oracle("{T}: Target land becomes an Island until end of turn.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
