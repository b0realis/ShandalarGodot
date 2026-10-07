extends GameTest
## Campaign fix-engine w7-5 — THE ANNOUNCEMENT BRACKET.
##
## A seat that has ANNOUNCED a spell or an ability (CR 601.2a) and then
## activates mana abilities to pay for it (601.2g) receives no priority
## until the object is on the stack, so what those mana abilities trigger —
## City of Brass's "becomes tapped", Manabarbs, Kudzu, Psychic Venom — waits
## and goes on the stack ABOVE the object (CR 603.3). The duel screen and
## the network referee announce first and pay second, and the engine did not
## know it: the City's trigger went on the stack at once and the creature
## the seat was paying for was refused ("main phase with an empty stack").
##
## [method MtgGame.begin_announcement] opens the bracket as the seat starts
## paying for its announcement; the cast or activation closes it (the
## waiting triggers go on above the object), [method
## MtgGame.end_announcement] closes it for an abandoned one, and passing
## priority closes it too. Without a bracket a mana ability's trigger goes
## on the stack at once, as CR 117.3c says it must.


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


func test_without_an_announcement_the_citys_trigger_goes_on_at_once() -> void:
	# The control: floating mana with City of Brass outside any
	# announcement puts its trigger on the stack (CR 117.3c, 603.3), and a
	# creature cannot be cast over it.
	var city := put_battlefield(0, "City of Brass")
	var bears := give_hand(0, "Grizzly Bears")
	put_battlefield(0, "Forest")
	assert_ok(g.tap_for_mana(0, city, 4))
	assert_eq(g.stack.size(), 1, "the City's trigger is on the stack")
	assert_refused(g.cast_spell(0, bears, []), "empty stack")


func test_paying_an_announced_creature_with_city_of_brass_casts_it() -> void:
	var city := put_battlefield(0, "City of Brass")
	var forest := put_battlefield(0, "Forest")
	var bears := give_hand(0, "Grizzly Bears")
	assert_ok(g.begin_announcement(0))
	assert_true(g.announcement_open(0))
	assert_ok(g.tap_for_mana(0, city, 4))
	assert_ok(g.tap_for_mana(0, forest))
	assert_true(g.stack.is_empty(), "the City's trigger waits while the cast is being paid for")
	assert_ok(g.cast_spell(0, bears, []))
	assert_false(g.announcement_open(0), "the cast closed the bracket")
	assert_eq(g.stack.size(), 2)
	assert_eq(g.stack[0].card, bears, "the Bears at the bottom")
	assert_eq(g.stack[1].card, city, "the City's trigger above them (CR 603.3)")
	assert_eq(g.priority_player, 0, "the caster keeps priority (CR 117.3c)")
	resolve_stack()
	assert_eq(g.players[0].life, 19, "the City dealt its 1")
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)


func test_manabarbs_waits_for_the_announced_spell_too() -> void:
	put_battlefield(1, "Manabarbs")
	var a := put_battlefield(0, "Forest")
	var b := put_battlefield(0, "Forest")
	var bears := give_hand(0, "Grizzly Bears")
	assert_ok(g.begin_announcement(0))
	assert_ok(g.tap_for_mana(0, a))
	assert_ok(g.tap_for_mana(0, b))
	assert_true(g.stack.is_empty())
	assert_ok(g.cast_spell(0, bears, []))
	assert_eq(g.stack.size(), 3, "two barbs above the Bears")
	assert_eq(g.stack[0].card, bears)
	resolve_stack()
	assert_eq(g.players[0].life, 18)


func test_an_announced_ability_gets_the_trigger_above_it() -> void:
	var city := put_battlefield(0, "City of Brass")
	var rod := put_battlefield(0, "Rod of Ruin")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	assert_ok(g.begin_announcement(0))
	for land in g.players[0].battlefield.duplicate():
		if land.is_land():
			assert_ok(g.tap_for_mana(0, land, 3) if land == city \
				else g.tap_for_mana(0, land))
	assert_true(g.stack.is_empty())
	assert_ok(g.activate_ability(0, rod, 0, [TargetRef.player(1)]))
	assert_eq(g.stack.size(), 2)
	assert_eq(g.stack[0].card, rod, "the Rod's ability at the bottom")
	assert_eq(g.stack[1].card, city, "the City's trigger above it")


