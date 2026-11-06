extends CardScript
## Soul Sculptor — {2}{W} — Creature — Human (rare, usg).
## Oracle: {1}{W}, {T}: Target creature becomes an enchantment and loses all abilities until a player casts a creature spell.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Soul Sculptor", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human"])
	c.oracle("{1}{W}, {T}: Target creature becomes an enchantment and loses all abilities until a player casts a creature spell.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
