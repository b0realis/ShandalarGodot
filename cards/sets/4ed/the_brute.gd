extends CardScript
## The Brute — {1}{R} — Enchantment — Aura — (4ed, common)
## Oracle: Enchant creature
##         Enchanted creature gets +1/+0.
##         {R}{R}{R}: Regenerate enchanted creature.
##
## Implementation: a +1/+0 static plus an activated ability that lives on
## the AURA (so its controller is the aura's controller, which matters
## when the aura sits on an opponent's creature — the mage-go reference
## puts it on the creature instead, which we consider a bug; see
## docs/audit-vs-mage-go.md for the same finding on Regeneration).


func build() -> CardData:
	return CardData.new("The Brute", "{1}{R}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(
			_apply, "Enchanted creature gets +1/+0.")) \
		.activated(ActivatedAbility.new(
			"{R}{R}{R}", false, [RegenerateHostEffect.new()],
			"{R}{R}{R}: Regenerate enchanted creature.")) \
		.oracle("Enchant creature\nEnchanted creature gets +1/+0.\n{R}{R}{R}: "
			+ "Regenerate enchanted creature.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		host.cur_power += 1


class RegenerateHostEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var host := game.find_instance(source.attached_to)
		if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
			return
		host.regeneration_shields += 1
		game.log_line("%s gains a regeneration shield (%d)" % [
			host.data.card_name, host.regeneration_shields])

	func describe() -> String:
		return "regenerates enchanted creature"
