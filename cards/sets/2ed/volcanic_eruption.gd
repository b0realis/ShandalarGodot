extends CardScript
## Volcanic Eruption — {X}{U}{U}{U} — Sorcery — (2ed, rare)
## Oracle: Destroy X target Mountains. Volcanic Eruption deals damage to
##         each creature and each player equal to the number of Mountains
##         put into a graveyard this way.
##
## Implementation: one effect for both sentences — the second counts the
## Mountains the first actually buried, so a Mountain that was regenerated
## or had already left doesn't add to the blast. Destruction is plain
## destroy (Mountains may be regenerated, and the count then drops).
##
## THE BLAST IS ONE EVENT (2026-09-09). "…to each creature and each
## player" is a single damage event, so nothing may be swept off the board
## or out of the game until every packet has landed (CR 704.3) — the same
## bracket [DamageAllEffect] puts round an Earthquake. Without it the
## loop below dealt to each player in turn, the state-based check fired
## between the two, and an Eruption lethal to BOTH duelists ended as a win
## for the opponent instead of the draw CR 104.4b calls for (probed at
## three life a side: P0 -1 and lost, P1 -1 and not, winner 1).
##
## AND SO IS THE WHOLE RESOLUTION (2026-09-10). The bracket now opens
## before the DESTROYS as well: CR 704.3 checks state-based actions when a
## player would receive priority, never in the middle of one resolution,
## and "destroy X target Mountains" is the same resolution as the blast.
## NOTHING IN THIS POOL COULD SEE THE DIFFERENCE, and the survey is the
## point rather than a bug — [method MtgGame.destroy] and
## MtgGame._move_to_graveyard never check state-based actions themselves,
## a land's dies- and leave-triggers go on the STACK (only a mana trigger
## resolves off-stack, CR 605.1b, and the pool's three all watch
## TAPPED_FOR_MANA), the two death replacements that would route a
## permanent through a checking helper are set by nothing that can name a
## land (Disintegrate, Runesword and Whippoorwill all read "target
## creature"), and no LAND carries an immediate leave hook
## (CardData.as_it_leaves has three users, none of them a land). Dingus
## Egg, the one card that watches a land reach a graveyard, is an ordinary
## stacked trigger and cannot act until this has finished resolving. So
## the bracket is here for the rule, and
## tests/cards/test_erupt_bracket_2026_09_10.gd is a rule test.


static func _is_mountain(inst: CardInstance) -> bool:
	return inst.is_land() and inst.has_subtype("mountain")


func build() -> CardData:
	# `subtype`: the filter asks for a land SUBTYPE, so that is the word
	# the 1997 refusal uses (`@PROMPT_ILLEGALTARGETWHY` entry 10, §6.10).
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target Mountain",
		_is_mountain).because(TargetSpec.WHY["subtype"])
	return CardData.new("Volcanic Eruption", "{X}{U}{U}{U}", Mtg.CardType.SORCERY) \
		.spell(EruptEffect.new(spec)) \
		.oracle("Destroy X target Mountains. Volcanic Eruption deals damage to each creature and each player equal to the number of Mountains put into a graveyard this way.")


class EruptEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec
		x_targets()

	func resolve_multi(game: MtgGame, source: CardInstance, _controller: int,
			targets: Array, _x_value: int = 0) -> void:
		# ONE RESOLUTION, ONE BRACKET (CR 704.3 / 104.4b) — see the note at
		# the top of the file. It opens before the first destroy and closes
		# after the last packet, and every exit from here runs through the
		# close: a deferral left open freezes state-based actions for the
		# rest of the game.
		game.begin_simultaneous()
		var buried := 0
		for ref in targets:
			var inst := game.find_instance(ref.instance_id)
			if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
				continue
			game.destroy(inst)
			if inst.zone == Mtg.Zone.GRAVEYARD:
				buried += 1
		if buried > 0:
			for inst in game.all_battlefield():
				if inst.is_creature():
					game.deal_damage(source, TargetRef.card(inst), buried)
			for p in game.players:
				if not p.has_lost:
					game.deal_damage(source, TargetRef.player(p.id), buried)
		game.end_simultaneous()

	func describe() -> String:
		return "destroys X target Mountains, then deals that much damage to each creature and each player"
