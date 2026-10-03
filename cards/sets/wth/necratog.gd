extends CardScript
## Necratog — {1}{B}{B} — Creature — Atog (uncommon, wth).
## Oracle: Exile the top creature card of your graveyard: this creature gets +2/+2 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Necratog", "{1}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["atog"])
	c.oracle("Exile the top creature card of your graveyard: this creature gets +2/+2 until end of turn.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
