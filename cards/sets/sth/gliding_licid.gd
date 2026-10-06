extends CardScript
## Gliding Licid — {2}{U} — Creature — Licid (uncommon, sth).
## Oracle: {U}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {U} to end this effect.
##         Enchanted creature has flying.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Gliding Licid", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["licid"])
	c.oracle("{U}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {U} to end this effect.\nEnchanted creature has flying.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
