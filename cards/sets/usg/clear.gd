extends CardScript
## Clear — {1}{W} — Instant (uncommon, usg).
## Oracle: Destroy target enchantment.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Clear", "{1}{W}", Mtg.CardType.INSTANT)
	c.oracle("Destroy target enchantment.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
