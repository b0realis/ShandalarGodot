extends CardScript
## Enchantment Alteration — {U} — Instant — (leg, common)
## Oracle: Attach target Aura attached to a creature or land to another
##         permanent of that type.
##
## Implementation: a one-mana theft of somebody else's Aura placement. The
## target is the AURA (not its host), and only one attached to a creature
## or to a land — the spec says so, so an Aura on an artifact or on another
## enchantment cannot be moved. The destination is "another permanent of
## THAT TYPE": a creature Aura goes to another creature, a land Aura to
## another land, and never across.
##
## The move itself is MtgGame.move_aura, which re-attaches with no zone
## change (CR 701.3), so a Control Magic really does hand its new host over
## and an Aura carrying counters keeps them. Candidates are filtered
## through the Aura's own attachment legality, so a Cursed Land cannot be
## dropped on something it could never enchant.
##
## The choice on resolution is the acting seat's own, asked through their
## DecisionAgent: a human seat is held open on it (docs/duel-todo.md
## §1.3) and every other seat answers for itself. The value the card
## computes is only the HINT, and the candidates are pre-sorted for it.


func build() -> CardData:
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"target Aura attached to a creature or land", _movable_aura)
	return CardData.new("Enchantment Alteration", "{U}", Mtg.CardType.INSTANT) \
		.spell(AlterEffect.new(spec)) \
		.oracle("Attach target Aura attached to a creature or land to another permanent of that type.")


static func _movable_aura(inst: CardInstance) -> bool:
	if not inst.data.is_aura() or inst.attached_to == -1:
		return false
	return true


class AlterEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		spec.with_game_filter(_host_is_a_creature_or_land)
		target_spec = spec

	static func _host_is_a_creature_or_land(game: MtgGame, inst: CardInstance) -> bool:
		var host := game.find_instance(inst.attached_to)
		if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
			return false
		return host.is_creature() or host.is_land()

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var aura := game.find_instance(target.instance_id)
		if aura == null or aura.zone != Mtg.Zone.BATTLEFIELD:
			return
		var host := game.find_instance(aura.attached_to)
		if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
			return
		var want_creature := host.is_creature()
		var candidates: Array[CardInstance] = []
		for inst in game.all_battlefield():
			if inst == host or inst == aura:
				continue
			if want_creature and not inst.is_creature():
				continue
			if not want_creature and not inst.is_land():
				continue
			if aura.data.aura_target != null \
					and not aura.data.aura_target.can_attach_to(game, inst):
				continue
			candidates.append(inst)
		if candidates.is_empty():
			return
		# The HINT: a harmful Aura (one its controller aimed at somebody
		# else) is pushed onto the enemy's biggest permanent; a helpful one
		# onto our own.
		var hostile := aura.controller_id != host.controller_id
		var wanted := game.opponent_of(controller) if hostile else controller
		candidates.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			var a_key := int(a.controller_id == wanted) * 100 + a.cur_power + a.cur_toughness
			var b_key := int(b.controller_id == wanted) * 100 + b.cur_power + b.cur_toughness
			return a_key > b_key)
		var pick := game.agents[controller].choose_card(game, controller, candidates,
			"Attach %s to" % aura.data.card_name)
		game.move_aura(aura, pick if pick != null and candidates.has(pick) else candidates[0])

	func describe() -> String:
		return "moves target Aura to another permanent of its host's type"
