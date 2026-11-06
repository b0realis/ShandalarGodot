extends CardScript
## Silent Attendant — {2}{W} — Creature — Human Cleric (common, usg).
## Oracle: {T}: You gain 1 life.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Silent Attendant", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(0, 2)
	c.with_subtypes(["human","cleric"])
	c.oracle("{T}: You gain 1 life.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
