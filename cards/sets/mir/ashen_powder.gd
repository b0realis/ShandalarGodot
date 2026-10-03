extends CardScript
## Ashen Powder — {2}{B}{B} — Sorcery (rare, mir).
## Oracle: Put target creature card from an opponent's graveyard onto the battlefield under your control.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ashen Powder", "{2}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Put target creature card from an opponent's graveyard onto the battlefield under your control.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
