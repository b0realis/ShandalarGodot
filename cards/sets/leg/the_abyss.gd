extends CardScript
## The Abyss — {3}{B} — World Enchantment — (leg, rare)
## Oracle: At the beginning of each player's upkeep, destroy target
##         nonartifact creature that player controls of their choice. It
##         can't be regenerated.
##
## Implementation: an UPKEEP_START trigger. The victim is chosen by THAT
## PLAYER (the printed "of their choice") through their DecisionAgent, so
## the AI picks its own worst creature; the destruction is marked
## can_regenerate = false. Artifact creatures are immune — the reason
## every Abyss deck of the era ran Su-Chi and friends. A WORLD permanent.
##
## The clause says "destroy TARGET nonartifact creature", so the choice is
## made from LEGAL TARGETS only: protection from black (CR 702.16b) and
## shroud take a creature out of the running entirely, and the player then
## offers the best of what is left. The Abyss's own TargetSpec decides,
## exactly as it would for a spell.


static func _is_nonartifact_creature(inst: CardInstance) -> bool:
	return not inst.is_type(Mtg.CardType.ARTIFACT)


## "target nonartifact creature that player controls" — the spec the
## chooser is filtered through, so every targeting ban the engine knows
## about applies without this card restating any of them.
static func _abyss_spec() -> TargetSpec:
	return TargetSpec.creature("target nonartifact creature",
		_is_nonartifact_creature)


func build() -> CardData:
	return CardData.new("The Abyss", "{3}{B}", Mtg.CardType.ENCHANTMENT) \
		.with_supertypes(Mtg.Supertype.WORLD) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _devour,
			"At the beginning of each player's upkeep, destroy target nonartifact "
			+ "creature that player controls of their choice. It can't be regenerated.")) \
		.oracle("At the beginning of each player's upkeep, destroy target nonartifact "
			+ "creature that player controls of their choice. It can't be regenerated.")


static func _devour(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var pid := int(event.data["player"])
	var spec := _abyss_spec()
	var candidates: Array[CardInstance] = []
	for inst in game.all_battlefield():
		if inst.controller_id != pid:
			continue
		# TARGET legality, not just "is a nonartifact creature": pro-black
		# and shrouded creatures are not choices at all (CR 702.16b, 702.18).
		if spec.is_legal(game, TargetRef.card(inst), source):
			candidates.append(inst)
	if candidates.is_empty():
		return
	var victim := game.agents[pid].choose_card(game, pid, candidates,
		"The Abyss: choose a nonartifact creature to be destroyed")
	if victim == null or not candidates.has(victim):
		victim = candidates[0]
	game.destroy(victim, false)
