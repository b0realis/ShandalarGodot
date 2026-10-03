extends CardScript
## Argivian Restoration — {2}{U}{U} — Sorcery (uncommon, wth).
## Oracle: Return target artifact card from your graveyard to the battlefield.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Argivian Restoration", "{2}{U}{U}", Mtg.CardType.SORCERY)
	c.oracle("Return target artifact card from your graveyard to the battlefield.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
