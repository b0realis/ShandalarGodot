extends CardScript
## Yawgmoth's Will — {2}{B} — Sorcery (rare, usg).
## Oracle: Until end of turn, you may play lands and cast spells from your graveyard.
##         If a card would be put into your graveyard from anywhere this turn, exile that card instead.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Yawgmoth's Will", "{2}{B}", Mtg.CardType.SORCERY)
	c.oracle("Until end of turn, you may play lands and cast spells from your graveyard.\nIf a card would be put into your graveyard from anywhere this turn, exile that card instead.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
