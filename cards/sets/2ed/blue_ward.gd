extends CardScript
## Blue Ward — {W} — Enchantment — Aura — (2ed, uncommon)
## Oracle: Enchant creature
##         Enchanted creature has protection from blue. This effect
##         doesn't remove this Aura.
##
## Implementation: the ward cycle (see white_ward.gd) — pro-blue flavor:
## the host shrugs off Psionic Blast and slips past blue blockers.


func build() -> CardData:
	return CardData.new("Blue Ward", "{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.grants_host_protection(Mtg.ManaColor.U,
			"Enchanted creature has protection from blue.") \
		.oracle("Enchant creature\nEnchanted creature has protection from blue. This effect doesn't remove this Aura.")
