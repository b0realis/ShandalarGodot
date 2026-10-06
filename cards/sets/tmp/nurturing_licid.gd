extends CardScript
## Nurturing Licid — {1}{G} — Creature — Licid (uncommon, tmp).
## Oracle: {G}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {G} to end this effect.
##         {G}: Regenerate enchanted creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Nurturing Licid", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["licid"])
	c.oracle("{G}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {G} to end this effect.\n{G}: Regenerate enchanted creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
