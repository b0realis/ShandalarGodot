extends CardScript
## Haunting Misery — {1}{B}{B} — Sorcery (common, wth).
## Oracle: As an additional cost to cast this spell, exile X creature cards from your graveyard.
##         Haunting Misery deals X damage to target player or planeswalker.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Haunting Misery", "{1}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("As an additional cost to cast this spell, exile X creature cards from your graveyard.\nHaunting Misery deals X damage to target player or planeswalker.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
