extends CardScript
## Convulsing Licid — {2}{R} — Creature — Licid (uncommon, sth).
## Oracle: {R}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {R} to end this effect.
##         Enchanted creature can't block.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Convulsing Licid", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["licid"])
	c.oracle("{R}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {R} to end this effect.\nEnchanted creature can't block.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
