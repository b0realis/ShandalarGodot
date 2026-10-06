extends GameTest
## Pack 9 (the Tempest block), batch B2: the AI metadata the buyback cards
## declare reaches the fair AI. Every buyback spell carries its buyback ROW
## (CardData.with_buyback), which the casting AI reads through
## AiPlayer._paying_mode (gate AiProfile.forecasts_tactics): the row is
## paid when payable now, its mana starves nothing else castable, a land it
## eats keeps the land floor, the objects it eats are worth less than the
## card and a life payment leaves ten. Flowstone Flood's random discard is
## the one row the generic reading cannot price, so the card ships its own
## picker (CardData.with_ai_mode): the average card of the rest of its own
## hand against the Flood. Every effect is typed, a source shield, or
## role-tagged, so no buyback card reads as an unknown blob. The null arm
## (gate off) pays the printed row as before Pack 9, and no decision moves
## when the opponent's hand or either library changes (docs/fair-play.md).

const BUYBACK := ["Anoint", "Capsize", "Corpse Dance", "Disturbed Burial", "Elvish Fury",
	"Evincar's Justice", "Imps' Taunt", "Invulnerability", "Searing Touch", "Whim of Volrath",
	"Whispers of the Muse", "Worthy Cause",
	"Brush with Death", "Change of Heart", "Constant Mists", "Fanning the Flames", "Lab Rats",
	"Mind Games", "Mind Peel", "Seething Anger", "Verdant Touch",
	"Allay", "Flowstone Flood", "Forbid", "Pegasus Stampede", "Reaping the Rewards",
	"Shattering Pulse", "Slaughter"]
const BASICS := {Mtg.ManaColor.W: "Plains", Mtg.ManaColor.U: "Island", Mtg.ManaColor.B: "Swamp",
	Mtg.ManaColor.R: "Mountain", Mtg.ManaColor.G: "Forest"}


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(forecasts := true, seat := 0) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = forecasts
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai

func _lands(pid: int, land: String, n: int) -> void:
	for _i in n:
		put_battlefield(pid, land)

## Into the OPPONENT's turn, P0 holding priority in [param step].
func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


## A board on which [param card_name]'s buyback row is payable: eight
## basics of its colour, and whatever its non-mana buyback or additional
## cost eats (land cards in hand never compete for the mana).
func _payable_board(card_name: String) -> CardInstance:
	var data := CardRegistry.get_card(card_name)
	_lands(0, String(BASICS[data.color_mask()]), 8)
	match card_name:
		"Worthy Cause": put_battlefield(0, "Grizzly Bears")
		"Forbid":
			give_hand(0, "Forest")
			give_hand(0, "Forest")
		"Flowstone Flood": give_hand(0, "Forest")
	return give_hand(0, card_name)


# ----------------------------------------------------------- the metadata --

func test_every_buyback_card_offers_its_row_to_the_casting_ai() -> void:
	for card_name in BUYBACK:
		before_each()
		var ai := _ai()
		var spell := _payable_board(card_name)
		# Fanning the Flames: an X spell pays its printed row (E2; the X
		# sizing does not see the buyback yet — the AI stage's). Forbid: two
		# cards from the hand are priced at least the Forbid itself, so the
		# generic rule keeps them (AI.md §2: "only for a real threat").
		var expected := -1 if card_name in ["Fanning the Flames", "Forbid"] else 1
		assert_eq(ai._paying_mode(g, spell.data), expected, card_name)

func test_the_null_arm_pays_every_printed_row() -> void:
	for card_name in BUYBACK:
		before_each()
		var ai := _ai(false)
		var spell := _payable_board(card_name)
		assert_eq(ai._paying_mode(g, spell.data), -1, "%s: gate off, as before Pack 9" % card_name)

func test_every_buyback_effect_is_readable_by_the_ai() -> void:
	for card_name in BUYBACK:
		var data := CardRegistry.get_card(card_name)
		for e in data.spell_effects:
			var intent := EffectIntent.read([e], card_name)
			assert_true(not intent.unknown or e is SourceShieldEffect or e.ai_role != &"",
				"%s: typed, a source shield, or role-tagged" % card_name)
	assert_eq(EffectIntent.read(CardRegistry.get_card("Mind Peel").spell_effects).discards, 1)
	assert_true(EffectIntent.read(CardRegistry.get_card("Slaughter").spell_effects).removal_ignores_regeneration)
	assert_eq(EffectIntent.read(CardRegistry.get_card("Brush with Death").spell_effects).life_loss, 2)
	assert_true(EffectIntent.read(CardRegistry.get_card("Forbid").spell_effects).counters)
	assert_true(EffectIntent.read(CardRegistry.get_card("Constant Mists").spell_effects).fogs)


