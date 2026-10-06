extends CardScript
## Dominating Licid — {1}{U}{U} — Creature — Licid (rare, exo).
## Oracle: {1}{U}{U}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {U} to end this effect.
##         You control enchanted creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dominating Licid", "{1}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["licid"])
	c.oracle("{1}{U}{U}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {U} to end this effect.\nYou control enchanted creature.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
