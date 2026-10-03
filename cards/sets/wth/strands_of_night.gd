extends CardScript
## Strands of Night — {2}{B}{B} — Enchantment (uncommon, wth).
## Oracle: {B}{B}, Pay 2 life, Sacrifice a Swamp: Return target creature card from your graveyard to the battlefield.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Strands of Night", "{2}{B}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{B}{B}, Pay 2 life, Sacrifice a Swamp: Return target creature card from your graveyard to the battlefield.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
