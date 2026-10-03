extends CardScript
## Femeref Healer — {1}{W} — Creature — Human Cleric (common, mir).
## Oracle: {T}: Prevent the next 1 damage that would be dealt to any target this turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Femeref Healer", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","cleric"])
	c.oracle("{T}: Prevent the next 1 damage that would be dealt to any target this turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
