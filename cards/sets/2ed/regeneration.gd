extends CardScript
## Regeneration — {1}{G} — Enchantment — Aura (2ed, common)
## Oracle: Enchant creature. {G}: Regenerate enchanted creature.
##
## Implementation: the aura form of Drudge Skeletons' ability — a
## card-local effect that puts the regeneration shield on the HOST (the
## engine's shields + destroy logic do the rest). Gives any creature the
## skeleton treatment.


func build() -> CardData:
	return CardData.new("Regeneration", "{1}{G}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.activated(ActivatedAbility.new(
			"{G}", false,
			[RegenerateHostEffect.new()],
			"{G}: Regenerate enchanted creature.")) \
		.oracle("Enchant creature. {G}: Regenerate enchanted creature.")


class RegenerateHostEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source.attached_to == -1:
			return
		var host := game.find_instance(source.attached_to)
		if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
			return
		host.regeneration_shields += 1
		game.log_line("%s gains a regeneration shield (%d)" % [
			host.data.card_name, host.regeneration_shields])

	func describe() -> String:
		return "regenerates enchanted creature"
