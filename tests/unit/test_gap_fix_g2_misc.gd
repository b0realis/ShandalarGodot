extends GameTest
## THE SMALLER LAYER ITEMS (gap review 2026-11-10, R2).
##
## - r2-6: the 1997 rule "a tapped artifact's continuous effects cease —
##   artifact creatures excepted" is judged again after layer 4, so an
##   artifact a STATIC animated (Animate Artifact) is excepted too.
## - r2-7: a text change (Sleight of Mind) rewrites the protection the
##   permanent's TEXT prints, never one another effect granted (CR 612.3).
## - r2-8: the off-battlefield pass of the characteristic definitions (CR
##   604.3) walks only the cards that carry one, not every library card.


func _enchant(pid: int, card_name: String, host: CardInstance) -> CardInstance:
	var aura := _make_instance(pid, card_name)
	g._put_on_battlefield(aura, pid, host)
	return aura


# ============== r2-6: the 1997 tapped-artifact rule after layer 4 ==============

func test_a_tapped_meekstone_animate_artifact_made_a_creature_keeps_locking() -> void:
	g.rules.tapped_artifacts_stop = true
	var stone := put_battlefield(0, "Meekstone")
	_enchant(0, "Animate Artifact", stone)
	var wurm := put_battlefield(1, "Craw Wurm")
	g.recalculate()
	assert_true(stone.is_creature(), "Animate Artifact made it an artifact creature")
	assert_true(wurm.cur_skips_untap, "untapped: Meekstone locks the 6/4")
	stone.tapped = true
	g.recalculate()
	assert_true(stone.is_creature())
	assert_false(stone.cur_statics_suspended, "an artifact creature: excepted")
	assert_true(wurm.cur_skips_untap,
		"manual p.124: artifact CREATURES are excepted - a tapped animated Meekstone still locks")


func test_a_tapped_meekstone_alone_still_stops() -> void:
	g.rules.tapped_artifacts_stop = true
	var stone := put_battlefield(0, "Meekstone")
	var wurm := put_battlefield(1, "Craw Wurm")
	stone.tapped = true
	g.recalculate()
	assert_true(stone.cur_statics_suspended, "the control: a tapped noncreature artifact ceases")
	assert_false(wurm.cur_skips_untap)


func test_the_modern_rules_never_suspend() -> void:
	var stone := put_battlefield(0, "Meekstone")
	var wurm := put_battlefield(1, "Craw Wurm")
	stone.tapped = true
	g.recalculate()
	assert_false(stone.cur_statics_suspended)
	assert_true(wurm.cur_skips_untap)


# ============== r2-7: a text change and a granted protection ==============

func test_sleight_of_mind_does_not_rewrite_a_granted_protection() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	g.grant_protection_permanently(bears, Mtg.ManaColor.R)   # Rainbow Knights-style grant
	assert_eq(bears.cur_protection, Mtg.ManaColor.R)
	g.change_text(bears, "color_word", Mtg.ManaColor.R, Mtg.ManaColor.G)
	assert_eq(bears.cur_protection, Mtg.ManaColor.R,
		"CR 612.3: a text change does not modify an ability granted by another effect")
	assert_eq(bears.text_protection(), 0, "the Bears' text names no color")


func test_sleight_of_mind_rewrites_the_printed_word_beside_a_grant() -> void:
	var knight := put_battlefield(0, "Black Knight")   # protection from white
	g.grant_protection_permanently(knight, Mtg.ManaColor.R)
	g.change_text(knight, "color_word", Mtg.ManaColor.W, Mtg.ManaColor.G)
	assert_eq(knight.cur_protection, Mtg.ManaColor.G | Mtg.ManaColor.R,
		"the printed white becomes green; the granted red stays")
	assert_eq(knight.text_protection(), Mtg.ManaColor.G)


func test_a_word_the_grant_shares_with_the_text_is_rewritten_in_the_text_only() -> void:
	var knight := put_battlefield(0, "Black Knight")
	g.grant_protection_permanently(knight, Mtg.ManaColor.W)   # white twice
	g.change_text(knight, "color_word", Mtg.ManaColor.W, Mtg.ManaColor.U)
	assert_eq(knight.cur_protection, Mtg.ManaColor.W | Mtg.ManaColor.U,
		"the text's white is blue now; the granted white is not text")


func test_two_text_changes_chain_on_the_printed_word() -> void:
	var knight := put_battlefield(0, "Black Knight")
	g.change_text(knight, "color_word", Mtg.ManaColor.W, Mtg.ManaColor.G)
	g.change_text(knight, "color_word", Mtg.ManaColor.G, Mtg.ManaColor.R)
	assert_eq(knight.cur_protection, Mtg.ManaColor.R)


# ============== r2-8: the off-battlefield definitions ==============

static func _hand_count(game: MtgGame, card: CardInstance) -> void:
	var n: int = game.players[card.owner_id].hand.size()
	card.cur_power = n
	card.cur_toughness = n


static func _counter() -> CardData:
	var c := CardData.new("Test Counter", "{1}{G}", Mtg.CardType.CREATURE).pt(0, 0)
	c.characteristic_definition = _hand_count
	return c


func test_the_definition_pass_walks_only_the_cards_that_carry_one() -> void:
	var held := give_synthetic(0, _counter())
	give_hand(0, "Grizzly Bears")
	g.recalculate()
	assert_eq(held.cur_power, 2, "the definition works in the hand (CR 604.3)")
	assert_eq(g.continuous.definition_holders(g), [held.id],
		"of the %d cards in the game only the one with a definition is walked" % g._instances.size())


func test_a_card_made_later_joins_the_walk() -> void:
	give_hand(0, "Grizzly Bears")
	g.recalculate()
	assert_eq(g.continuous.definition_holders(g), [])
	var later := give_synthetic(1, _counter())
	g.recalculate()
	assert_eq(later.cur_power, 1)
	assert_eq(g.continuous.definition_holders(g), [later.id])


func test_a_card_that_left_the_game_drops_out_of_the_walk() -> void:
	var held := give_synthetic(0, _counter())
	g.recalculate()
	g.players[0].hand.erase(held)
	g._instances.erase(held.id)
	g.recalculate()
	assert_eq(g.continuous.definition_holders(g), [])
