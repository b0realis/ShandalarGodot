extends CardScript
## Runesword — {6} — Artifact — (drk, uncommon)
## Oracle: {3}, {T}: Target attacking creature gets +2/+0 until end of turn.
##         When that creature leaves the battlefield this turn, sacrifice
##         this artifact. If the creature deals damage to a creature this
##         turn, the creature dealt damage can't be regenerated this turn.
##         If a creature dealt damage by the targeted creature would die
##         this turn, exile that creature instead.
##
## Implementation: four clauses off one activation.
## - The +2/+0 is an ordinary until-EOT pump.
## - The last two clauses are one floating watch on the SWORDBEARER
##   (MtgGame.watch_damage_dealt, new): whenever it deals damage to a
##   creature this turn, that victim is marked
##   `regeneration_banned_this_turn` and `exile_instead_of_dying`. The watch
##   is per-turn and outlives the Runesword, which is what "this turn"
##   demands.
## - "When that creature leaves the battlefield this turn, sacrifice this
##   artifact" is a LEAVES_BATTLEFIELD trigger, gated on the id the
##   Runesword wrote into its own memory when the ability resolved, and on
##   the turn it did so.
##
## The exile clause is the reason to swing a Runesword at a Sengir Vampire:
## the body never reaches a graveyard for anything to raise.


func build() -> CardData:
	return CardData.new("Runesword", "{6}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{3}", true, [ArmEffect.new()],
			"{3}, {T}: Target attacking creature gets +2/+0 until end of turn, and creatures it damages this turn can't be regenerated and are exiled if they die.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.LEAVES_BATTLEFIELD, _break_the_sword,
			"When that creature leaves the battlefield this turn, sacrifice this artifact.",
			_it_was_mine)) \
		.oracle("{3}, {T}: Target attacking creature gets +2/+0 until end of turn. "
			+ "When that creature leaves the battlefield this turn, sacrifice this "
			+ "artifact. If the creature deals damage to a creature this turn, the "
			+ "creature dealt damage can't be regenerated this turn. If a creature "
			+ "dealt damage by the targeted creature would die this turn, exile that "
			+ "creature instead.")


static func _it_was_mine(game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return false
	if int(source.memory.get("armed_on_turn", -1)) != game.turn_number:
		return false
	var gone: CardInstance = event.data["instance"]
	return int(source.memory.get("bearer", -1)) == gone.id


static func _break_the_sword(game: MtgGame, source: CardInstance,
		_event: GameEvent) -> void:
	if source.zone == Mtg.Zone.BATTLEFIELD:
		game.sacrifice_permanent(source)


class ArmEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature("target attacking creature") \
			.with_game_filter(ArmEffect._attacking)

	static func _attacking(game: MtgGame, inst: CardInstance) -> bool:
		return game.combat.attackers.has(inst.id)

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var bearer := game.find_instance(target.instance_id)
		if bearer == null or bearer.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.continuous.add_until_eot_pump(bearer.id, 2, 0)
		game.recalculate()
		if source != null and source.zone == Mtg.Zone.BATTLEFIELD:
			source.memory["bearer"] = bearer.id
			source.memory["armed_on_turn"] = game.turn_number
		game.watch_damage_dealt(bearer, ArmEffect._curse)

	## Everything the Runesword's edge does to what it cuts.
	static func _curse(game: MtgGame, _source: CardInstance,
			victim: CardInstance, _amount: int) -> void:
		victim.regeneration_banned_this_turn = true
		victim.exile_instead_of_dying = true
		game.log_line("%s is cut by the Runesword" % victim.data.card_name)

	func describe() -> String:
		return "arms an attacker: +2/+0, and what it cuts is exiled"
