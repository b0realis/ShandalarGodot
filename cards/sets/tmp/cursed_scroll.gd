extends CardScript
## Cursed Scroll — {1} — Artifact (rare, tmp).
## Oracle: {3}, {T}: Choose a card name, then reveal a card at random from your hand. If that card has the chosen name, this artifact deals 2 damage to any target.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cursed Scroll", "{1}", Mtg.CardType.ARTIFACT)
	c.oracle("{3}, {T}: Choose a card name, then reveal a card at random from your hand. If that card has the chosen name, this artifact deals 2 damage to any target.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
