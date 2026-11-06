extends CardScript
## Show and Tell — {2}{U} — Sorcery (rare, usg).
## Oracle: Each player may put an artifact, creature, enchantment, or land card from their hand onto the battlefield.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Show and Tell", "{2}{U}", Mtg.CardType.SORCERY)
	c.oracle("Each player may put an artifact, creature, enchantment, or land card from their hand onto the battlefield.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
