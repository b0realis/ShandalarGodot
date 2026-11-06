extends CardScript
## Sanctum Custodian — {2}{W} — Creature — Human Cleric (common, usg).
## Oracle: {T}: Prevent the next 2 damage that would be dealt to any target this turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sanctum Custodian", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["human","cleric"])
	c.oracle("{T}: Prevent the next 2 damage that would be dealt to any target this turn.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
