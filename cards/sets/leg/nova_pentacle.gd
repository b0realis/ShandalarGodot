extends CardScript
## Nova Pentacle — {4} — Artifact — (leg, rare)
## Oracle: {3}, {T}: The next time a source of your choice would deal damage
##         to you this turn, that damage is dealt to target creature of an
##         opponent's choice instead.
##
## Implementation: a one-shot player-side replacement
## (MtgPlayer.damage_replacements) whose handler REDIRECTS the packet
## (MtgGame.redirect_damage) — the same damage, landing somewhere else, so
## everything downstream still sees one event.
##
## Whose choice is what makes this card. The creature that eats the damage
## is a TARGET the OPPONENT chooses (TargetSpec.opponent_chooses), named
## as the ability is activated (CR 601.2c) through the same hold that
## asks a human which body a sacrifice cost eats: with no creature on the
## battlefield the ability can't be activated, a creature with shroud is
## not on their list, and the ability fizzles if what they named leaves
## before it resolves. "Target creature" is ANY creature — the printed
## text does not say "they control", so the opponent may name one of
## YOURS — and their list is ordered from their point of view: your
## creatures first (your best), then the one of theirs they would miss
## least. Should that creature be gone by the time the damage would land,
## there is nothing to redirect to and it lands on you after all.
##
## The SOURCE is yours, chosen as the ability resolves from every object
## that could deal damage — each permanent on either side and each spell
## on the stack. Your own sources qualify: a Pestilence you control is a
## source of your choice too (docs/audit-vs-s30.md, 2026-09-01).


func build() -> CardData:
	return CardData.new("Nova Pentacle", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{3}", true, [PentacleEffect.new()],
			"{3}, {T}: The next time a source of your choice would deal damage to you this turn, that damage is dealt to target creature of an opponent's choice instead.")) \
		.oracle("{3}, {T}: The next time a source of your choice would deal damage "
			+ "to you this turn, that damage is dealt to target creature of an "
			+ "opponent's choice instead.")


class PentacleEffect extends EffectBase:
	func _init() -> void:
		is_damage_prevention = true   # a redirection: legal in the window
		target_spec = TargetSpec.creature(
				"target creature of an opponent's choice") \
			.opponent_chooses(PentacleEffect._their_order,
				"Select target creature.")

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var victim := game.find_instance(target.instance_id)
		if victim == null or victim.zone != Mtg.Zone.BATTLEFIELD:
			return
		# Every permanent and every spell on the stack (MtgGame.
		# damage_sources, CR 609.7), ranked so the first entry is the one
		# about to deal damage to the activator — the heuristic's pick.
		var candidates := game.damage_sources(Callable(), TargetRef.player(controller))
		if candidates.is_empty():
			return
		var pick := game.agents[controller].choose_card(game, controller,
			candidates, "Choose a source for Nova Pentacle", false, false, true)
		if pick == null or not candidates.has(pick):
			pick = candidates[0]
		game.players[controller].damage_replacements.append({
			"desc": "Nova Pentacle",
			"filter": PentacleEffect._from_that_source.bind(pick.id),
			"apply": PentacleEffect._deflect.bind(victim.id),
		})
		game.log_line("Nova Pentacle watches %s, for %s" % [
			pick.data.card_name, victim.data.card_name])

	static func _from_that_source(_game: MtgGame, packet: DamagePacket,
			chosen_id: int) -> bool:
		return packet.source_id() == chosen_id

	## Onto the creature the opponent named — if it is still there.
	static func _deflect(game: MtgGame, packet: DamagePacket,
			victim_id: int) -> int:
		var victim := game.find_instance(victim_id)
		if victim == null or victim.zone != Mtg.Zone.BATTLEFIELD \
				or not victim.is_creature():
			return -1   # nothing to deflect onto: it lands on you after all
		return game.redirect_damage(packet, TargetRef.card(victim))

	## THEIR order: the activator's creatures first, their best first;
	## then their own, cheapest first.
	static func _their_order(game: MtgGame, source: CardInstance,
			a_ref: TargetRef, b_ref: TargetRef) -> bool:
		var a := game.find_instance(a_ref.instance_id)
		var b := game.find_instance(b_ref.instance_id)
		var a_theirs := source != null and a.controller_id == source.controller_id
		var b_theirs := source != null and b.controller_id == source.controller_id
		if a_theirs != b_theirs:
			return a_theirs
		var va := a.data.cost.mana_value() * 10 + a.cur_power + a.cur_toughness
		var vb := b.data.cost.mana_value() * 10 + b.cur_power + b.cur_toughness
		if va != vb:
			return va > vb if a_theirs else va < vb
		return a.id < b.id

	func describe() -> String:
		return "the next damage from one source hits a creature of their choice"
