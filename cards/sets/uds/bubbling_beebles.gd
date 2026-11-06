extends CardScript
## Bubbling Beebles — {4}{U} — Creature — Beeble (common, uds).
## Oracle: This creature can't be blocked as long as defending player controls an enchantment.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bubbling Beebles", "{4}{U}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["beeble"])
	c.oracle("This creature can't be blocked as long as defending player controls an enchantment.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
