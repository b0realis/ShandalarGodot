extends CardScript
## Scrying Glass — {2} — Artifact (rare, uds).
## Oracle: {3}, {T}: Choose a number greater than 0 and a color. Target opponent reveals their hand. If that opponent reveals exactly the chosen number of cards of the chosen color, you draw a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Scrying Glass", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("{3}, {T}: Choose a number greater than 0 and a color. Target opponent reveals their hand. If that opponent reveals exactly the chosen number of cards of the chosen color, you draw a card.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
