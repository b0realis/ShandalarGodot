extends CardScript
## Reclaim — {G} — Instant (common, exo).
## Oracle: Put target card from your graveyard on top of your library.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Reclaim", "{G}", Mtg.CardType.INSTANT)
	c.oracle("Put target card from your graveyard on top of your library.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