func test_an_abandoned_announcement_puts_the_trigger_on_the_stack() -> void:
	var city := put_battlefield(0, "City of Brass")
	assert_ok(g.begin_announcement(0))
	assert_ok(g.tap_for_mana(0, city, 4))
	assert_true(g.stack.is_empty())
	g.end_announcement(0)
	assert_false(g.announcement_open(0))
	assert_eq(g.stack.size(), 1, "the trigger goes on now")
	assert_eq(g.priority_player, 0, "and the seat keeps priority (CR 117.3c)")
	assert_eq(g.players[0].mana_pool.total(), 1, "the mana it made stays in the pool")


func test_passing_priority_closes_the_bracket_first() -> void:
	var city := put_battlefield(0, "City of Brass")
	assert_ok(g.begin_announcement(0))
	assert_ok(g.tap_for_mana(0, city, 4))
	assert_ok(g.pass_priority(0))
	assert_false(g.announcement_open(0))
	assert_eq(g.stack.size(), 1, "the trigger is on the stack, not lost")
	assert_eq(g.priority_player, 1, "the opponent gets to respond to it")
	assert_ok(g.pass_priority(1))
	assert_eq(g.players[0].life, 19, "both passed in succession: it resolved")


func test_only_the_priority_holder_announces() -> void:
	assert_refused(g.begin_announcement(1), "priority")
	assert_false(g.announcement_open(1))
	assert_ok(g.begin_announcement(0))
	assert_ok(g.begin_announcement(0))   # idempotent for the same seat
	g.end_announcement(0)
	g.end_announcement(0)                # and closing twice is harmless
	assert_false(g.announcement_open(0))


func test_the_journal_puts_an_opened_bracket_back() -> void:
	var city := put_battlefield(0, "City of Brass")
	var mark := g.make_mark()
	assert_ok(g.begin_announcement(0))
	assert_ok(g.tap_for_mana(0, city, 4))
	g.unmake_to(mark)
	g.end_search()
	assert_false(g.announcement_open(0), "the bracket is put back")
	assert_false(city.tapped)
	assert_true(g.stack.is_empty())
	# And the duel goes on normally: a fresh tap triggers at once.
	assert_ok(g.tap_for_mana(0, city, 4))
	assert_eq(g.stack.size(), 1)


## The network referee's flow (prepare → autopay → submit, w7-5's probe),
## with the bracket opened where the referee's autopay is to open it
## (SgDuelActions.autopay — a call-site change for its owner): the City's
## trigger waits and the submitted creature is cast.
func test_the_referees_prepare_autopay_submit_casts_with_the_bracket() -> void:
	put_battlefield(0, "City of Brass")
	put_battlefield(0, "City of Brass")
	var bears := give_hand(0, "Grizzly Bears")
	var referee := SgPracticeMatch.new(42)
	referee.game = g
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	referee.view(0)
	var handle: String = referee._handle(0, bears)
	assert_eq(referee.act(0, {"op": "prepare", "card": handle, "kind": "spell", "index": 0, "x": 0, "mode": 0}), "")
	assert_ok(g.begin_announcement(0))   # what autopay is to do first
	assert_eq(referee.act(0, {"op": "autopay", "excluded": [], "count": 1}), "")
	assert_true(g.stack.is_empty(), "the Cities' triggers wait")
	assert_eq(referee.act(0, {"op": "submit", "targets": []}), "", "the paid creature is cast")
	assert_eq(bears.zone, Mtg.Zone.STACK)
	assert_eq(g.stack[0].card, bears, "the Bears at the bottom, the triggers above")
	assert_eq(g.stack.size(), 3)
