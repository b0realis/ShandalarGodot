extends CardScript
## Standing Troops — {2}{W} — Creature — Human Soldier (common, exo).
## Oracle: Vigilance
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Standing Troops", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 4)
	c.with_subtypes(["human","soldier"])
	c.with_keywords([Mtg.Keyword.VIGILANCE])
	c.oracle("Vigilance")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
