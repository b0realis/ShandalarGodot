extends CardScript
## Serene Offering — {1}{W} — Instant (uncommon, tmp).
## Oracle: Destroy target enchantment. You gain life equal to its mana value.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Serene Offering", "{1}{W}", Mtg.CardType.INSTANT)
	c.oracle("Destroy target enchantment. You gain life equal to its mana value.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
