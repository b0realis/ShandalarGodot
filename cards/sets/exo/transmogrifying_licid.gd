extends CardScript
## Transmogrifying Licid — {3} — Artifact Creature — Licid (uncommon, exo).
## Oracle: {1}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {1} to end this effect.
##         Enchanted creature gets +1/+1 and is an artifact in addition to its other types.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Transmogrifying Licid", "{3}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(2, 2)
	c.with_subtypes(["licid"])
	c.oracle("{1}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {1} to end this effect.\nEnchanted creature gets +1/+1 and is an artifact in addition to its other types.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
