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
## with the Equinox on it hands the ability to the thief. The grant is a
## CR 613 layer-6 effect at the Aura's timestamp (changing_abilities, CR
## 613.7): on a land that is a creature (Living Lands), a Humility that
## entered after the Equinox removes the ability, one before it does not.
##
## "If it would destroy a land you control" is judged when the ability
## RESOLVES, because it is a condition on the effect and not on the target —
## the spell is a legal target either way, and Equinox simply does nothing
## to a Lightning Bolt. What counts as land destruction is the spell's own
## effects: a DestroyAllEffect whose filter a land you control satisfies
## (Armageddon, Tsunami), or a destroying effect whose CHOSEN TARGETS
## include a land you control (Stone Rain, Sinkhole, a Desert Twister aimed
## at your land, Volcanic Eruption's Mountains — an effect of a card's own
## that destroys its targets says so with `destroys_its_targets`).
##
## Until the bug hunt of 2026-10-21 a targeted destroy was judged by its
## SPEC — "could this spell legally have named one of your lands?" — so a
## Desert Twister or a Fissure aimed at your creature was countered, and
## Volcanic Eruption (its own effect class) was never recognised at all.


func build() -> CardData:
	return CardData.new("Equinox", "{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "enchant land",
			_is_land)) \
		.static_ability(StaticAbility.new(
			_grant, "Enchanted land has \"{T}: Counter target spell if it would destroy a land you control.\"") \
			.changing_abilities()) \
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
		var item := game.find_stack_item(spell)
		var effects: Array = spell.data.spell_effects
		if spell.data.is_modal():
			var mode: int = 0 if item == null else item.mode
			effects = spell.data.modes[clampi(mode, 0,
				spell.data.modes.size() - 1)]["effects"]
		var slot := 0   # each targeting effect owns one target group, in order
		for effect in effects:
			var group: Array = []
			if effect.target_spec != null:
				group = WardEffect._group_of(item, slot)
				slot += 1
			if effect is DestroyAllEffect:
				# A sweeper (Armageddon): its own filter decides.
				for land in game.players[pid].battlefield:
					if land.is_land() and (not effect.filter.is_valid() \
							or effect.filter.call(land)):
						return true
			elif effect is DestroyEffect or (&"destroys_its_targets" in effect
					and effect.get(&"destroys_its_targets") == true):
				for ref in group:
					if ref == null or ref.is_player or ref.is_damage or ref.is_ability:
						continue
					var aimed := game.find_instance(ref.instance_id)
					if aimed != null and aimed.zone == Mtg.Zone.BATTLEFIELD \
							and aimed.is_land() and aimed.controller_id == pid:
						return true
		return false

	## The refs [param item] chose for its [param slot]-th targeting effect —
	## the grouping `MtgGame._run_effects_impl` resolves with.
	static func _group_of(item: StackItem, slot: int) -> Array:
		if item == null:
			return []
		if slot < item.target_groups.size():
			return item.target_groups[slot]
		if slot < item.targets.size():
			return [item.targets[slot]]
		return []

	func describe() -> String:
		return "counters a spell that would destroy one of your lands"
