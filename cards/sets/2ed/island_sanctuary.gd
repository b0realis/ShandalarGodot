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
## The shield is the REPLACEMENT's effect, not a static of the enchantment
## (2026-10-03): skipping the draw registers a floating static
## (ContinuousEffects.add_floating_static) that lasts until the skipping
## player's next untap step — "until your next turn" (Duration.
## UNTIL_UNTAP_OF) — whatever becomes of the Sanctuary, and however many
## turns (Time Walk, Stolen Time) come in between. It used to be a static
## reading the turn number off the Sanctuary's memory, so destroying the
## Sanctuary dropped the shield and an opponent's extra turn outlasted it.
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
		.replaces_draws(_offer, _catches) \
		.oracle("If you would draw a card during your draw step, instead you may "
			+ "skip that draw. If you do, until your next turn, you can't be attacked "
			+ "except by creatures with flying and/or islandwalk.")


## The pure half (CR 616.1): the Sanctuary offers itself for its own
## controller's draws, and only in their own draw step — ANY draw in it,
## which is how it can meet Chains of Mephistopheles over a Howling Mine's
## extra card. Asked before any replacement runs, so it puts no question to
## anybody.
static func _catches(_game: MtgGame, source: CardInstance, pid: int,
		ctx: Dictionary) -> bool:
	return pid == source.controller_id and bool(ctx["in_draw_step"])


## The replacement. Returns true when the draw was skipped.
static func _offer(game: MtgGame, source: CardInstance, pid: int,
		ctx: Dictionary) -> bool:
	if pid != source.controller_id or not bool(ctx["in_draw_step"]):
		return false
	# `@ISLAND_SANCTUARY`, Program/prompts.txt:495 — the original's own words.
	if not game.agents[pid].choose_yes_no(game, pid, "Select draw potential.",
			_worth_it(game, source)):
		return false
	game.continuous.add_floating_static(source, StaticAbility.new(
			_shield.bind(pid), "Until your next turn, you can't be attacked "
			+ "except by creatures with flying and/or islandwalk."),
		ContinuousEffects.Duration.UNTIL_UNTAP_OF, pid)
	game.log_line("%s skips their draw — the Island Sanctuary closes"
		% game.players[pid].player_name)
	# Nothing else in this path recalculates.
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


## While the gates are shut, the opponent's ground creatures can't attack
## [param pid] — the player who skipped the draw, fixed as it was skipped.
static func _shield(game: MtgGame, _source: CardInstance, pid: int) -> void:
	for inst in game.players[game.opponent_of(pid)].battlefield:
		if inst.is_creature() and not _flies_or_swims(inst):
			inst.cur_cant_attack = true
