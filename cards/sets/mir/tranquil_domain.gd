extends CardScript
## Tranquil Domain — {1}{G} — Instant (common, mir).
## Oracle: Destroy all non-Aura enchantments.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tranquil Domain", "{1}{G}", Mtg.CardType.INSTANT)
	c.oracle("Destroy all non-Aura enchantments.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
