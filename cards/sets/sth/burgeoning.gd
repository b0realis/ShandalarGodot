extends CardScript
## Burgeoning — {G} — Enchantment (rare, sth).
## Oracle: Whenever an opponent plays a land, you may put a land card from your hand onto the battlefield.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Burgeoning", "{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever an opponent plays a land, you may put a land card from your hand onto the battlefield.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
