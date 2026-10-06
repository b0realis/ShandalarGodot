extends CardScript
## Abandon Hope — {X}{1}{B} — Sorcery (uncommon, tmp).
## Oracle: As an additional cost to cast this spell, discard X cards.
##         Look at target opponent's hand and choose X cards from it. That player discards those cards.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Abandon Hope", "{X}{1}{B}", Mtg.CardType.SORCERY)
	c.oracle("As an additional cost to cast this spell, discard X cards.\nLook at target opponent's hand and choose X cards from it. That player discards those cards.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
