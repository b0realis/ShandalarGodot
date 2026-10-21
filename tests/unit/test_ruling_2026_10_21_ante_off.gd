extends GameTest
## THE OWNER'S RULING OF 2026-10-21 ON ANTE OFF, verbatim: *"fix ante off
## (only back side of mtg cards shown instead of ante, no ante used!)"*.
##
## WAS: a duel not played for ante ([member MtgGame.ante_enabled] false —
## only [method MtgGame.stake_ante] sets it) still let the nine ante cards
## put cards into the ante: Contract from Below was a {B} "discard your
## hand, draw seven" that staked a card nobody had agreed to play for,
## Demonic Attorney and Rebirth did the same to both players, Jeweled Bird
## anted itself, and Amulet of Quoz flipped a coin for the GAME.
##
## NOW: each of the nine prints "Remove this card from your deck before
## playing if you're not playing for ante." and, with ante off, does
## NOTHING — its spell is refused, its abilities are refused, one reason
## for every asker ([method MtgGame.not_for_ante_refusal]): the cast
## ([method MtgGame.cast_spell], [method MtgGame.cast_timing_refusal],
## [method MtgGame.cast_refusal]) and the activation
## ([method MtgGame.activate_ability], [method MtgGame.ability_timing_refusal],
## [method MtgGame.activation_refusal]) — so the duel screen, SGManalink and
## the AI hear the same. Behind that, [method MtgGame.ante_top_of_library]
## and [method MtgGame.move_to_ante] move nothing without ante, so nothing
## can reach the ante (the opening window keeps showing card backs). A duel
## played for ante is unchanged.

const ANTE_SPELLS := ["Contract from Below", "Darkpact", "Demonic Attorney",
	"Rebirth", "Jeweled Bird", "Bronze Tablet", "Tempest Efreet",
	"Timmerian Fiends", "Amulet of Quoz"]
## The five that are permanents with an activated ability.
const ANTE_PERMANENTS := ["Jeweled Bird", "Bronze Tablet", "Tempest Efreet",
	"Timmerian Fiends", "Amulet of Quoz"]
const REASON := "Ante must be on for"


## Says yes to every "may" (Rebirth's ante, Fiends' and Amulet's ransom).
class Yes extends DecisionAgent:
	func answer_yes_no(_g: MtgGame, _p: int, _prompt: String, _hint: bool) -> bool:
		return true


func before_each() -> void:
	CardPacks.set_enabled(IceAgePack.ID, true)    # Amulet of Quoz
	CardPacks.set_enabled("pack-4", true)         # Timmerian Fiends
	CardRegistry.ensure_loaded()
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled(IceAgePack.ID, false)
	CardPacks.set_enabled("pack-4", false)


func _all_mana(pid := 0) -> void:
	for color in [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B,
			Mtg.ManaColor.R, Mtg.ManaColor.G, Mtg.ManaColor.C]:
		add_mana(pid, color, 10)


func _upkeep() -> void:
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.UPKEEP)


# ----------------------------------------------------------- the pieces --

func test_the_nine_ante_cards_are_known_by_their_first_line() -> void:
	for card_name in ANTE_SPELLS:
		var data := CardRegistry.get_card(card_name)
		assert_not_null(data, card_name)
		if data != null:
			assert_true(MtgGame.is_ante_card(data), card_name)
	for card_name in ["Lightning Bolt", "Grizzly Bears", "Fireball", "Wheel of Fortune"]:
		assert_false(MtgGame.is_ante_card(CardRegistry.get_card(card_name)), card_name)


func test_a_bare_duel_is_not_played_for_ante() -> void:
	assert_false(g.ante_enabled, "nothing staked: not for ante")
	assert_eq(DuelConfig.new().ante, 0, "a bare DuelConfig plays for no ante")


# ------------------------------------------------- ante OFF: the refusals --

func test_every_ante_spell_is_refused_with_ante_off() -> void:
	for card_name in ANTE_SPELLS:
		var card := give_hand(0, card_name)
		_all_mana()
		var pool := g.players[0].mana_pool.total()
		var expected := "Ante must be on for %s: this duel is not played for ante" % card_name
		assert_eq(g.cast_timing_refusal(0, card), expected, card_name + " (timing)")
		assert_eq(g.cast_refusal(0, card, []), expected, card_name + " (plan)")
		assert_eq(g.cast_spell(0, card, []), expected, card_name + " (cast)")
		assert_eq(card.zone, Mtg.Zone.HAND, card_name + " stays in hand")
		assert_eq(g.players[0].mana_pool.total(), pool, card_name + ": no mana spent")
		assert_true(g.stack.is_empty(), card_name + ": nothing on the stack")
	assert_eq(g.all_ante().size(), 0, "nothing ever reached the ante")


