extends GameTest
## FINAL FORTUNE IN THEIR TURN (bug hunt 2026-10-21, ai).
##
## "Take an extra turn after this one. At the beginning of that turn's end
## step, you lose the game." The pilot casts it when one more turn's
## unblockable damage is lethal (`extra_turn_then_lose`,
## [method PortalTactics.spell_choice]) — and as an instant it was offered
## at every priority outside our main phase too ([method
## PortalTactics.special_spell] from the response arm). Cast in THEIR turn
## the extra turn is taken where our own next turn was coming anyway: no
## attack gained, their main phases still ahead of it for a blocker or a
## Fog, and the loss at its end. With a lethal Grizzly Bears against 2
## life, the Wizard cast it in their upkeep.
##
## It waits for our own turn now; there the extra turn is a second attack
## (the control).

const PT := preload("res://engine/ai/portal_tactics.gd")


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-8", true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


## Advance into the OPPONENT's turn and hand seat 0 priority in [param step].
func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


## Our Grizzly Bears, two Mountains and Final Fortune; they are at 2 life
## with nothing to block.
func _board() -> Array:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	for n in 2: put_battlefield(0, "Mountain")
	put_battlefield(0, "Grizzly Bears")
	var ff := give_hand(0, "Final Fortune")
	g.players[1].life = 2
	return [ai, ff]


func test_not_in_their_upkeep() -> void:
	var board := _board()
	_their_turn_at(Mtg.Step.UPKEEP)
	(board[0] as AiPlayer).act(g)
	assert_eq((board[1] as CardInstance).zone, Mtg.Zone.HAND, "held: our own turn is next anyway")
	assert_eq(PT.spell_choice(g, board[0], board[1]), {}, "no value in their turn")


func test_not_at_their_end_step() -> void:
	var board := _board()
	_their_turn_at(Mtg.Step.END)
	(board[0] as AiPlayer).act(g)
	assert_eq((board[1] as CardInstance).zone, Mtg.Zone.HAND)


## THE CONTROL: in our own turn the extra turn is a second attack.
func test_in_our_own_turn_the_extra_turn_wins() -> void:
	var board := _board()
	advance_to_step(Mtg.Step.MAIN1)
	var choice: Variant = PT.spell_choice(g, board[0], board[1])
	assert_true(choice is Dictionary and not (choice as Dictionary).is_empty())
	if choice is Dictionary and not (choice as Dictionary).is_empty():
		assert_gte(float(choice["value"]), AiPlayer.LETHAL_WORTH * 0.5)
