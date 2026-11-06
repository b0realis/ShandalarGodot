extends CardScript
## Songstitcher — {W} — Creature — Human Cleric (uncommon, usg).
## Oracle: {1}{W}: Prevent all combat damage that would be dealt this turn by target attacking creature with flying.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Songstitcher", "{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","cleric"])
	c.oracle("{1}{W}: Prevent all combat damage that would be dealt this turn by target attacking creature with flying.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
