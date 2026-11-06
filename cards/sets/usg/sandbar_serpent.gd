extends CardScript
## Sandbar Serpent — {4}{U} — Creature — Serpent (uncommon, usg).
## Oracle: Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sandbar Serpent", "{4}{U}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["serpent"])
	c.oracle("Cycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
