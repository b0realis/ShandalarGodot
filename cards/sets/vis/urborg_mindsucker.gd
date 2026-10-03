extends CardScript
## Urborg Mindsucker — {2}{B} — Creature — Horror (common, vis).
## Oracle: {B}, Sacrifice this creature: Target opponent discards a card at random. Activate only as a sorcery.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Urborg Mindsucker", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["horror"])
	c.oracle("{B}, Sacrifice this creature: Target opponent discards a card at random. Activate only as a sorcery.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