func test_every_ante_ability_is_refused_with_ante_off() -> void:
	var hostage := put_battlefield(1, "Sol Ring")
	for card_name in ANTE_PERMANENTS:
		var perm := put_battlefield(0, card_name)
		perm.tapped = false
		if card_name == "Amulet of Quoz":
			_upkeep()
		_all_mana()
		var ability: ActivatedAbility = perm.cur_activated_abilities[0]
		var expected := "Ante must be on for %s: this duel is not played for ante" % card_name
		assert_eq(g.ability_timing_refusal(0, perm, ability), expected, card_name + " (timing)")
		assert_eq(g.activation_refusal(0, perm, 0), expected, card_name + " (activation cue)")
		var target: Array = []
		if card_name in ["Bronze Tablet", "Timmerian Fiends"]:
			target = [TargetRef.card(hostage)]
		elif card_name in ["Tempest Efreet", "Amulet of Quoz"]:
			target = [TargetRef.player(1)]
		assert_eq(g.activate_ability(0, perm, 0, target), expected, card_name + " (activate)")
		assert_eq(perm.zone, Mtg.Zone.BATTLEFIELD, card_name + " was not sacrificed")
		assert_false(perm.tapped, card_name + " was not tapped")
		assert_true(g.stack.is_empty(), card_name + ": nothing on the stack")
		g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.MAIN1)
	assert_eq(hostage.owner_id, 1, "no ransom was ever offered")
	assert_eq(g.all_ante().size(), 0, "nothing ever reached the ante")
	assert_false(g.game_over, "Amulet of Quoz flipped no coin for the game")


func test_a_copy_of_an_ante_card_does_nothing_either() -> void:
	# Read off the Oracle text, so a creature that copies Tempest Efreet
	# carries its first line with it.
	var efreet := put_battlefield(0, "Tempest Efreet")
	var copy := put_battlefield(0, "Grizzly Bears")
	copy.data = efreet.data
	assert_eq(g.not_for_ante_refusal(copy),
		"Ante must be on for Tempest Efreet: this duel is not played for ante")


func test_nothing_else_is_refused() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_eq(g.not_for_ante_refusal(bolt), "")
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))


# ------------------------------------------------ ante OFF: the backstops --

func test_nothing_can_be_anted_off_the_library_with_ante_off() -> void:
	var top: CardInstance = g.players[0].library.back()
	var size := g.players[0].library.size()
	assert_null(g.ante_top_of_library(0), "no ante: nothing goes")
	assert_eq(g.players[0].library.size(), size)
	assert_eq(top.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.all_ante().size(), 0)


func test_nothing_can_be_moved_to_the_ante_with_ante_off() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var card := give_hand(0, "Hill Giant")
	assert_false(g.move_to_ante(bear))
	assert_false(g.move_to_ante(card))
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(card.zone, Mtg.Zone.HAND)
	assert_eq(g.all_ante().size(), 0)


func test_jeweled_bird_does_nothing_if_it_could_not_be_anted() -> void:
	# The effect itself, past the refusal (the backstop's "if you do"):
	# no ante, so no dump and no draw.
	var bird := put_battlefield(0, "Jeweled Bird")
	var hand := g.players[0].hand.size()
	var effect: EffectBase = bird.data.activated_abilities[0].effects[0]
	effect.resolve(g, bird, 0, null, 0)
	assert_eq(bird.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].hand.size(), hand, "no card drawn")


func test_rebirth_sets_no_life_if_nothing_could_be_anted() -> void:
	var rebirth := give_hand(0, "Rebirth")
	g.set_agent(0, Yes.new())
	g.set_agent(1, Yes.new())
	g.adjust_life(0, -15)
	var effect: EffectBase = rebirth.data.spell_effects[0]
	effect.resolve(g, rebirth, 0, null, 0)
	assert_eq(g.players[0].life, 5, "'if a player does' — nobody could")
	assert_eq(g.all_ante().size(), 0)


# -------------------------------------------------- Test hands and the AI --

func test_a_test_hands_duel_is_never_for_ante_and_its_ante_cards_do_nothing() -> void:
	var config := DuelConfig.new()
	config.ante = 1
	var position := DuelPosition.new()
	position.add(0, DuelPosition.TABLE, "Jeweled Bird")
	position.add(0, DuelPosition.HAND, "Contract from Below")
	position.add(0, DuelPosition.TABLE, "Swamp")
	var test_config := config.for_test(position, 7)
	assert_eq(test_config.ante, 0, "a test is never for ante")
	var deck: Array = []
	for i in 30:
		deck.append("Swamp")
	var game := MtgGame.new()
	game.setup(deck, deck, "P0", "P1", 20, 20, 7)
	assert_eq(game.begin_from_position(test_config.position), "")
	assert_false(game.ante_enabled)
	var bird: CardInstance = game.players[0].battlefield[0]
	var contract: CardInstance = game.players[0].hand[0]
	assert_eq(bird.data.card_name, "Jeweled Bird")
	assert_refused(game.activate_ability(0, bird, 0, []), REASON)
	assert_refused(game.cast_timing_refusal(0, contract), REASON)
	assert_eq(game.all_ante().size(), 0, "the position put nothing in the ante")


