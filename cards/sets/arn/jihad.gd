extends CardScript
## Jihad — {W}{W}{W} — Enchantment — (arn, rare)
## Oracle: As this enchantment enters, choose a color and an opponent.
##         White creatures get +2/+1 as long as the chosen player controls
##         a nontoken permanent of the chosen color.
##         When the chosen player controls no nontoken permanents of the
##         chosen color, sacrifice this enchantment.
##
## Implementation: a CR 614.1c REPLACEMENT (CardData.as_it_enters)
## remembering the opponent and the colour in the enchantment's card-local
## memory (in a duel the opponent picks itself; the colour is the one they
## hold MOST of, which is the choice a player would make), plus a static
## anthem gated on that colour still being on their board, and a
## CardData.sacrifices_when clause (checked as a state-based action,
## exactly like Sea Serpent's "when you control no Islands") that buries
## Jihad the moment that colour is gone.
##
## "As Jihad enters, choose a colour and an opponent" — the colour is the
## CASTER's, asked through their DecisionAgent as the enchantment enters,
## with the colour the chosen opponent holds most of as the hint. (With two
## players the opponent is not a choice at all.)
##
## IT USED TO BE AN ARRIVAL TRIGGER (fixed 2026-09-09, alongside Lich and
## the three "choose an opponent" artifacts). A trigger is a stack object,
## so between Jihad arriving and the choice resolving both players held
## priority over a board WITHOUT the anthem — and the anthem is a toughness
## bonus. Reproduced: a Samite Healer under a Jihad that has not chosen yet
## is a 1/1, and a Prodigal Sorcerer's ping in that window kills it; with
## the anthem up, as the rules have it, the Healer is a 3/2 and takes the
## point. The `memory.has("victim")` guards below are still right — an
## arrival the engine refused, or a Jihad put onto the battlefield by a
## path that never ran this hook, has nothing to read — but they are no
## longer the only thing standing between the window and the board.


const COLORS := [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B,
	Mtg.ManaColor.R, Mtg.ManaColor.G]


func build() -> CardData:
	return CardData.new("Jihad", "{W}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.as_it_enters(_choose) \
		.sacrifices_when(_colour_is_gone) \
		.static_ability(StaticAbility.new(
			_apply,
			"White creatures get +2/+1 as long as the chosen player controls a "
			+ "nontoken permanent of the chosen color.")) \
		.oracle("As this enchantment enters, choose a color and an opponent.\nWhite "
			+ "creatures get +2/+1 as long as the chosen player controls a nontoken "
			+ "permanent of the chosen color.\nWhen the chosen player controls no "
			+ "nontoken permanents of the chosen color, sacrifice this enchantment.")


## THE CHOICE (CR 614.1c), made as the enchantment arrives, so the anthem
## is on the board at the first instant anybody could act against it.
## MtgGame._put_on_battlefield recalculates straight afterwards, and the
## state-based check that can bury a Jihad with nothing to hate rides the
## caller's own pass — sacrificing a permanent from inside its own arrival
## is not this hook's business.
static func _choose(game: MtgGame, source: CardInstance, controller: int) -> void:
	var victim := game.opponent_of(controller)
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
	source.memory["color"] = game.agents[controller].choose_option(
		game, controller, ["white", "blue", "black", "red", "green"],
		"Choose a colour for Jihad", best)


## "When the chosen player controls no nontoken permanents of the chosen
## color, sacrifice this enchantment." A Jihad that never made the choice
## (an arrival the hook above never ran) has nothing to be missing.
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
