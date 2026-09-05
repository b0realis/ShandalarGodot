extends CardScript
## Red Ward — {W} — Enchantment — Aura — (2ed, uncommon)
## Oracle: Enchant creature
##         Enchanted creature has protection from red. This effect
##         doesn't remove this Aura.
##
## Implementation: the ward cycle (see white_ward.gd) — pro-red flavor:
## Bolts can't target the host, Shivan damage is prevented. Note the
## exemption covers only its OWN grant: a later pro-WHITE effect on the
## host still evicts this (white) aura.


func build() -> CardData:
	return CardData.new("Red Ward", "{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.grants_host_protection(Mtg.ManaColor.R,
			"Enchanted creature has protection from red.") \
		.oracle("Enchant creature\nEnchanted creature has protection from red. This effect doesn't remove this Aura.")
