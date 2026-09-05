extends CardScript
## Aswan Jaguar — {1}{G}{G} — Creature — Jaguar — 2/2 — (past, common)
## Oracle: When Aswan Jaguar comes into play, choose a random creature type
##         from those in target opponent's deck.
##         {G}{G}, {T}: Bury target creature of the chosen type.
##
## Implementation: the chosen type lives in the Jaguar's own memory, and the
## ability's target filter reads it back through a source-aware filter, so
## two Jaguars can hunt two different types. "Bury" is the 1997 wording for
## destroy-without-regeneration. With one opponent per duel, "target
## opponent's deck" is that opponent's — no target choice to make.
##
## SIMPLIFIED (docs/simplified-cards.md, "Aswan Jaguar"): the roll is over
## the creature types in the opponent's DECK, i.e. their library;
## RandomEffects.creature_type_of also scans their hand, battlefield and
## graveyard, so a type that is nowhere in the deck can come up (and one
## buried deep in an empty-of-creatures library cannot be missed). Fixing
## it belongs in that engine helper — mage-go's
## ChooseRandomCreatureSubtypeFromTargetLibrary reads the library only.


static func _matches_chosen(_game: MtgGame, source: CardInstance,
		inst: CardInstance) -> bool:
	var wanted: String = String(source.memory.get("type", ""))
	return wanted != "" and inst.has_subtype(wanted)


func build() -> CardData:
	var spec := TargetSpec.creature("target creature of the chosen type")
	spec.with_source_filter(_matches_chosen)
	return CardData.new("Aswan Jaguar", "{1}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["jaguar"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _choose_type,
			"When Aswan Jaguar comes into play, choose a random creature type from those in target opponent's deck.",
			_is_self)) \
		.activated(ActivatedAbility.new("{G}{G}", true, [BuryEffect.new(spec)],
			"{G}{G}, {T}: Bury target creature of the chosen type.")) \
		.oracle("When Aswan Jaguar comes into play, choose a random creature type from those in target opponent's deck.\n{G}{G}, {T}: Bury target creature of the chosen type.")


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _choose_type(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var victim := game.opponent_of(source.controller_id)
	# SIMPLIFIED (see the header): "from those in target opponent's DECK",
	# but this helper scans library + hand + battlefield + graveyard.
	var chosen := RandomEffects.creature_type_of(game, victim)
	source.memory["type"] = chosen
	if chosen != "":
		game.log_line("Aswan Jaguar chooses %s" % chosen)


class BuryEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst != null and inst.zone == Mtg.Zone.BATTLEFIELD:
			game.destroy(inst, false)   # "bury" = can't be regenerated

	func describe() -> String:
		return "buries target creature of the chosen type"
