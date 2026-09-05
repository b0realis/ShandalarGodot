extends CardScript
## Gaseous Form — {2}{U} — Enchantment — Aura — (4ed, common)
## Oracle: Enchant creature
##         Prevent all combat damage that would be dealt to and dealt by
##         enchanted creature.
##
## Implementation: a static setting the host's two COMBAT-only prevention
## flags. The engine's deal_damage knows which damage is combat damage,
## so a Lightning Bolt still kills the enchanted creature and its own
## ping abilities still work — only combat is blanked. Cast on an
## opponent's fatty it is pseudo-removal; cast on your own wall it makes
## an unkillable blocker.


func build() -> CardData:
	return CardData.new("Gaseous Form", "{2}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(
			_apply,
			"Prevent all combat damage that would be dealt to and dealt by "
			+ "enchanted creature.")) \
		.oracle("Enchant creature\nPrevent all combat damage that would be dealt to "
			+ "and dealt by enchanted creature.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		host.cur_prevent_combat_damage_dealt = true
		host.cur_prevent_combat_damage_taken = true
