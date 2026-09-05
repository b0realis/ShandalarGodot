extends CardScript
## Control Magic — {2}{U}{U} — Enchantment — Aura (2ed, uncommon)
## Oracle: Enchant creature. You control enchanted creature.
##
## Implementation: the reference CONTROL-CHANGE card — steals_control()
## marks the aura; the engine transfers the host on attach (with the
## summoning-sickness a newly-stolen creature rightly has, CR 302.6) and
## sends it home when the aura leaves (Disenchant IS the answer, exactly
## as in 1997). Blue's great heist.


func build() -> CardData:
	return CardData.new("Control Magic", "{2}{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.steals_control() \
		.oracle("Enchant creature. You control enchanted creature.")
