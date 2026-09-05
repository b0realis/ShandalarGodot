extends CardScript
## Shimian Night Stalker — {3}{B}{B} — Creature — Nightstalker — 4/4 — (leg, uncommon)
## Oracle: {B}, {T}: All damage that would be dealt to you this turn by
##         target attacking creature is dealt to this creature instead.
##
## Implementation: an ALL-TURN player-side replacement
## (MtgPlayer.damage_replacements with "all_turn" set, so it is not consumed
## by the first packet) whose handler REDIRECTS the damage onto the Stalker
## itself. "All damage ... this turn" really is all of it: a first-strike
## blow and a normal one both land on the Stalker.
##
## Note what this is NOT: the Stalker does not block. It stays untapped —
## well, it taps to activate — and simply eats the damage from one attacker
## wherever that attacker's damage was going, which is why it answers a
## trampler and a creature with an evasion ability alike.
##
## If the Stalker has left the battlefield when the blow lands, the
## redirection has nowhere to go and the damage carries on to you (CR 614.6
## — a replacement that cannot be applied simply does not apply).


func build() -> CardData:
	return CardData.new("Shimian Night Stalker", "{3}{B}{B}",
			Mtg.CardType.CREATURE) \
		.pt(4, 4) \
		.with_subtypes(["nightstalker"]) \
		.activated(ActivatedAbility.new("{B}", true, [SoakEffect.new()],
			"{B}, {T}: All damage that would be dealt to you this turn by target attacking creature is dealt to this creature instead.")) \
		.oracle("{B}, {T}: All damage that would be dealt to you this turn by target "
			+ "attacking creature is dealt to this creature instead.")


class SoakEffect extends EffectBase:
	func _init() -> void:
		is_damage_prevention = true   # a redirection: legal in the window
		target_spec = TargetSpec.creature("target attacking creature") \
			.with_game_filter(SoakEffect._attacking)

	static func _attacking(game: MtgGame, inst: CardInstance) -> bool:
		return game.combat.attackers.has(inst.id)

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		if source == null:
			return
		var attacker := game.find_instance(target.instance_id)
		if attacker == null:
			return
		game.players[controller].damage_replacements.append({
			"desc": "Shimian Night Stalker",
			"filter": SoakEffect._from_that_attacker.bind(attacker.id),
			"apply": SoakEffect._soak.bind(source.id),
			"all_turn": true,
		})
		game.log_line("%s steps in front of %s" % [
			source.data.card_name, attacker.data.card_name])

	static func _from_that_attacker(_game: MtgGame, packet: DamagePacket,
			attacker_id: int) -> bool:
		return packet.source_id() == attacker_id

	static func _soak(game: MtgGame, packet: DamagePacket,
			stalker_id: int) -> int:
		var stalker := game.find_instance(stalker_id)
		if stalker == null or stalker.zone != Mtg.Zone.BATTLEFIELD:
			return -1   # nothing left to take the blow (CR 614.6)
		return game.redirect_damage(packet, TargetRef.card(stalker))

	func describe() -> String:
		return "takes all of one attacker's damage on itself this turn"
