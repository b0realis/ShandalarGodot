extends CardScript
## Mundungu — {1}{U}{B} — Creature — Human Wizard (uncommon, vis).
## Oracle: {T}: Counter target spell unless its controller pays {1} and 1 life.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mundungu", "{1}{U}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","wizard"])
	c.oracle("{T}: Counter target spell unless its controller pays {1} and 1 life.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
