extends CardScript
## Mind Peel — {B} — Sorcery (uncommon, sth).
## Oracle: Buyback {2}{B}{B} (You may pay an additional {2}{B}{B} as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Target player discards a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mind Peel", "{B}", Mtg.CardType.SORCERY)
	c.oracle("Buyback {2}{B}{B} (You may pay an additional {2}{B}{B} as you cast this spell. If you do, put this card into your hand as it resolves.)\nTarget player discards a card.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
