extends CardScript
## Forcefield — {3} — Artifact — (2ed, rare)
## Oracle: {1}: The next time an unblocked creature of your choice would
##         deal combat damage to you this turn, prevent all but 1 of that
##         damage.
##
## Implementation: the engine's one-shot player-side replacement list
## (MtgPlayer.damage_replacements) — the shared shape behind the whole
## "the next time a source of your choice would deal damage to you this
## turn" family. The creature is chosen when the ability RESOLVES, and the
## filter then catches exactly one packet: combat damage, from that
## creature, and only while it is genuinely unblocked (CR 509.1h — a
## blocked attacker whose blocker died is still blocked, and its trample
## spill-over is not what Forcefield stops).
##
## "Prevent all but 1" leaves one point through: the handler prevents
## amount - 1 and returns -1, which is the contract's "carry on with what is
## left" — so a Circle of Protection can still answer that last point, and
## the packet honestly records what was prevented.
##
## One activation per attacker: against a real board you pay {1} per
## creature, which is the whole cost of the card.


func build() -> CardData:
	return CardData.new("Forcefield", "{3}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{1}", false, [ShieldEffect.new()],
			"{1}: The next time an unblocked creature of your choice would deal combat damage to you this turn, prevent all but 1 of that damage.")) \
		.oracle("{1}: The next time an unblocked creature of your choice would deal "
			+ "combat damage to you this turn, prevent all but 1 of that damage.")


class ShieldEffect extends EffectBase:
	func _init() -> void:
		is_damage_prevention = true   # legal in the 1997 window (§6.8)

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var them := game.opponent_of(controller)
		var candidates: Array[CardInstance] = []
		for inst in game.players[them].battlefield:
			if inst.is_creature():
				candidates.append(inst)
		if candidates.is_empty():
			game.log_line("Forcefield finds nothing to brace against")
			return
		# The biggest attacker first: the one a player would name.
		candidates.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			return a.cur_power > b.cur_power)
		var pick := game.agents[controller].choose_card(game, controller,
			candidates, "Choose a creature for Forcefield")
		if pick == null or not candidates.has(pick):
			pick = candidates[0]
		game.players[controller].damage_replacements.append({
			"desc": "Forcefield",
			"filter": ShieldEffect._unblocked_combat_damage.bind(pick.id),
			"apply": ShieldEffect._all_but_one,
		})
		game.log_line("Forcefield braces against %s" % pick.data.card_name)

	static func _unblocked_combat_damage(game: MtgGame, packet: DamagePacket,
			chosen_id: int) -> bool:
		if not packet.is_combat or packet.source_id() != chosen_id:
			return false
		return not game.combat.was_blocked(game.combat.band_of(chosen_id))

	static func _all_but_one(_game: MtgGame, packet: DamagePacket) -> int:
		packet.prevent(packet.remaining() - 1)
		return -1   # one point carries on through the usual gates

	func describe() -> String:
		return "prevents all but 1 of one unblocked attacker's damage"
