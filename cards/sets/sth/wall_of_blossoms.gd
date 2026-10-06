extends CardScript
## Wall of Blossoms — {1}{G} — Creature — Plant Wall (uncommon, sth).
## Oracle: Defender
##         When this creature enters, draw a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wall of Blossoms", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(0, 4)
	c.with_subtypes(["plant","wall"])
	c.with_keywords([Mtg.Keyword.DEFENDER])
	c.oracle("Defender\nWhen this creature enters, draw a card.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
