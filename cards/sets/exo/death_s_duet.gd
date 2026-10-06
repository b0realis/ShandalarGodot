extends CardScript
## Death's Duet — {2}{B} — Sorcery (common, exo).
## Oracle: Return two target creature cards from your graveyard to your hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Death's Duet", "{2}{B}", Mtg.CardType.SORCERY)
	c.oracle("Return two target creature cards from your graveyard to your hand.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
