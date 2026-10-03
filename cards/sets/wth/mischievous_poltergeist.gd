extends CardScript
## Mischievous Poltergeist — {2}{B} — Creature — Spirit (uncommon, wth).
## Oracle: Flying
##         Pay 1 life: Regenerate this creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mischievous Poltergeist", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["spirit"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nPay 1 life: Regenerate this creature.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
