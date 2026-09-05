extends CardScript
## Equinox — {W} — Enchantment — Aura — (leg, common)
## Oracle: Enchant land
##         Enchanted land has "{T}: Counter target spell if it would destroy
##         a land you control."
##
## Implementation: the granted ability lives on the LIVE ability list of the
## host (CardInstance.cur_activated_abilities, the same list Zombie Master
## appends to), so it really belongs to the land: it is refused while the
## land is tapped, it is gone the moment the Aura leaves, and a land stolen
## with the Equinox on it hands the ability to the thief.
##
## "If it would destroy a land you control" is judged when the ability
## RESOLVES, because it is a condition on the effect and not on the target —
## the spell is a legal target either way, and Equinox simply does nothing
## to a Lightning Bolt. What counts as land destruction is the spell's own
## effects: a DestroyEffect or DestroyAllEffect whose spec a land you
## control satisfies (Stone Rain, Armageddon, Sinkhole).


func build() -> CardData:
	return CardData.new("Equinox", "{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "enchant land",
			_is_land)) \
		.static_ability(StaticAbility.new(
			_grant, "Enchanted land has \"{T}: Counter target spell if it would destroy a land you control.\"")) \
		.oracle("Enchant land\nEnchanted land has \"{T}: Counter target spell if "
			+ "it would destroy a land you control.\"")


static func _is_land(inst: CardInstance) -> bool:
	return inst.is_land()


static func _grant(game: MtgGame, source: CardInstance) -> void:
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return
	host.cur_activated_abilities.append(ActivatedAbility.new(
		"", true, [WardEffect.new()],
		"{T}: Counter target spell if it would destroy a land you control."))


class WardEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.spell()

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var spell := game.find_instance(target.instance_id)
		if spell == null or spell.zone != Mtg.Zone.STACK:
			return
		if not WardEffect._threatens_a_land(game, spell, controller):
			game.log_line("%s does not threaten a land — Equinox does nothing"
				% spell.data.card_name)
			return
		game.counter_spell(spell)

	## Would [param spell] destroy a land [param pid] controls? Read off the
	## spell's own effects, so nothing is keyed to a card name.
	static func _threatens_a_land(game: MtgGame, spell: CardInstance,
			pid: int) -> bool:
		var effects: Array = spell.data.spell_effects
		if spell.data.is_modal():
			var item := game.find_stack_item(spell)
			var mode: int = 0 if item == null else item.mode
			effects = spell.data.modes[clampi(mode, 0,
				spell.data.modes.size() - 1)]["effects"]
		for effect in effects:
			for land in game.players[pid].battlefield:
				if not land.is_land():
					continue
				if effect is DestroyAllEffect:
					# A sweeper (Armageddon): its own filter decides.
					if not effect.filter.is_valid() or effect.filter.call(land):
						return true
				elif effect is DestroyEffect and effect.target_spec != null \
						and effect.target_spec.is_legal(game,
							TargetRef.card(land), spell):
					return true
		return false

	func describe() -> String:
		return "counters a spell that would destroy one of your lands"
