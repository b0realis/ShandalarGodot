extends CardScript
## Emerald Charm — {G} — Instant (common, vis).
## Oracle: Choose one —
##         • Untap target permanent.
##         • Destroy target non-Aura enchantment.
##         • Target creature loses flying until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Emerald Charm", "{G}", Mtg.CardType.INSTANT)
	c.oracle("Choose one —\n• Untap target permanent.\n• Destroy target non-Aura enchantment.\n• Target creature loses flying until end of turn.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
