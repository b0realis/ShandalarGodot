extends CardScript
## Demonic Torment — {2}{B} — Enchantment — Aura — (leg, uncommon)
## Oracle: Enchant creature
##         Enchanted creature can't attack.
##         Prevent all combat damage that would be dealt by enchanted
##         creature.
##
## Implementation: a static setting both the host's cur_cant_attack flag
## and its combat-damage-dealt prevention — so the creature can still
## block, but it deals nothing when it does. Three mana of pure
## pacifism, in black.


func build() -> CardData:
	return CardData.new("Demonic Torment", "{2}{B}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(
			_apply,
			"Enchanted creature can't attack, and its combat damage is prevented.")) \
		.oracle("Enchant creature\nEnchanted creature can't attack.\nPrevent all "
			+ "combat damage that would be dealt by enchanted creature.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		host.cur_cant_attack = true
		host.cur_prevent_combat_damage_dealt = true
