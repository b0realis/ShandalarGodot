extends CardScript
## Anvil of Bogardan — {2} — Artifact (rare, vis).
## Oracle: Players have no maximum hand size.
##         At the beginning of each player's draw step, that player draws an additional card, then discards a card.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Anvil of Bogardan", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("Players have no maximum hand size.\nAt the beginning of each player's draw step, that player draws an additional card, then discards a card.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
