extends CardScript
## Abyssal Horror — {4}{B}{B} — Creature — Horror (rare, usg).
## Oracle: Flying
##         When this creature enters, target player discards two cards.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Abyssal Horror", "{4}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["horror"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature enters, target player discards two cards.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
