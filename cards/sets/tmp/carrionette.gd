extends CardScript
## Carrionette — {1}{B} — Creature — Skeleton (rare, tmp).
## Oracle: {2}{B}{B}: Exile this card and target creature unless that creature's controller pays {2}. Activate only if this card is in your graveyard.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Carrionette", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["skeleton"])
	c.oracle("{2}{B}{B}: Exile this card and target creature unless that creature's controller pays {2}. Activate only if this card is in your graveyard.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
