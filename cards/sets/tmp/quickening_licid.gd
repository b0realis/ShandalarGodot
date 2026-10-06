extends CardScript
## Quickening Licid — {1}{W} — Creature — Licid (uncommon, tmp).
## Oracle: {1}{W}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {W} to end this effect.
##         Enchanted creature has first strike.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Quickening Licid", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["licid"])
	c.oracle("{1}{W}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {W} to end this effect.\nEnchanted creature has first strike.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
