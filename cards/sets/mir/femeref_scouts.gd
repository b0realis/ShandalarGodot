extends CardScript
## Femeref Scouts — {2}{W} — Creature — Human Scout (common, mir).
## Oracle: (No rules text.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Femeref Scouts", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 4)
	c.with_subtypes(["human","scout"])
	c.oracle("")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