func test_every_cost_card_effect_is_readable_by_the_ai() -> void:
	for card_name in ["Abandon Hope", "Goblin Bombardment", "Harrow", "Pegasus Refuge",
			"Scorched Earth", "Spontaneous Combustion", "Tooth and Claw", "Fling", "Hidden Retreat",
			"Mask of the Mimic", "Scapegoat", "Aether Tide", "Culling the Weak", "Hatred",
			"Necrologia", "Penance", "Sonic Burst"]:
		var data := CardRegistry.get_card(card_name)
		var effects: Array = data.spell_effects.duplicate()
		for ability in data.activated_abilities:
			effects.append_array(ability.effects)
		assert_false(effects.is_empty(), card_name)
		for e in effects:
			var intent := EffectIntent.read([e], card_name)
			assert_true(not intent.unknown or e is SourceShieldEffect or e.ai_role != &"",
				"%s: typed, a source shield, or role-tagged" % card_name)
	assert_true(EffectIntent.read(CardRegistry.get_card("Harrow").spell_effects).searches)
	assert_true(EffectIntent.read(CardRegistry.get_card("Aether Tide").spell_effects).bounces)
	assert_true(EffectIntent.read(CardRegistry.get_card("Necrologia").spell_effects).draws_use_x)
	assert_true(EffectIntent.read(CardRegistry.get_card("Hatred").spell_effects).pump_uses_x)
	var claw := EffectIntent.read(CardRegistry.get_card("Tooth and Claw").activated_abilities[0].effects)
	assert_eq(int(claw.makes_token.get("power", 0)), 3, "the Carnivore's body is read")
	# The cost modifiers reach every planner through the engine's own price.
	put_battlefield(0, "Sphere of Resistance")
	assert_eq(g.spell_surcharge(0, CardRegistry.get_card("Lightning Bolt")), 1)


# ------------------------------------------------------------- the action --

func test_it_buys_back_whispers_of_the_muse_at_their_end_step() -> void:
	var ai := _ai()
	_lands(0, "Island", 6)
	var whispers := give_hand(0, "Whispers of the Muse")
	_their_turn_at(Mtg.Step.END)
	var hand := g.players[0].hand.size()
	assert_string_contains(ai.act(g), "Whispers of the Muse")
	assert_true(g.buyback_paid(whispers), "{U} plus {5}: six Islands")
	resolve_stack()
	assert_eq(whispers.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].hand.size(), hand + 1)

func test_short_of_the_buyback_it_pays_the_printed_row() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 4)
	var touch := give_hand(0, "Searing Touch")
	assert_eq(ai._paying_mode(g, touch.data), -1, "{R} plus {4} needs five")

func test_a_land_buyback_keeps_the_land_floor() -> void:
	var ai := _ai()
	_lands(0, "Forest", 3)
	var mists := give_hand(0, "Constant Mists")
	assert_eq(ai._paying_mode(g, mists.data), -1, "three lands: the floor")
	_lands(0, "Forest", 2)
	assert_eq(ai._paying_mode(g, mists.data), 1)

func test_a_life_buyback_keeps_ten_life() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 4)
	var slaughter := give_hand(0, "Slaughter")
	g.players[0].life = 13
	assert_eq(ai._paying_mode(g, slaughter.data), -1)
	g.players[0].life = 14
	assert_eq(ai._paying_mode(g, slaughter.data), 1)


# ------------------------------------------------------ Flowstone Flood's row --

func test_flowstone_flood_buys_back_when_the_roll_takes_a_spare_land() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 4)
	var flood := give_hand(0, "Flowstone Flood")
	give_hand(0, "Forest")
	give_hand(0, "Island")
	assert_eq(ai._paying_mode(g, flood.data), 1, "the average card it may lose is a land")

func test_flowstone_flood_keeps_a_hand_worth_more_than_the_flood() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 4)
	var flood := give_hand(0, "Flowstone Flood")
	give_hand(0, "Shivan Dragon")
	give_hand(0, "Serra Angel")
	assert_eq(ai._paying_mode(g, flood.data), 0, "a dragon at random is too dear")

func test_flowstone_flood_needs_a_card_and_thirteen_life() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 4)
	var flood := give_hand(0, "Flowstone Flood")
	assert_eq(ai._paying_mode(g, flood.data), 0, "nothing to discard: the row is unpayable")
	give_hand(0, "Forest")
	g.players[0].life = 12
	assert_eq(ai._paying_mode(g, flood.data), 0, "3 life would leave nine")
	g.players[0].life = 13
	assert_eq(ai._paying_mode(g, flood.data), 1)

func test_flowstone_flood_null_arm_and_hidden_information() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 4)
	var flood := give_hand(0, "Flowstone Flood")
	give_hand(0, "Forest")
	var first := ai._paying_mode(g, flood.data)
	give_hand(1, "Shivan Dragon")
	give_hand(1, "Lightning Bolt")
	g.players[0].library.reverse()
	g.players[1].library.reverse()
	assert_eq(ai._paying_mode(g, flood.data), first, "their hand and the libraries change nothing")
	var off := _ai(false)
	assert_eq(off._paying_mode(g, flood.data), -1, "gate off: the printed row")

func test_the_ai_casts_flowstone_flood_with_buyback_on_their_land() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 4)
	var land := put_battlefield(1, "Island")
	var flood := give_hand(0, "Flowstone Flood")
	var spare := give_hand(0, "Forest")
	g.players[0].lands_played_this_turn = 1   # the spare land stays a spare
	assert_string_contains(ai.act(g), "Flowstone Flood")
	assert_true(g.buyback_paid(flood))
	assert_eq(spare.zone, Mtg.Zone.GRAVEYARD, "the random card was the spare land")
	resolve_stack()
	assert_eq(land.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(flood.zone, Mtg.Zone.HAND)
