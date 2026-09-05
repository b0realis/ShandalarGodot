extends CardScript
## Jihad — {W}{W}{W} — Enchantment — (arn, rare)
## Oracle: As this enchantment enters, choose a color and an opponent.
##         White creatures get +2/+1 as long as the chosen player controls
##         a nontoken permanent of the chosen color.
##         When the chosen player controls no nontoken permanents of the
##         chosen color, sacrifice this enchantment.
##
## Implementation: an ETB trigger remembering the opponent and the colour
## in the enchantment's card-local memory (in a duel the opponent picks
## itself; the colour is the one they hold MOST of, which is the choice a
## player would make), plus a static anthem gated on that colour still
## being on their board, and a CardData.sacrifices_when clause (checked as
## a state-based action, exactly like Sea Serpent's "when you control no
## Islands") that buries Jihad the moment that colour is gone.
##
## "As Jihad enters, choose a colour and an opponent" — the colour is the
## CASTER's, asked through their DecisionAgent on the arrival trigger, with
## the colour the chosen opponent holds most of as the hint. (With two
## players the opponent is not a choice at all.)


const COLORS := [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B,
	Mtg.ManaColor.R, Mtg.ManaColor.G]


func build() -> CardData:
	return CardData.new("Jihad", "{W}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.sacrifices_when(_colour_is_gone) \
		.static_ability(StaticAbility.new(
			_apply,
			"White creatures get +2/+1 as long as the chosen player controls a "
			+ "nontoken permanent of the chosen color.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _choose,
			"As Jihad enters, choose a color and an opponent.",
			_is_self)) \
		.oracle("As this enchantment enters, choose a color and an opponent.\nWhite "
			+ "creatures get +2/+1 as long as the chosen player controls a nontoken "
			+ "permanent of the chosen color.\nWhen the chosen player controls no "
			+ "nontoken permanents of the chosen color, sacrifice this enchantment.")


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _choose(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var victim := game.opponent_of(source.controller_id)
	source.memory["victim"] = victim
	var counts := [0, 0, 0, 0, 0]
	for inst in game.players[victim].battlefield:
		for i in COLORS.size():
			if (inst.cur_colors & COLORS[i]) != 0:
				counts[i] += 1
	var best := 0
	for i in COLORS.size():
		if counts[i] > counts[best]:
			best = i
	var pid := source.controller_id
	source.memory["color"] = game.agents[pid].choose_option(game, pid,
		["white", "blue", "black", "red", "green"],
		"Choose a colour for Jihad", best)
	game.recalculate()
	game.check_state_based_actions()


## "When the chosen player controls no nontoken permanents of the chosen
## color, sacrifice this enchantment." Before the choice is made (the ETB
## trigger has not resolved yet) there is nothing to be missing.
static func _colour_is_gone(game: MtgGame, source: CardInstance) -> bool:
	if not source.memory.has("victim"):
		return false
	return not _victim_has_colour(game, source)


static func _victim_has_colour(game: MtgGame, source: CardInstance) -> bool:
	var victim: int = int(source.memory["victim"])
	var color: int = COLORS[int(source.memory["color"])]
	for inst in game.players[victim].battlefield:
		if not inst.is_token and (inst.cur_colors & color) != 0:
			return true
	return false


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if not source.memory.has("victim"):
		return
	if not _victim_has_colour(game, source):
		return
	for inst in game.all_battlefield():
		if inst.is_creature() and (inst.cur_colors & Mtg.ManaColor.W) != 0:
			inst.cur_power += 2
			inst.cur_toughness += 1
