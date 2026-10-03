extends CardScript
## Skulking Ghost — {1}{B} — Creature — Spirit (common, mir).
## Oracle: Flying
##         When this creature becomes the target of a spell or ability, sacrifice it.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Skulking Ghost", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["spirit"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature becomes the target of a spell or ability, sacrifice it.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
