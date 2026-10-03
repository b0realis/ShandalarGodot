extends CardScript
## Gaea's Blessing — {1}{G} — Sorcery (uncommon, wth).
## Oracle: Target player shuffles up to three target cards from their graveyard into their library.
##         Draw a card.
##         When this card is put into your graveyard from your library, shuffle your graveyard into your library.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Gaea's Blessing", "{1}{G}", Mtg.CardType.SORCERY)
	c.oracle("Target player shuffles up to three target cards from their graveyard into their library.\nDraw a card.\nWhen this card is put into your graveyard from your library, shuffle your graveyard into your library.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
