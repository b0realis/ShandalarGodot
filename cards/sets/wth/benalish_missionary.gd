extends CardScript
## Benalish Missionary — {W} — Creature — Human Cleric (common, wth).
## Oracle: {1}{W}, {T}: Prevent all combat damage that would be dealt by target blocked creature this turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Benalish Missionary", "{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","cleric"])
	c.oracle("{1}{W}, {T}: Prevent all combat damage that would be dealt by target blocked creature this turn.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
