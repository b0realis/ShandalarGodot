extends CardScript
## Calming Licid — {2}{W} — Creature — Licid (uncommon, sth).
## Oracle: {W}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {W} to end this effect.
##         Enchanted creature can't attack.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Calming Licid", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["licid"])
	c.oracle("{W}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {W} to end this effect.\nEnchanted creature can't attack.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
