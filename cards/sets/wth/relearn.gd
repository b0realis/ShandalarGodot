extends CardScript
## Relearn — {1}{U}{U} — Sorcery (uncommon, wth).
## Oracle: Return target instant or sorcery card from your graveyard to your hand.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Relearn", "{1}{U}{U}", Mtg.CardType.SORCERY)
	c.oracle("Return target instant or sorcery card from your graveyard to your hand.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
