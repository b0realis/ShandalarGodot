extends CardScript
## Island Sanctuary — {1}{W} — Enchantment — (2ed, rare)
## Oracle: If you would draw a card during your draw step, instead you may
##         skip that draw. If you do, until your next turn, you can't be
##         attacked except by creatures with flying and/or islandwalk.
##
## Implementation: a real CR 614 replacement (CardData.draw_replacement) —
## the draw is REPLACED, so no card moves, no CARD_DRAWN fires, and an
## empty library cannot kill you through it. The offer is only made for the
## enchantment's own controller, and only in their own draw step.
##
## The shield is card-local memory: the turn the draw was skipped is written
## on the instance, and the static reads it. "Until your next turn" is that
## turn plus the opponent's — turns alternate, so the ban lifts as your next
## turn begins. Cast a second Island Sanctuary and each keeps its own memory.
##
## The ban itself is Moat's mechanism (CardInstance.cur_cant_attack) narrowed
## to the opponent's ground creatures, so LIVE keywords decide: a creature
## granted flying, or islandwalk by Scarwood Hag, walks straight in.
##
## The 1997 game called the offer `@ISLAND_SANCTUARY`, `Select draw
## potential.` (`Program/prompts.txt:495`).
##
## Note the QUESTION is asked from the draw step — a turn-based action, not
## a resolution — so the pre-flight cannot hold it open for a human seat
## (docs/ROADMAP.md, "draw replacements ask outside a resolution").


func build() -> CardData:
	return CardData.new("Island Sanctuary", "{1}{W}", Mtg.CardType.ENCHANTMENT) \
		.replaces_draws(_offer) \
		.static_ability(StaticAbility.new(
			_shield, "Until your next turn, you can't be attacked except by creatures with flying and/or islandwalk.")) \
		.oracle("If you would draw a card during your draw step, instead you may "
			+ "skip that draw. If you do, until your next turn, you can't be attacked "
			+ "except by creatures with flying and/or islandwalk.")


## The replacement. Returns true when the draw was skipped.
static func _offer(game: MtgGame, source: CardInstance, pid: int,
		ctx: Dictionary) -> bool:
	if pid != source.controller_id or not bool(ctx["in_draw_step"]):
		return false
	# `@ISLAND_SANCTUARY`, Program/prompts.txt:495 — the original's own words.
	if not game.agents[pid].choose_yes_no(game, pid, "Select draw potential.",
			_worth_it(game, source)):
		return false
	source.memory["closed_on_turn"] = game.turn_number
	game.log_line("%s skips their draw — the Island Sanctuary closes"
		% game.players[pid].player_name)
	# The shield is a STATIC reading that memory, so the pipeline has to be
	# told the memory changed — nothing else in this path recalculates.
	game.recalculate()
	return true


## The heuristic's answer: shut the gates when what is standing opposite
## could kill you this turn if it all got through.
static func _worth_it(game: MtgGame, source: CardInstance) -> bool:
	var pid := source.controller_id
	var incoming := 0
	for inst in game.players[game.opponent_of(pid)].battlefield:
		if inst.is_creature() and not _flies_or_swims(inst):
			incoming += inst.cur_power
	return incoming >= game.players[pid].life


static func _flies_or_swims(inst: CardInstance) -> bool:
	return inst.has_keyword(Mtg.Keyword.FLYING) or inst.cur_landwalk.has("island")


## While the gates are shut, the opponent's ground creatures can't attack.
static func _shield(game: MtgGame, source: CardInstance) -> void:
	var closed := int(source.memory.get("closed_on_turn", -1))
	# "Until your next turn": the turn it was closed, plus the one after it.
	if closed < 0 or game.turn_number > closed + 1:
		return
	for inst in game.players[game.opponent_of(source.controller_id)].battlefield:
		if inst.is_creature() and not _flies_or_swims(inst):
			inst.cur_cant_attack = true
