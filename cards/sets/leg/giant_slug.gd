extends CardScript
## Giant Slug — {1}{B} — Creature — Slug — 1/1 — (leg, common)
## Oracle: {5}: At the beginning of your next upkeep, choose a basic land
##         type. This creature gains landwalk of the chosen type until the
##         end of that turn. (It can't be blocked as long as defending
##         player controls a land of that type.)
##
## Implementation: the activation only ARMS the Slug — the landwalk itself
## arrives a whole turn later, which is the printed card's famous drawback
## and the reason it costs {5} for a 1/1's evasion. The arming is card-local
## memory (`armed_on_turn`), read by an upkeep trigger; a second activation
## in the same turn re-arms the same pending grant rather than stacking a
## second one, because "your next upkeep" is one moment.
##
## The type is chosen AT THAT UPKEEP, not at activation (DecisionAgent.
## choose_option, inside the trigger's resolution, so the pre-flight reaches
## it), and the heuristic names the type the defending player actually has
## most of — the only choice that does anything.
##
## The grant is until end of THAT turn, which is exactly
## GrantLandwalkEffect's until-EOT floating grant.


const BASIC_TYPES := ["plains", "island", "swamp", "mountain", "forest"]


func build() -> CardData:
	return CardData.new("Giant Slug", "{1}{B}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["slug"]) \
		.activated(ActivatedAbility.new("{5}", false, [ArmEffect.new()],
			"{5}: At the beginning of your next upkeep, this creature gains landwalk of a basic land type of your choice until end of turn.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _slither,
			"At the beginning of your next upkeep, choose a basic land type. This creature gains landwalk of the chosen type until the end of that turn.",
			_armed_and_yours)) \
		.oracle("{5}: At the beginning of your next upkeep, choose a basic land "
			+ "type. This creature gains landwalk of the chosen type until the end "
			+ "of that turn. (It can't be blocked as long as defending player "
			+ "controls a land of that type.)")


static func _armed_and_yours(game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	if int(event.data["player"]) != source.controller_id:
		return false
	var armed := int(source.memory.get("armed_on_turn", -1))
	# "Your NEXT upkeep": the arming turn's own upkeep has already gone by.
	return armed >= 0 and game.turn_number > armed


static func _slither(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	source.memory.erase("armed_on_turn")
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	var them := game.opponent_of(pid)
	# The heuristic names the type the DEFENDER actually has — the only
	# choice that makes the Slug unblockable.
	var best := 0
	var most := -1
	for i in BASIC_TYPES.size():
		var count := 0
		for inst in game.players[them].battlefield:
			if inst.has_subtype(BASIC_TYPES[i]):
				count += 1
		if count > most:
			most = count
			best = i
	var labels: Array[String] = []
	for t in BASIC_TYPES:
		labels.append(t.capitalize())
	var picked := game.agents[pid].choose_option(game, pid, labels,
		"Choose a basic land type for Giant Slug", best)
	var chosen: String = BASIC_TYPES[maxi(picked, 0)]
	game.continuous.add_until_eot_landwalk(source.id, [chosen], false)
	game.recalculate()
	game.log_line("Giant Slug gains %swalk" % chosen)


class ArmEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source == null or source.zone != Mtg.Zone.BATTLEFIELD:
			return
		source.memory["armed_on_turn"] = game.turn_number

	func describe() -> String:
		return "arms the Slug's landwalk for your next upkeep"
