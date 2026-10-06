extends CardScript
## Lobotomy — {2}{U}{B} — Sorcery (uncommon, tmp).
## Oracle: Target player reveals their hand, then you choose a card other than a basic land card from it. Search that player's graveyard, hand, and library for all cards with the same name as the chosen card and exile them. Then that player shuffles.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lobotomy", "{2}{U}{B}", Mtg.CardType.SORCERY)
	c.oracle("Target player reveals their hand, then you choose a card other than a basic land card from it. Search that player's graveyard, hand, and library for all cards with the same name as the chosen card and exile them. Then that player shuffles.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
