extends CardScript
## Wall of Dust — {2}{R} — Creature — Wall — 1/4 — (4ed, uncommon)
## Oracle: Defender (This creature can't attack.)
##         Whenever this creature blocks a creature, that creature can't
##         attack during its controller's next turn.
##
## Implementation: a BLOCKED trigger (self as the BLOCKER only) raising
## the attacker's cant_attack_next_turn flag; the engine's untap step
## converts it into a this-turn ban and expires it a turn later.


func build() -> CardData:
	return CardData.new("Wall of Dust", "{2}{R}", Mtg.CardType.CREATURE) \
		.pt(1, 4) \
		.with_subtypes(["wall"]) \
		.with_keywords([Mtg.Keyword.DEFENDER]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BLOCKED, _choke,
			"Whenever this creature blocks a creature, that creature can't attack during its controller's next turn.",
			_self_blocks)) \
		.oracle("Defender\nWhenever this creature blocks a creature, that creature can't attack during its controller's next turn.")


static func _self_blocks(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data["blocker"] == source


static func _choke(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	var attacker: CardInstance = event.data["attacker"]
	if attacker != null and attacker.zone == Mtg.Zone.BATTLEFIELD:
		attacker.cant_attack_next_turn = true
		game.log_line("%s can't attack during its controller's next turn" %
			attacker.data.card_name)
