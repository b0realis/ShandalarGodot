extends CardScript
## Anti-Magic Aura — {2}{U} — Enchantment — Aura — (leg, common)
## Oracle: Enchant creature
##         Enchanted creature can't be the target of spells and can't be
##         enchanted by other Auras.
##
## Implementation: a static raising two instance flags on the host —
## "can't be the target of spells" (abilities still work: a Prodigal
## Sorcerer can still shoot it) and "can't be enchanted by other Auras",
## which TargetSpec enforces against any aura still in hand or on the
## stack. Cast on your own fatty it blanks removal; cast on theirs it
## blanks their own pump spells.


func build() -> CardData:
	return CardData.new("Anti-Magic Aura", "{2}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(
			_apply,
			"Enchanted creature can't be the target of spells and can't be enchanted "
			+ "by other Auras.")) \
		.oracle("Enchant creature\nEnchanted creature can't be the target of spells "
			+ "and can't be enchanted by other Auras.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		host.cur_cant_be_spell_target = true
		host.cur_cant_be_aura_target = true