func test_the_ai_never_casts_an_ante_card_with_ante_off() -> void:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	var contract := give_hand(0, "Contract from Below")
	put_battlefield(0, "Swamp")
	var bird := put_battlefield(0, "Jeweled Bird")
	for _i in 6:
		if g.priority_player != 0 or g.game_over:
			break
		ai.act(g)
		resolve_stack()
	assert_eq(contract.zone, Mtg.Zone.HAND, "Contract from Below was not cast")
	assert_false(bird.tapped, "Jeweled Bird was not activated")
	assert_eq(g.all_ante().size(), 0)


func test_the_ai_casts_contract_from_below_when_playing_for_ante() -> void:
	# The control: the same seat, the same hand, the duel played for ante.
	g.ante_enabled = true
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	var contract := give_hand(0, "Contract from Below")
	put_battlefield(0, "Swamp")
	assert_eq(g.cast_timing_refusal(0, contract), "")
	for _i in 6:
		if g.priority_player != 0 or g.game_over or contract.zone != Mtg.Zone.HAND:
			break
		ai.act(g)
		resolve_stack()
	assert_ne(contract.zone, Mtg.Zone.HAND, "with ante on the AI may cast it")


# ------------------------------------------- ante ON: nothing changed --

func test_stake_ante_turns_the_ante_cards_on() -> void:
	var contract := give_hand(0, "Contract from Below")
	assert_refused(g.cast_timing_refusal(0, contract), REASON)
	g.stake_ante(0)
	g.stake_ante(1)
	assert_true(g.ante_enabled)
	assert_eq(g.cast_timing_refusal(0, contract), "")


func test_contract_from_below_still_works_played_for_ante() -> void:
	g.ante_enabled = true
	give_hand(0, "Grizzly Bears")
	var contract := give_hand(0, "Contract from Below")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, contract, []))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 7)
	assert_eq(g.players[0].ante.size(), 1)


func test_demonic_attorney_still_works_played_for_ante() -> void:
	g.ante_enabled = true
	var attorney := give_hand(0, "Demonic Attorney")
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, attorney, []))
	resolve_stack()
	assert_eq([g.players[0].ante.size(), g.players[1].ante.size()], [1, 1])


func test_darkpact_still_works_played_for_ante() -> void:
	var theirs := g.stake_ante(1)[0]
	var darkpact := give_hand(0, "Darkpact")
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_ok(g.cast_spell(0, darkpact, [TargetRef.card(theirs)]))
	resolve_stack()
	assert_eq(theirs.owner_id, 0)
	assert_eq(theirs.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[0].ante.size(), 1, "our top card took its place")


func test_rebirth_still_works_played_for_ante() -> void:
	g.ante_enabled = true
	g.set_agent(0, Yes.new())
	g.set_agent(1, Yes.new())
	g.adjust_life(0, -15)
	var rebirth := give_hand(0, "Rebirth")
	add_mana(0, Mtg.ManaColor.G, 3)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, rebirth, []))
	resolve_stack()
	assert_eq(g.players[0].life, 20)
	assert_eq(g.all_ante().size(), 2)


func test_jeweled_bird_still_works_played_for_ante() -> void:
	var mine := g.stake_ante(0)[0]
	var bird := put_battlefield(0, "Jeweled Bird")
	var hand := g.players[0].hand.size()
	assert_ok(g.activate_ability(0, bird, 0, []))
	resolve_stack()
	assert_eq(bird.zone, Mtg.Zone.ANTE)
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].hand.size(), hand + 1)


func test_bronze_tablet_and_tempest_efreet_still_work_played_for_ante() -> void:
	g.ante_enabled = true
	var tablet := put_battlefield(0, "Bronze Tablet")
	tablet.tapped = false
	var hostage := put_battlefield(1, "Grizzly Bears")
	g.adjust_life(1, -12)   # 8 life: the ransom can't be paid
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, tablet, 0, [TargetRef.card(hostage)]))
	resolve_stack()
	assert_eq(hostage.owner_id, 0)
	var efreet := put_battlefield(0, "Tempest Efreet")
	give_hand(1, "Hill Giant")
	assert_ok(g.activate_ability(0, efreet, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(efreet.owner_id, 1, "the Efreet changed hands")


func test_timmerian_fiends_and_amulet_of_quoz_still_work_played_for_ante() -> void:
	g.ante_enabled = true
	g.set_agent(1, Yes.new())
	var fiends := put_battlefield(0, "Timmerian Fiends")
	var artifact := put_battlefield(1, "Sol Ring")
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_ok(g.activate_ability(0, fiends, 0, [TargetRef.card(artifact)]))
	resolve_stack()
	assert_eq(g.players[1].ante.size(), 1, "the owner anted to keep the Sol Ring")
	var amulet := put_battlefield(0, "Amulet of Quoz")
	_upkeep()
	assert_ok(g.activate_ability(0, amulet, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].ante.size(), 2, "and anted again to dodge the flip")
	assert_false(g.game_over)


func test_the_backstops_move_cards_when_played_for_ante() -> void:
	g.ante_enabled = true
	assert_not_null(g.ante_top_of_library(0))
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_true(g.move_to_ante(bear))
	assert_eq(bear.zone, Mtg.Zone.ANTE)
	assert_eq(g.players[0].ante.size(), 2)
