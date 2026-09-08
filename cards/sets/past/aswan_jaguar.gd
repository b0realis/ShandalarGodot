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
## "Deck" is the LIBRARY [1997]: Duel.hlp's Library topic calls the two
## face-down piles "the dueling decks, each of which is now considered to
## be a player's library", and RandomEffects.creature_type_of rolls over
## the distinct creature types in that pile alone — each type once, however
## many cards carry it (the Manalink rewrite's "equal chance for each
## creature type present in opponent's library, no matter how many times it
## appears", and mage-go's ChooseRandomCreatureSubtypeFromTargetLibrary).
## A type that is only in their hand, on the table or in their graveyard
## cannot come up, and a library with no creature card left leaves the
## Jaguar hunting nothing — its ability then has no legal target. The 1997
## FAQ's "in deck or graveyard" (s30/shandalar-faq.txt) is the one witness
## for the graveyard, a secondary paraphrase the printed text outranks;
## the roll scanned four zones until 2026-09-07.
##
## THE CHOICE IS SHOWN (2026-09-08, `[QoL]`): `.with_chosen_type("type")`
## tells the duel screen where the roll lives, and it draws the chosen
## type as a ghost card behind the Jaguar, titled with the type, so the
## player reads at a glance what the Jaguar hunts — the owner: *"The
## chosen creature type name should be present as a back mini card like
## aura - with creature type as it name on the aura card top, so player
## quickly knows which type was randomly chosen!"* The engine's log line
## below was the only witness before that.
##
## ONE WORD IS ENOUGH: a creature of two types is of the chosen type if
## either matches — `has_subtype` — so a Jaguar that chose Elf takes a
## Llanowar Elves (Elf Druid), and one that chose Druid takes it too.
## The owner's ruling, 2026-09-08: *"if just one word matches from the
## jaguar selection to the creature type then the jaguar can take it."*


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
		.with_chosen_type("type") \
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
