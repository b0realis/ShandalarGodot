extends CardScript
## Planar Birth — {1}{W} — Sorcery (rare, usg).
## Oracle: Return all basic land cards from all graveyards to the battlefield tapped under their owners' control.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Planar Birth", "{1}{W}", Mtg.CardType.SORCERY)
	c.oracle("Return all basic land cards from all graveyards to the battlefield tapped under their owners' control.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
