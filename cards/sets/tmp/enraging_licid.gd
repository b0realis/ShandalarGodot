extends CardScript
## Enraging Licid — {1}{R} — Creature — Licid (uncommon, tmp).
## Oracle: {R}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {R} to end this effect.
##         Enchanted creature has haste.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Enraging Licid", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["licid"])
	c.oracle("{R}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {R} to end this effect.\nEnchanted creature has haste.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
