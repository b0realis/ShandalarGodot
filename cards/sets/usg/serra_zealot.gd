extends CardScript
## Serra Zealot — {W} — Creature — Human Soldier (common, usg).
## Oracle: First strike
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Serra Zealot", "{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","soldier"])
	c.with_keywords([Mtg.Keyword.FIRST_STRIKE])
	c.oracle("First strike")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
