extends CardScript
## White Ward — {W} — Enchantment — Aura — (2ed, uncommon)
## Oracle: Enchant creature
##         Enchanted creature has protection from white. This effect
##         doesn't remove this Aura.
##
## Implementation: grants_host_protection installs the protection static
## AND the printed self-exemption — this white aura is the reason the
## rider exists (it grants pro-white and must survive its own grant; any
## OTHER pro-white source still removes it).


func build() -> CardData:
	return CardData.new("White Ward", "{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.grants_host_protection(Mtg.ManaColor.W,
			"Enchanted creature has protection from white.") \
		.oracle("Enchant creature\nEnchanted creature has protection from white. This effect doesn't remove this Aura.")
