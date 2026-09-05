extends CardScript
## Black Ward — {W} — Enchantment — Aura — (2ed, uncommon)
## Oracle: Enchant creature
##         Enchanted creature has protection from black. This effect
##         doesn't remove this Aura.
##
## Implementation: the ward cycle (see white_ward.gd) — pro-black flavor:
## blanks Terror, Drain Life, black blockers and Bad Moon'd attacks.


func build() -> CardData:
	return CardData.new("Black Ward", "{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.grants_host_protection(Mtg.ManaColor.B,
			"Enchanted creature has protection from black.") \
		.oracle("Enchant creature\nEnchanted creature has protection from black. This effect doesn't remove this Aura.")
