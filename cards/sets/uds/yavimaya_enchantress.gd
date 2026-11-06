extends CardScript
## Yavimaya Enchantress — {2}{G} — Creature — Human Druid (uncommon, uds).
## Oracle: This creature gets +1/+1 for each enchantment on the battlefield.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Yavimaya Enchantress", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","druid"])
	c.oracle("This creature gets +1/+1 for each enchantment on the battlefield.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
