extends CardScript
## Dauthi Embrace — {2}{B} — Enchantment (uncommon, tmp).
## Oracle: {B}{B}: Target creature gains shadow until end of turn. (It can block or be blocked by only creatures with shadow.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dauthi Embrace", "{2}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{B}{B}: Target creature gains shadow until end of turn. (It can block or be blocked by only creatures with shadow.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
