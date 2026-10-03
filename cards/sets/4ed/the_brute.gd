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
##
## The effect says what it is (2026-10-03), as the 2ed Regeneration aura's
## does: [member EffectBase.is_regeneration] lets the ability into Fifth
## Edition's regeneration window, and the `regenerate_host` role lets the
## AI read the shield off the aura for the creature it enchants. Without
## them a Brute-wearer died in that window with {R}{R}{R} open.


func build() -> CardData:
	return CardData.new("The Brute", "{1}{R}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(
			_apply, "Enchanted creature gets +1/+0.")) \
		.activated(ActivatedAbility.new(
			"{R}{R}{R}", false,
			[RegenerateHostEffect.new().with_ai_role(&"regenerate_host")],
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
	func _init() -> void:
		is_regeneration = true

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source.attached_to == -1:
			return
		var host := game.find_instance(source.attached_to)
		if not game.is_present(host):   # gone, or phased out (CR 702.26e)
			return
		host.regeneration_shields += 1
		game.log_line("%s gains a regeneration shield (%d)" % [
			host.data.card_name, host.regeneration_shields])

	func describe() -> String:
		return "regenerates enchanted creature"
