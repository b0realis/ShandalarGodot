extends GameTest
## THE CHOICE CARDS, CAST BY THEIR ROLES (Pack 8, 2026-10-03; card batch
## B1's `ai_role` tags; [member AiProfile.forecasts_tactics]).
##
## Their resolution choices are the cards' own public hints; what the AI
## decides is WHETHER to cast them (mirage_tactics.gd `role_choice`):
## Doomsday never (a combo piece with no combo to finish), Natural Balance
## when it gains us more lands than them, Tariff when their payment is out
## of reach of their open mana, Illicit Auction only at a creature our
## bidding limit wins. And a seat's flash GRANT (Winding Canyons) is this
## turn's: a creature it covers does not wait for their turn.

const M := preload("res://engine/ai/mirage_tactics.gd")


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-8", true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func _ai() -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func test_doomsday_is_never_cast() -> void:
	var ai := _ai()
	for _i in 3: put_battlefield(0, "Swamp")
	var doomsday := give_hand(0, "Doomsday")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(doomsday.zone, Mtg.Zone.HAND)


func test_natural_balance_when_it_ramps_us_and_cuts_them() -> void:
	var ai := _ai()
	for _i in 4: put_battlefield(0, "Forest")   # {2}{G}{G}; one basic to fetch
	for _i in 7: put_battlefield(1, "Plains")   # two to lose
	var balance := give_hand(0, "Natural Balance")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Natural Balance")
	assert_eq(balance.zone, Mtg.Zone.STACK)


func test_natural_balance_waits_when_it_cuts_us() -> void:
	var ai := _ai()
	for _i in 7: put_battlefield(0, "Forest")
	for _i in 3: put_battlefield(1, "Plains")
	var balance := give_hand(0, "Natural Balance")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(balance.zone, Mtg.Zone.HAND)


func test_illicit_auction_only_when_our_bid_wins() -> void:
	var ai := _ai()
	for _i in 5: put_battlefield(0, "Mountain")
	var auction := give_hand(0, "Illicit Auction")
	var wurm := put_battlefield(1, "Craw Wurm")
	g.players[1].life = 8   # their limit is 2: we outbid at 3
	var choice: Variant = M.role_choice(g, ai, auction)
	assert_false(choice.is_empty())
	assert_eq(choice["targets"][0].instance_id, wurm.id)
	g.players[0].life = 8   # now ours is 2 as well: no auction
	choice = M.role_choice(g, ai, auction)
	assert_true(choice.is_empty())


func test_a_seat_flash_grant_does_not_make_a_creature_wait() -> void:
	var ai := _ai()
	var bears := give_hand(0, "Grizzly Bears")
	g.grant_flash(0, func(_g: MtgGame, i: CardInstance) -> bool: return i.is_creature(), "test")
	advance_to_step(Mtg.Step.MAIN1)
	assert_false(M.flash_creature_waits(g, ai, bears), "the grant ends this turn")
	var cheetah := give_hand(0, "King Cheetah")
	bears.zone = Mtg.Zone.GRAVEYARD   # out of the hand: nothing else wants the mana
	g.players[0].hand.erase(bears)
	put_battlefield(1, "Llanowar Elves")   # an attacker the Cheetah ambushes
	assert_true(M.flash_creature_waits(g, ai, cheetah), "printed flash waits")
