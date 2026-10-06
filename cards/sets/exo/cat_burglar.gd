extends CardScript
## Cat Burglar — {3}{B} — Creature — Kor Rogue Minion (common, exo).
## Oracle: {2}{B}, {T}: Target player discards a card. Activate only as a sorcery.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cat Burglar", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["kor","rogue","minion"])
	c.oracle("{2}{B}, {T}: Target player discards a card. Activate only as a sorcery.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
