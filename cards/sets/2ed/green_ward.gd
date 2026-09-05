extends CardScript
## Green Ward — {W} — Enchantment — Aura — (2ed, uncommon)
## Oracle: Enchant creature
##         Enchanted creature has protection from green. This effect
##         doesn't remove this Aura.
##
## Implementation: the ward cycle (see white_ward.gd) — pro-green flavor:
## unblockable by green fatties, immune to their damage.


func build() -> CardData:
	return CardData.new("Green Ward", "{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.grants_host_protection(Mtg.ManaColor.G,
			"Enchanted creature has protection from green.") \
		.oracle("Enchant creature\nEnchanted creature has protection from green. This effect doesn't remove this Aura.")
