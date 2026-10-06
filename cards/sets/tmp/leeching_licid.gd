extends CardScript
## Leeching Licid — {1}{B} — Creature — Licid (uncommon, tmp).
## Oracle: {B}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {B} to end this effect.
##         At the beginning of the upkeep of enchanted creature's controller, this creature deals 1 damage to that player.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Leeching Licid", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["licid"])
	c.oracle("{B}, {T}: This creature loses this ability and becomes an Aura enchantment with enchant creature. Attach it to target creature. You may pay {B} to end this effect.\nAt the beginning of the upkeep of enchanted creature's controller, this creature deals 1 damage to that player.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
