extends CardScript
## Daring Apprentice — {1}{U}{U} — Creature — Human Wizard (rare, mir).
## Oracle: {T}, Sacrifice this creature: Counter target spell.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Daring Apprentice", "{1}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","wizard"])
	c.oracle("{T}, Sacrifice this creature: Counter target spell.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
