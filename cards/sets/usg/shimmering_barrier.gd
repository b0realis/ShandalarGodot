extends CardScript
## Shimmering Barrier — {1}{W} — Creature — Wall (uncommon, usg).
## Oracle: Defender (This creature can't attack.)
##         First strike
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shimmering Barrier", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 3)
	c.with_subtypes(["wall"])
	c.with_keywords([Mtg.Keyword.DEFENDER, Mtg.Keyword.FIRST_STRIKE])
	c.oracle("Defender (This creature can't attack.)\nFirst strike\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
