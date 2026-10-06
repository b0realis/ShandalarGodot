extends CardScript
## Tempting Licid — {2}{G} — Creature — Licid (uncommon, sth).
## Oracle: {G}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {G} to end this effect.
##         All creatures able to block enchanted creature do so.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tempting Licid", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["licid"])
	c.oracle("{G}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {G} to end this effect.\nAll creatures able to block enchanted creature do so.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
