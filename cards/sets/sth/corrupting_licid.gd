extends CardScript
## Corrupting Licid — {2}{B} — Creature — Licid (uncommon, sth).
## Oracle: {B}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {B} to end this effect.
##         Enchanted creature has fear. (It can't be blocked except by artifact creatures and/or black creatures.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Corrupting Licid", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["licid"])
	c.oracle("{B}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {B} to end this effect.\nEnchanted creature has fear. (It can't be blocked except by artifact creatures and/or black creatures.)")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
