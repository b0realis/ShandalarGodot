extends CardScript
## Phyrexian Furnace — {1} — Artifact (uncommon, wth).
## Oracle: {T}: Exile the bottom card of target player's graveyard.
##         {1}, Sacrifice this artifact: Exile target card from a graveyard. Draw a card.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Phyrexian Furnace", "{1}", Mtg.CardType.ARTIFACT)
	c.oracle("{T}: Exile the bottom card of target player's graveyard.\n{1}, Sacrifice this artifact: Exile target card from a graveyard. Draw a card.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
