extends CardScript
## Giant Shark — {5}{U} — Creature — Shark — 4/4 — (drk, common)
## Oracle: This creature can't attack unless defending player controls an
##         Island.
##         Whenever this creature blocks or becomes blocked by a creature
##         that has been dealt damage this turn, this creature gets +2/+0
##         and gains trample until end of turn.
##         When you control no Islands, sacrifice this creature.
##
## Implementation: the two Island clauses are the engine's printed fields
## (Merchant Ship's pair). The blood-in-the-water trigger listens on
## BLOCKED, which fires once per declared block PAIR, and asks whether the
## OTHER creature in the pair has been dealt damage this turn —
## CardInstance.damaged_by_this_turn, the engine's per-turn damage
## bookkeeping, which is non-empty exactly when damage actually landed
## (a fully prevented Lightning Bolt does not chum the water). Ganged up on
## by two wounded blockers, the Shark triggers twice — the ability is
## worded per creature.


func build() -> CardData:
	return CardData.new("Giant Shark", "{5}{U}", Mtg.CardType.CREATURE) \
		.pt(4, 4) \
		.with_subtypes(["shark"]) \
		.with_attack_needs_defender_land("island") \
		.with_sacrifice_if_no_land("island") \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BLOCKED, _frenzy,
			"Whenever this creature blocks or becomes blocked by a creature that has been dealt damage this turn, this creature gets +2/+0 and gains trample until end of turn.",
			_smells_blood)) \
		.oracle("This creature can't attack unless defending player controls an Island.\n"
			+ "Whenever this creature blocks or becomes blocked by a creature that has been "
			+ "dealt damage this turn, this creature gets +2/+0 and gains trample until end of turn.\n"
			+ "When you control no Islands, sacrifice this creature.")


## The pair is {attacker, blocker}; the Shark may be on either side, and it
## is the OTHER creature whose wounds matter.
static func _smells_blood(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	var attacker: CardInstance = event.data["attacker"]
	var blocker: CardInstance = event.data["blocker"]
	var other: CardInstance = null
	if attacker == source:
		other = blocker
	elif blocker == source:
		other = attacker
	return other != null and not other.damaged_by_this_turn.is_empty()


static func _frenzy(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	game.continuous.add_until_eot_pump(source.id, 2, 0, [Mtg.Keyword.TRAMPLE])
	game.recalculate()
