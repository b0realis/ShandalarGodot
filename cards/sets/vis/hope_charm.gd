extends CardScript
## Hope Charm — {W} — Instant (common, vis).
## Oracle: Choose one —
##         • Target creature gains first strike until end of turn.
##         • Target player gains 2 life.
##         • Destroy target Aura.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hope Charm", "{W}", Mtg.CardType.INSTANT)
	c.oracle("Choose one —\n• Target creature gains first strike until end of turn.\n• Target player gains 2 life.\n• Destroy target Aura.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
