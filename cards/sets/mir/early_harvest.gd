extends CardScript
## Early Harvest — {1}{G}{G} — Instant (rare, mir).
## Oracle: Target player untaps all basic lands they control.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Early Harvest", "{1}{G}{G}", Mtg.CardType.INSTANT)
	c.oracle("Target player untaps all basic lands they control.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
