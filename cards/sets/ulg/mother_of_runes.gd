extends CardScript
## Mother of Runes — {W} — Creature — Human Cleric (uncommon, ulg).
## Oracle: {T}: Target creature you control gains protection from the color of your choice until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mother of Runes", "{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","cleric"])
	c.oracle("{T}: Target creature you control gains protection from the color of your choice until end of turn.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
