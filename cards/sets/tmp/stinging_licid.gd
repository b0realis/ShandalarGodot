extends CardScript
## Stinging Licid — {1}{U} — Creature — Licid (uncommon, tmp).
## Oracle: {1}{U}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {U} to end this effect.
##         Whenever enchanted creature becomes tapped, this creature deals 2 damage to that creature's controller.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Stinging Licid", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["licid"])
	c.oracle("{1}{U}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {U} to end this effect.\nWhenever enchanted creature becomes tapped, this creature deals 2 damage to that creature's controller.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
