extends CardScript
## Wall of Caltrops — {1}{W} — Creature — Wall — 2/1 — (leg, common)
## Oracle: Defender
##         Whenever this creature blocks a creature, if at least one other
##         Wall creature is blocking that creature and no non-Wall creatures
##         are blocking that creature, this creature gains banding until end
##         of turn.
##
## Implementation: the trigger and its two conditions are real — it reads
## the whole block group of the attacker it just blocked and grants itself
## banding when the wall of Walls is unbroken. Being an INTERVENING "IF"
## clause, that condition is tested twice: when the trigger would go on
## the stack and again as it resolves (CR 603.4), so killing the other
## Wall in response takes the banding away. A blocker that has left the
## battlefield is no longer blocking (CR 506.4) and no longer counts.
##
## The grant does the printed work: a blocking band with banding in it puts
## the attacker's damage division in the DEFENDING player's hands
## (CR 702.22f-h), which is the entire reason a Wall wants the keyword.
## The trigger resolves while blockers are declared, so the banding is
## already live when the damage step divides.


func build() -> CardData:
	return CardData.new("Wall of Caltrops", "{1}{W}", Mtg.CardType.CREATURE) \
		.pt(2, 1) \
		.with_subtypes(["wall"]) \
		.with_keywords([Mtg.Keyword.DEFENDER]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BLOCKED, _band_up,
			"Whenever this creature blocks a creature, if at least one other Wall creature is blocking that creature and no non-Wall creatures are blocking that creature, this creature gains banding until end of turn.",
			_wall_only_gang)) \
		.oracle("Defender (This creature can't attack.)\nWhenever this creature blocks a creature, if at least one other Wall creature is blocking that creature and no non-Wall creatures are blocking that creature, this creature gains banding until end of turn.")


static func _wall_only_gang(game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	if event.data.get("blocker") != source:
		return false
	var attacker: CardInstance = event.data.get("attacker")
	if attacker == null:
		return false
	var other_walls := 0
	for blocker_id in game.combat.blockers_of(attacker.id):
		var blocker := game.find_instance(blocker_id)
		if blocker == null or blocker.zone != Mtg.Zone.BATTLEFIELD:
			continue   # it left combat when it left the battlefield (506.4)
		if not blocker.has_subtype("wall"):
			return false          # a non-Wall is in the gang
		if blocker != source:
			other_walls += 1
	return other_walls >= 1


static func _band_up(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	if not _wall_only_gang(game, source, event):
		return   # the intervening "if", tested again on resolution (603.4)
	game.continuous.add_until_eot_pump(source.id, 0, 0, [Mtg.Keyword.BANDING])
	game.recalculate()
