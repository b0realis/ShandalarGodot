extends GutTest
## StackHand + CardPreview: the original's hand window (a pile of full
## card faces offset by OVERLAP, last card fully visible — the owner's
## reference screenshots / s30 drawHandPanel) and the shared enlarged-card
## preview. Engine state is built directly — these are widget tests.


var game: MtgGame


func before_each() -> void:
	CardRegistry.ensure_loaded()
	game = MtgGame.new()
	game.setup(["Forest"], ["Forest"], "P0", "P1", 20, 20, 7)


func _instance(card_name: String) -> CardInstance:
	var inst := CardInstance.new(CardRegistry.get_card(card_name), 900 + randi() % 1000, 0)
	inst.zone = Mtg.Zone.HAND
	return inst


static func _no_highlight(_inst: CardInstance) -> int:
	return MiniCard.Highlight.NONE


func test_stack_builds_one_face_per_card_with_title_count() -> void:
	var stack := StackHand.new()
	add_child_autofree(stack)
	var hand := [_instance("Lightning Bolt"), _instance("Giant Growth"),
		_instance("Island")]
	stack.populate(hand, false, func(_inst): pass, _no_highlight)
	assert_eq(stack._pile.get_child_count(), 3)
	assert_string_contains(stack._title.text, "Your hand (3)")


func test_pile_overlaps_with_last_card_compact() -> void:
	# Card i sits at i*OVERLAP; the LAST card shows its COMPACT face
	# (name + art + type, no rules box — the reference's pile look; the
	# full text lives in the sidebar's enlarged view).
	var stack := StackHand.new()
	add_child_autofree(stack)
	stack.populate([_instance("Lightning Bolt"), _instance("Island"),
		_instance("Giant Growth")], false, func(_inst): pass, _no_highlight)
	var second: Control = stack._pile.get_child(1)
	assert_eq(second.position.y, CardPile.OVERLAP)
	assert_eq(stack.size.y,
		StackHand.TITLE_HEIGHT + 2 * CardPile.OVERLAP
			+ CardPile.COMPACT_FACE_HEIGHT + StackHand.FOOT,
		"the window is exactly its rows plus its chrome")
	# The last face is a TABLE CARD, not a shrunken enlarged one — the pile
	# shows no rules box, and the full text lives in the sidebar. (This
	# used to be measured against `CardPile.FACE_HEIGHT`, a dead constant
	# that derived a 188px face from `CardPreview.SIZE` and so implied a
	# second card size; the fortieth pass deleted it.)
	assert_eq(CardPile.COMPACT_FACE_HEIGHT, MiniCard.SIZE.y)
	assert_lt(CardPile.COMPACT_FACE_HEIGHT, CardPreview.SIZE.y)


static func _all_castable(_inst: CardInstance) -> int:
	return MiniCard.Highlight.CASTABLE


func test_row_name_is_yellow_when_castable_white_when_not() -> void:
	# The reference's hand rule: castable now = YELLOW name, else WHITE.
	var castable := StackHand.new()
	add_child_autofree(castable)
	castable.populate([_instance("Lightning Bolt"), _instance("Island")],
		false, func(_inst): pass, _all_castable)
	var yellow_card: MiniCard = castable._pile.get_child(0).get_child(0)
	var yellow: Color = yellow_card._name_label.get_theme_color("font_color")
	assert_gt(yellow.r, yellow.b, "castable names are yellow")
	assert_gt(yellow.g, yellow.b)

	var idle := StackHand.new()
	add_child_autofree(idle)
	idle.populate([_instance("Lightning Bolt"), _instance("Island")],
		false, func(_inst): pass, _no_highlight)
	var white_card: MiniCard = idle._pile.get_child(0).get_child(0)
	var white: Color = white_card._name_label.get_theme_color("font_color")
	assert_almost_eq(white.r, white.b, 0.08, "uncastable names are white")


func test_each_colour_keeps_its_own_stripe_slot() -> void:
	# Every colour owns a fixed place on the border, so a card that makes
	# several shows several at once — Black Lotus wears all five — and a
	# given colour lands in the same spot on every card.
	var lotus := _instance("Black Lotus")
	lotus.zone = Mtg.Zone.BATTLEFIELD
	var lotus_card := MiniCard.new(lotus)
	add_child_autofree(lotus_card)
	assert_eq(lotus_card._stripes.get_child_count(), 5,
		"Black Lotus wears one stripe per colour")

	var island := _instance("Island")
	island.zone = Mtg.Zone.BATTLEFIELD
	var island_card := MiniCard.new(island)
	add_child_autofree(island_card)
	assert_eq(island_card._stripes.get_child_count(), 1)
	var blue_x: float = island_card._stripes.get_child(0).position.x
	assert_eq(blue_x, MiniCard._stripe_x(MiniCard.STRIPE_SLOT[Mtg.ManaColor.U]),
		"an Island's blue sits in the blue slot")
	var lotus_xs: Array[float] = []
	for child in lotus_card._stripes.get_children():
		lotus_xs.append(child.position.x)
	assert_true(lotus_xs.has(blue_x),
		"Black Lotus's blue lands in that same slot")


func test_mana_producers_get_one_stripe_per_colour() -> void:
	# Lands (and Moxen) carry a diagonal stripe per colour they can make.
	var stack := StackHand.new()
	add_child_autofree(stack)
	stack.populate([_instance("Island"), _instance("Lightning Bolt"),
		_instance("Plains")], false, func(_inst): pass, _no_highlight)
	var island_card: MiniCard = stack._pile.get_child(0).get_child(0)
	var bolt_card: MiniCard = stack._pile.get_child(1).get_child(0)
	assert_eq(island_card._stripes.get_child_count(), 1, "Island makes one colour")
	assert_eq(bolt_card._stripes.get_child_count(), 0, "a burn spell makes no mana")


func test_hidden_hand_shows_anonymous_bands() -> void:
	var stack := StackHand.new()
	add_child_autofree(stack)
	stack.populate([_instance("Lightning Bolt")], true,
		func(_inst): pass, _no_highlight)
	var band: Button = stack._pile.get_child(0)
	assert_true(band.disabled)
	for child in band.get_children():
		assert_false(child is CardPreview, "hidden hands leak nothing")


func test_clicking_a_card_reports_the_instance() -> void:
	var stack := StackHand.new()
	add_child_autofree(stack)
	var bolt := _instance("Lightning Bolt")
	var clicked: Array = []
	stack.populate([bolt], false,
		func(inst): clicked.append(inst), _no_highlight)
	await get_tree().process_frame
	var holder: Button = stack._pile.get_child(0)
	holder.pressed.emit()
	assert_eq(clicked, [bolt])


func test_preview_shows_full_card_data() -> void:
	var preview := CardPreview.new()
	add_child_autofree(preview)
	var serra := _instance("Serra Angel")
	preview.show_card(serra)
	assert_true(preview.visible)
	assert_eq(preview._name_label.text, "Serra Angel")
	assert_string_contains(preview._type_label.text, "Creature")
	assert_string_contains(preview._type_label.text, "Angel")
	assert_string_contains(preview._oracle.text, "Flying")
	assert_eq(preview._pt_label.text, "4/4")


func test_preview_type_line_covers_legends_and_lands() -> void:
	var preview := CardPreview.new()
	add_child_autofree(preview)
	preview.show_card(_instance("Jedit Ojanen"))
	assert_string_contains(preview._type_label.text, "Legendary")
	preview.show_card(_instance("Island"))
	assert_string_contains(preview._type_label.text, "Basic")
	assert_string_contains(preview._type_label.text, "Land")
	assert_eq(preview._pt_label.text, "", "lands have no P/T box")


func test_duel_screen_boots_with_stack_hand_setting() -> void:
	# Force the setting for this test, restore after WITHOUT materializing
	# a default into the player's real settings file (Settings.clear_value).
	var had := Settings.has_value("hand_style")
	var prior: String = Settings.hand_style()
	Settings.set_value("hand_style", "stack")
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	if had:
		Settings.set_value("hand_style", prior)
	else:
		Settings.clear_value("hand_style")
	assert_not_null(screen.game)
	assert_true(screen._hand_rows[1] is StackHand, "bottom hand is the stack window")
	assert_not_null(screen._card_preview)
	assert_true(screen._card_preview.docked, "the big card docks in the sidebar middle")
	var stack: StackHand = screen._hand_rows[1]
	assert_eq(stack.preview, screen._card_preview)
	assert_eq(stack._pile.get_child_count(), screen.game.players[0].hand.size())


func test_sick_creature_wears_the_summoning_spiral() -> void:
	# The original marks a creature that can't act yet with Summon.pic's
	# spiral over its art; a ready creature has none.
	var sick := _instance("Savannah Lions")
	sick.zone = Mtg.Zone.BATTLEFIELD
	sick.summoning_sick = true
	var sick_card := MiniCard.new(sick)
	add_child_autofree(sick_card)
	assert_true(sick_card._sick_spiral.visible, "sick creatures show the spiral")

	var ready := _instance("Savannah Lions")
	ready.zone = Mtg.Zone.BATTLEFIELD
	ready.summoning_sick = false
	var ready_card := MiniCard.new(ready)
	add_child_autofree(ready_card)
	assert_false(ready_card._sick_spiral.visible, "a ready creature has none")


func test_keyword_badges_appear_on_permanents_in_play() -> void:
	# The original badges what is IN PLAY (s30: getKeywordIcons drawn along
	# the card's bottom edge); a card in hand carries none.
	var flyer := _instance("Serra Angel")
	flyer.zone = Mtg.Zone.BATTLEFIELD
	var played := MiniCard.new(flyer)
	add_child_autofree(played)
	assert_gt(played._badges.get_child_count(), 0, "a flyer in play badges its keyword")

	var in_hand := MiniCard.new(_instance("Serra Angel"))
	add_child_autofree(in_hand)
	assert_eq(in_hand._badges.get_child_count(), 0, "cards in hand carry no badges")


func test_big_card_writes_star_pt_for_dynamic_creatures() -> void:
	# Nightmare's printed P/T is 0/0 with a static that sets it — the
	# original prints "*/*" on such cards.
	var preview := CardPreview.new()
	add_child_autofree(preview)
	preview.show_card(_instance("Nightmare"))
	assert_eq(preview._pt_label.text, "*/*", "dynamic P/T prints as stars")
	preview.show_card(_instance("Grizzly Bears"))
	assert_eq(preview._pt_label.text, "2/2", "a printed P/T prints as itself")


func test_every_card_shows_its_set_icon_or_a_short_label() -> void:
	# Sets the original never gave a symbol still name themselves.
	var preview := CardPreview.new()
	add_child_autofree(preview)
	preview.show_card(_instance("Island"))          # 2ed — no symbol
	assert_false(preview._set_icon.visible)
	assert_eq(preview._set_text.text, "2")
	assert_eq(preview._set_suffix.text, "nd", "the ordinal rides raised")
	preview.show_card(_instance("Moat"))            # leg — has a symbol
	assert_true(preview._set_icon.visible)
	assert_eq(preview._set_text.text, "")


func test_protection_shows_a_badge_in_play() -> void:
	var knight := _instance("White Knight")   # protection from black
	knight.zone = Mtg.Zone.BATTLEFIELD
	var card := MiniCard.new(knight)
	add_child_autofree(card)
	assert_gt(card._badges.get_child_count(), 1,
		"first strike AND the protection shield")


func test_permanents_badge_their_activation_cost() -> void:
	# The reference puts the ability's mana symbol at a permanent's
	# bottom-left (Urza's Avenger wears the "0" of its "{0}:" ability).
	var cop := _instance("Circle of Protection: Red")   # "{1}: prevent..."
	cop.zone = Mtg.Zone.BATTLEFIELD
	var with_ability := MiniCard.new(cop)
	add_child_autofree(with_ability)
	assert_gt(with_ability._badges.get_child_count(), 0,
		"an activatable permanent shows its cost")

	var vanilla := _instance("Grizzly Bears")
	vanilla.zone = Mtg.Zone.BATTLEFIELD
	var plain := MiniCard.new(vanilla)
	add_child_autofree(plain)
	assert_eq(plain._badges.get_child_count(), 0,
		"a vanilla creature badges nothing")


func test_hand_hint_requires_priority() -> void:
	# The castable hint must not promise an action the engine refuses:
	# both play_land and cast_spell need priority (2026-08 code review).
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var seat := 0
	var card: CardInstance = screen.game.players[seat].hand[0]
	screen.game.priority_player = screen.game.opponent_of(seat)
	assert_eq(screen._highlight_for(card), MiniCard.Highlight.NONE,
		"nothing in hand is highlighted without priority")


func test_creature_that_can_swing_is_not_drawn_sick() -> void:
	# Instill Energy lifts the attack gate via cur_attacks_as_if_hasty
	# rather than granting HASTE — such a creature must not wear the
	# summoning-sickness spiral (2026-08 code review).
	var lion := _instance("Savannah Lions")
	lion.zone = Mtg.Zone.BATTLEFIELD
	lion.summoning_sick = true
	lion.cur_attacks_as_if_hasty = true
	var card := MiniCard.new(lion)
	add_child_autofree(card)
	assert_false(card._sick_spiral.visible, "it can swing — no spiral")


func test_graveyard_shows_its_top_card() -> void:
	# The reference shows a card face in a full graveyard and the
	# empty-grave plate in an empty one.
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var empty_face: Texture2D = screen._grave_icons[0].texture
	var dead := screen.game.players[0].hand[0]
	screen.game.players[0].hand.erase(dead)
	dead.zone = Mtg.Zone.GRAVEYARD
	screen.game.players[0].graveyard.append(dead)
	screen._refresh()
	assert_ne(screen._grave_icons[0].texture, empty_face,
		"a filled graveyard shows its top card, not the empty plate")


func test_ui_casts_an_x_targets_spell() -> void:
	# "Tap X target creatures" — the UI must collect X targets, not one.
	# (The engine grew variable targeting in wave 43; the screen used to
	# mirror the old one-ref-per-effect model and could not cast these.)
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var g: MtgGame = screen.game
	var word := CardInstance.new(CardRegistry.get_card("Word of Binding"),
		g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[word.id] = word
	word.zone = Mtg.Zone.HAND
	g.players[0].hand.append(word)
	var victims: Array[CardInstance] = []
	for i in 2:
		var bear := CardInstance.new(CardRegistry.get_card("Grizzly Bears"),
			g._next_instance_id, 1)
		g._next_instance_id += 1
		g._instances[bear.id] = bear
		g._put_on_battlefield(bear, 1)
		victims.append(bear)

	screen._pending_card = word
	screen._pending_ability_index = -1
	screen._pending_pid = 0
	screen._pending_x = 2
	screen._build_target_slots(word.data, 0)
	assert_eq(screen._pending_slots.size(), 1, "one targeting effect")
	assert_eq(screen._pending_slots[0]["max"], 2, "X=2 means two targets")
	screen._advance_pending()
	screen._try_take_target(TargetRef.card(victims[0]))
	assert_eq(screen._pending_groups[0].size(), 1, "first target taken")
	# CR 601.2c still holds — one object cannot be targeted twice for one
	# instance of a spell — but the second click is now how you TAKE IT
	# BACK rather than a refusal (docs/duel-todo.md §3.1, s30
	# `selectTarget`). Either way the group never holds a duplicate.
	screen._try_take_target(TargetRef.card(victims[0]))
	assert_eq(screen._pending_groups[0].size(), 0, "the pick came back off")
	screen._try_take_target(TargetRef.card(victims[0]))
	assert_eq(screen._pending_groups[0].size(), 1, "and can be picked again")
	# The final pick submits the cast, so assert the OUTCOME: the spell
	# reached the stack with both targets (a target-count mismatch would
	# have been refused instead).
	# A sorcery needs seat 0's main phase, priority, an empty stack and
	# the mana — set the table directly (this is a widget test).
	g.active_player = 0
	g.priority_player = 0
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.MAIN1)
	g.awaiting_attackers = false
	g.awaiting_blockers = false
	g.players[0].mana_pool.add(Mtg.ManaColor.B, 2)
	g.players[0].mana_pool.add(Mtg.ManaColor.C, 2)
	screen._try_take_target(TargetRef.card(victims[1]))
	assert_eq(g.stack.size(), 1, "the X-target spell went on the stack")
	assert_eq(g.stack[0].targets.size(), 2, "carrying both targets")


func test_ui_divides_damage_across_chosen_targets() -> void:
	# Pyrotechnics: the shares are DIALLED IN, one click per point
	# (`@PYROTECHNICS`, `Program/prompts.txt:698` — §6.14), and the refs
	# that reach the stack carry what the player dialled. This used to
	# spread the total as evenly as it would go, marked SIMPLIFIED; the
	# marker is lifted and this is what lifted it.
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var g: MtgGame = screen.game
	var pyro := CardInstance.new(CardRegistry.get_card("Pyrotechnics"),
		g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[pyro.id] = pyro
	pyro.zone = Mtg.Zone.HAND
	g.players[0].hand.append(pyro)
	var giant := CardInstance.new(CardRegistry.get_card("Hill Giant"),
		g._next_instance_id, 1)
	g._next_instance_id += 1
	g._instances[giant.id] = giant
	g._put_on_battlefield(giant, 1)
	g.recalculate()
	g.active_player = 0
	g.priority_player = 0
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.MAIN1)
	g.awaiting_attackers = false
	g.awaiting_blockers = false
	g.players[0].mana_pool.add(Mtg.ManaColor.R, 1)
	g.players[0].mana_pool.add(Mtg.ManaColor.C, 4)

	screen._click_hand_card(pyro)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	assert_eq(screen._prompt_label.text, "Select (1st of 4) any target.")
	# Three points into the Giant, then the last into the opponent — the
	# same card clicked again ADDS a point rather than deselecting, which
	# is the one place the §3.1 take-back does not apply.
	screen._on_card_clicked(giant)
	assert_eq(screen._prompt_label.text, "Select (2nd of 4) any target.")
	screen._on_card_clicked(giant)
	screen._on_card_clicked(giant)
	assert_eq(screen._prompt_label.text, "Select (4th of 4) any target.")
	assert_eq(screen._pending_groups[0].size(), 1, "one target, three points")
	# The last point spends itself and the cast submits.
	screen._on_life_clicked(1)
	assert_eq(g.stack.size(), 1, "the spell went on the chain")
	var refs: Array = g.stack[0].targets
	assert_eq(refs.size(), 2)
	var by_amount := {}
	for ref in refs:
		by_amount[ref.is_player] = ref.amount
	assert_eq(by_amount[false], 3, "three damage where the player put it")
	assert_eq(by_amount[true], 1, "and one on the opponent")


func test_wounded_creature_wears_the_damage_marker() -> void:
	# The original marks damage with Damage.pic's dagger plus the amount
	# (its raw 84x26 file is a clean image+mask pair; the converted copy
	# is not, which is why the import prefers the raw one).
	var hurt := _instance("Serra Angel")
	hurt.zone = Mtg.Zone.BATTLEFIELD
	hurt.damage = 3
	var card := MiniCard.new(hurt)
	add_child_autofree(card)
	assert_true(card._damage_icon.visible, "a wounded creature shows the marker")
	assert_not_null(card._damage_icon.texture, "the mask decoded")
	assert_eq(card._damage_count.text, "3")

	var whole := _instance("Serra Angel")
	whole.zone = Mtg.Zone.BATTLEFIELD
	var fine := MiniCard.new(whole)
	add_child_autofree(fine)
	assert_false(fine._damage_icon.visible, "an undamaged creature shows none")


func test_mana_stripes_are_native_size_not_squeezed() -> void:
	# The band is a 2px diagonal: scaling the cell down dissolved it, so
	# the stripe is cropped 1:1 from the sheet and drawn unscaled.
	var tex := MiniCard.stripe_texture(Mtg.ManaColor.W)
	if tex == null:
		pass_test("no skin imported — stripes fall back to none")
		return
	assert_eq(tex.get_size(), Vector2(MiniCard.STRIPE_W, MiniCard.STRIPE_H),
		"the stripe is the sheet's native window, not a rescale")


func test_tapped_card_keeps_its_dimensions() -> void:
	# Tapping turns the card 90 degrees; it must not resize.
	var inst := _instance("Savannah Lions")
	inst.zone = Mtg.Zone.BATTLEFIELD
	inst.tapped = true
	var card := MiniCard.new(inst)
	add_child_autofree(card)
	assert_true(card.wants_rotation(), "a tapped permanent turns")
	assert_eq(card.custom_minimum_size, MiniCard.SIZE,
		"the card keeps its exact dimensions when turned")


# --------------------------------------------- the 1997 window chrome --

func test_window_chrome_is_one_continuous_nine_patch() -> void:
	# The original frames the WHOLE window in one piece: the patterned
	# border runs unbroken down both sides from the title bar to the foot
	# of the list. Ours used to be a title strip with a separate bordered
	# box under it, which stepped at the corners.
	var stack := StackHand.new()
	add_child_autofree(stack)
	stack.set_deck_color("red")
	stack.populate([_instance("Lightning Bolt"), _instance("Island")],
		false, func(_inst): pass, _no_highlight)
	if stack._frame.texture == null:
		assert_true(stack._fallback.visible, "no skin: the flat frame stands in")
		return
	assert_true(stack._frame.visible)
	assert_false(stack._fallback.visible, "the texture replaces the flat frame")
	# One node, anchored to the whole window — not just its top.
	assert_eq(stack._frame.anchor_bottom, 1.0, "the chrome spans the window")
	assert_eq(stack._frame.patch_margin_left, int(StackHand.BORDER))
	assert_eq(stack._frame.patch_margin_right, int(StackHand.BORDER))
	assert_eq(stack._frame.patch_margin_top, int(StackHand.TITLE_HEIGHT))
	assert_eq(stack._frame.patch_margin_bottom, int(StackHand.FOOT))


func test_window_texture_rebuilds_the_missing_left_border() -> void:
	# Hand_<colour>.pic (145x51) carries the right border but no left one;
	# window_texture mirrors those BORDER columns onto the left so the
	# frame is symmetric and nine-patches cleanly.
	var source := GameSkin.texture("hand_panel_red")
	if source == null:
		pass_test("no skin imported")
		return
	var whole := StackHand.window_texture("red")
	assert_not_null(whole)
	assert_eq(whole.get_width(), source.get_width() + int(StackHand.BORDER))
	assert_eq(whole.get_height(), source.get_height())
	var img := whole.get_image()
	# Column 0 is the mirror of the source's last column.
	assert_eq(img.get_pixel(0, 20),
		source.get_image().get_pixel(source.get_width() - 1, 20))


func test_the_list_sits_inside_the_frame() -> void:
	var stack := StackHand.new()
	add_child_autofree(stack)
	stack.populate([_instance("Lightning Bolt")], false,
		func(_inst): pass, _no_highlight)
	assert_eq(stack._pile.offset_left, StackHand.BORDER)
	assert_eq(stack._pile.offset_right, -StackHand.BORDER)
	assert_eq(stack._pile.offset_top, StackHand.TITLE_HEIGHT,
		"the rows start under the whole title cap")
	assert_eq(stack.size.x, CardPile.WIDTH + 2.0 * StackHand.BORDER,
		"the window is its cards plus the frame")


func test_title_is_light_grey_not_yellow() -> void:
	# Yellow is the CASTABLE-card colour; the original's bar reads light
	# grey/white, and having both wear yellow made the title look like a row.
	var stack := StackHand.new()
	add_child_autofree(stack)
	stack.populate([_instance("Island")], false, func(_inst): pass, _no_highlight)
	var ink: Color = stack._title.get_theme_color("font_color")
	assert_almost_eq(ink.r, ink.b, 0.10, "the title is neutral, not gold")
	assert_gt(ink.get_luminance(), 0.7, "and light")


func test_hovered_row_lifts_and_its_name_turns_yellow() -> void:
	# The owner's zoomed hand: the row under the pointer is LIGHTER and
	# its name reads YELLOW.
	var stack := StackHand.new()
	add_child_autofree(stack)
	stack.populate([_instance("Island"), _instance("Lightning Bolt")],
		false, func(_inst): pass, _no_highlight)
	var holder: Button = stack._pile.get_child(0)
	var face: MiniCard = holder.get_child(0)
	var resting: Color = face.modulate
	holder.mouse_entered.emit()
	assert_true(face.hovered)
	assert_gt(face.modulate.get_luminance(), resting.get_luminance(),
		"the hovered row lightens")
	var ink: Color = face._name_label.get_theme_color("font_color")
	assert_gt(ink.r, ink.b, "and its name turns yellow")
	holder.mouse_exited.emit()
	assert_false(face.hovered)
	assert_eq(face.modulate, resting)


func test_card_art_is_inset_inside_its_frame() -> void:
	# The reference insets a card's art inside the frame, with the border
	# visible on all four sides and a gold/tan rule round the picture.
	var inst := _instance("Savannah Lions")
	inst.zone = Mtg.Zone.BATTLEFIELD
	var card := MiniCard.new(inst)
	add_child_autofree(card)
	assert_gt(card._art.anchor_left, 0.05, "art clears the left border")
	assert_lt(card._art.anchor_right, 0.95, "art clears the right border")
	assert_lt(card._art.anchor_bottom, 0.95, "art clears the bottom border")
	assert_not_null(card._art_frame, "the art window keeps its bevel")
	assert_true(card._art_frame.visible)


# ------------------------------------ the OPPONENT's hand (manual p.114) --
#
# *"Only the title bar of your opponent's hand is visible; this is to keep
# you aware of how many cards are in that hand."* So it is THIS window with
# no list under it — not a chip, a bar or a badge of its own — and these
# pins exist because it was one: a disabled Button wearing the raw 145x51
# `hand_panel_<colour>` sheet as an UNPATCHED `StyleBoxTexture` at 150x22,
# which squashed the whole window into a strip and crushed the ▲ painted
# into its left edge (the owner: "cropped at left end").

func _plate_label(plate: Control) -> Label:
	for child in plate.get_children():
		if child is Label:
			return child
		for grandchild in child.get_children():
			if grandchild is Label:
				return grandchild
	return null


func test_the_opponents_plate_is_the_same_window_at_its_empty_height() -> void:
	var plate := StackHand.title_plate("red", "Opponent (5)")
	add_child_autofree(plate)
	assert_eq(plate.custom_minimum_size,
		Vector2(StackHand.WIDTH, StackHand.TITLE_HEIGHT + StackHand.FOOT),
		"the player's own window at zero rows — same width, same chrome")
	var empty := StackHand.new()
	add_child_autofree(empty)
	assert_eq(plate.custom_minimum_size, empty.custom_minimum_size,
		"and literally the size an empty StackHand takes")


func test_the_opponents_plate_nine_patches_the_sheet_it_never_squashes_it() -> void:
	# The whole defect in one assertion: the sheet has a border, a title
	# bar and two painted arrows, so it must be PATCHED, never scaled.
	if not GameSkin.is_present():
		pass_test("no 1997 skin imported; the flat fallback is exercised below")
		return
	var plate := StackHand.title_plate("red", "Opponent (5)")
	add_child_autofree(plate)
	var frame: NinePatchRect = null
	for child in plate.get_children():
		if child is NinePatchRect:
			frame = child
	assert_not_null(frame, "the plate is a nine-patch, not a stretched texture")
	assert_eq(frame.patch_margin_left, int(StackHand.BORDER))
	assert_eq(frame.patch_margin_right, int(StackHand.BORDER))
	assert_eq(frame.patch_margin_top, int(StackHand.TITLE_HEIGHT),
		"the whole top cap — border, bar and the band — is unstretched")
	assert_eq(frame.patch_margin_bottom, int(StackHand.FOOT))
	assert_eq(frame.axis_stretch_vertical,
		NinePatchRect.AXIS_STRETCH_MODE_TILE)
	assert_eq(frame.texture, StackHand.window_texture("red"),
		"the same made-whole texture the player's own window wears")


func test_the_opponents_plate_leaves_the_arrows_to_the_texture() -> void:
	# The sheet paints ▲ at x 1..9 and ▼ at x 125..132. The old chip ALSO
	# wrote them into its own text, so each appeared twice.
	var plate := StackHand.title_plate("red", "Opponent (5)")
	add_child_autofree(plate)
	var label := _plate_label(plate)
	assert_not_null(label, "the plate letters its title on the bar")
	assert_false(label.text.contains("↑"), "the ▲ belongs to the texture")
	assert_false(label.text.contains("↓"), "and so does the ▼")
	assert_eq(label.offset_left, StackHand.ARROW_ZONE + 2.0,
		"the text starts past the painted ▲, exactly as on our own window")


func test_the_opponents_hand_wears_the_1997_word() -> void:
	# `@WINDOWTITLES` (UIStrings.txt:155) gives this window the single word
	# `Opponent`. s30's `Opp Hand` is s30's. The count in brackets is [QoL],
	# in the same form our own `Your hand (N)` uses — and it is the reason
	# manual p.114 gives for showing the bar at all.
	assert_true(DuelScreen.OPPONENT_HAND_TITLE.begins_with("Opponent"),
		"the original's noun, not s30's abbreviation")
	assert_eq(DuelScreen.OPPONENT_HAND_TITLE % 5, "Opponent (5)")


func test_the_duel_screen_hangs_that_plate_in_the_opponents_half() -> void:
	# Seat 1 must be an AI for its hand to be HIDDEN — a hotseat or a demo
	# shows both hands in full and there is no plate to find.
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = DuelConfig.vs_ai_default(AiProfile.wizard())
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_true(screen.hidden_hands.has(1), "the AI's hand is face-down")
	var row: Control = screen._hand_rows[0]   # [opponent, player]
	assert_true(row is HFlowContainer, "the opponent's hand row exists")
	assert_gte(row.custom_minimum_size.y,
		StackHand.TITLE_HEIGHT + StackHand.FOOT,
		"the row leaves the whole plate room")
	assert_eq(row.get_child_count(), 1, "one plate, nothing else")
	var label := _plate_label(row.get_child(0))
	assert_not_null(label)
	assert_eq(label.text,
		DuelScreen.OPPONENT_HAND_TITLE % screen.game.players[1].hand.size(),
		"and it counts the opponent's cards")


# --------------------------------- the ILLUSTRATOR CREDIT (Duel.hlp §6) --
#
# `Duel.hlp`'s "Parts of the Card" topic numbers the twelve labelled parts
# of the enlarged card and **part 6 is `Artist`** — the credit the printed
# card carries in its bottom-LEFT corner as `Illus. <name>`. The Showcase
# drew eleven of the twelve and not that one.

func test_the_pool_knows_who_illustrated_its_cards() -> void:
	CardRegistry.ensure_loaded()
	assert_ne(CardRegistry.artist_of("Air Elemental"), "",
		"the cards/data snapshot carries an artist per printing")
	var lion := CardRegistry.get_card("Savannah Lions")
	assert_ne(lion.artist, "",
		"and the loader hangs it on CardData beside the set code")


func test_the_showcase_credits_the_illustrator_bottom_left() -> void:
	var preview := CardPreview.new()
	add_child_autofree(preview)
	var serra := _instance("Serra Angel")
	preview.show_card(serra)
	assert_true(preview._artist_label.visible)
	assert_eq(preview._artist_label.text,
		CardPreview.ILLUS_PREFIX + serra.data.artist)
	assert_true(preview._artist_label.text.begins_with("Illus. "),
		"the form the printed card uses")
	# BOTTOM-LEFT of the frame's bottom border (0.920-0.995), and it stops
	# short of the P/T box so no name can ever run into a 10/10.
	assert_eq(preview._artist_label.anchor_top, preview._pt_label.anchor_top,
		"the two marks share the bottom border")
	assert_lt(preview._artist_label.anchor_left, 0.2, "left corner")
	assert_lte(preview._artist_label.anchor_right, preview._pt_label.anchor_left,
		"and never reaches into the P/T's half of the band")
	assert_eq(preview._artist_label.text_overrun_behavior,
		TextServer.OVERRUN_TRIM_ELLIPSIS,
		"a long name is trimmed, never shrunk or wrapped")


func test_a_card_with_no_power_toughness_still_gets_its_credit() -> void:
	var preview := CardPreview.new()
	add_child_autofree(preview)
	var bolt := _instance("Lightning Bolt")
	preview.show_card(bolt)
	assert_eq(preview._pt_label.text, "", "an instant has no P/T box")
	assert_true(preview._artist_label.visible,
		"the credit has the whole bottom border to itself")


func test_an_unknown_artist_draws_nothing_rather_than_an_empty_credit() -> void:
	# An older cards/data snapshot has no artists in it at all, and a
	# printing Scryfall does not credit leaves the field empty. Neither may
	# put a bare "Illus. " on the card.
	var preview := CardPreview.new()
	add_child_autofree(preview)
	var nameless := CardData.new("Test Subject", "{1}", Mtg.CardType.INSTANT)
	nameless.oracle("Does nothing.")
	assert_eq(nameless.artist, "", "CardData defaults to no credit")
	preview.show_card(CardInstance.new(nameless, 12345, 0))
	assert_eq(preview._artist_label.text, "")
	assert_false(preview._artist_label.visible)


func test_the_credit_follows_the_printing_the_card_ships_in() -> void:
	# Fourth Edition redrew a great many Alpha cards, so a card whose
	# implementation lives in cards/sets/4ed/ must credit 4ed's artist.
	CardRegistry.ensure_loaded()
	var by_set := CardRegistry.artist_of("Air Elemental", "4ed")
	var any := CardRegistry.artist_of("Air Elemental")
	assert_ne(by_set, "", "the set-specific lookup answers")
	assert_ne(any, "", "and so does the fall-back")
	assert_eq(CardRegistry.artist_of("No Such Card At All"), "",
		"a name nothing lists gets no credit, not a wrong one")


# ================================================ §3.6 folding the hand --
#
# The hand window floats over the player's own territory, so during a
# declaration it covers the very creatures being declared. s30 gives the
# fold three doors — the painted ▲/▼ zones, a click anywhere on the header
# and the `H` key (`duel.go:1172-1174`, `1673-1686`) — *"while the header
# bar stays visible so the hand can be expanded again."* We had only the
# arrow zones.
#
# THE 1997 CONSTRAINT the s30 route runs into: the middle of that bar is
# the DRAG HANDLE. `Duel.hlp`, topic **Hands**: *"Both of these windows are
# movable. To move a hand window, click and drag on the bar at the top of
# the window."* So a press on the header is only a fold if it never became
# a drag, which is what DRAG_SLOP decides.

func _bar_press(hand: StackHand, at: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = at
	hand._on_title_input(ev)


## A live window, laid out. The title bar is anchored TOP_WIDE, so its
## width only exists after Godot has run a layout pass over the parent —
## and the ARROW_ZONE hit test reads that width.
func _hand_window() -> StackHand:
	var hand := StackHand.new()
	add_child_autofree(hand)
	hand.populate([], false, Callable(), Callable())
	await get_tree().process_frame
	return hand


func test_a_click_on_the_header_middle_folds_the_hand() -> void:
	var hand: StackHand = await _hand_window()
	assert_false(hand.is_collapsed())
	var middle := Vector2(hand._title_bg.size.x / 2.0, 8)
	_bar_press(hand, middle, true)
	_bar_press(hand, middle, false)
	assert_true(hand.is_collapsed(), "press and release, no movement: a fold")
	_bar_press(hand, middle, true)
	_bar_press(hand, middle, false)
	assert_false(hand.is_collapsed(), "and the same click unfolds it")


func test_dragging_the_header_moves_the_window_and_does_not_fold_it() -> void:
	var hand: StackHand = await _hand_window()
	var middle := Vector2(hand._title_bg.size.x / 2.0, 8)
	_bar_press(hand, middle, true)
	# The headless pointer never leaves the origin, so the press is
	# BACKDATED far from it: the slop test measures how far the pointer has
	# travelled since the press, and that is the quantity under test.
	hand._drag_from = Vector2(500, 500)
	hand._on_title_input(InputEventMouseMotion.new())
	_bar_press(hand, middle, false)
	assert_true(hand._drag_moved, "the gesture travelled")
	assert_false(hand.is_collapsed(), "so it was a drag, not a fold")
	# A real drag ENDS BY SAVING the window's corner, and this one dropped
	# it at the origin. Leave no trace, exactly as `Settings.clear_value`
	# is documented for: writing the old value back would materialise a
	# default into the player's own file.
	Settings.clear_value("hand_stack_pos")


func test_a_wobble_inside_the_slop_does_not_move_the_window() -> void:
	# THE BUG THIS PINS: DRAG_SLOP gated the `_drag_moved` FLAG but not the
	# movement — `global_position` was rewritten on every motion event.
	# So the 1-2px a mouse travels under the finger during an ordinary
	# click nudged the window, and then the release branch, seeing
	# `_drag_moved == false`, toggled the hand and skipped the
	# `Settings.set_value("hand_stack_pos", ...)`. The window drifted on
	# every header click and snapped back next duel.
	var hand: StackHand = await _hand_window()
	hand.global_position = Vector2(120, 90)
	var middle := Vector2(hand._title_bg.size.x / 2.0, 8)
	_bar_press(hand, middle, true)
	# The headless pointer never leaves the origin, so the PRESS is
	# backdated 2px away from it — the wobble, inside the slop.
	hand._drag_from = hand.get_global_mouse_position() + Vector2(2, 0)
	hand._drag_offset = hand._drag_from - hand.global_position
	var before := hand.global_position
	hand._on_title_input(InputEventMouseMotion.new())
	assert_false(hand._drag_moved, "2px is inside DRAG_SLOP: still a click")
	assert_eq(hand.global_position, before,
		"...so the window must not have moved either")
	_bar_press(hand, middle, false)
	assert_true(hand.is_collapsed(), "and the release folds the hand")


func test_the_painted_arrow_zones_still_fold_and_unfold() -> void:
	# The ▲/▼ are drawn into the 1997 Hand_<colour> sheet itself; the
	# header click is an addition beside them, never a replacement.
	var hand: StackHand = await _hand_window()
	_bar_press(hand, Vector2(4, 8), true)
	assert_true(hand.is_collapsed(), "▲ folds")
	_bar_press(hand, Vector2(hand._title_bg.size.x - 4, 8), true)
	assert_false(hand.is_collapsed(), "▼ unfolds")


func test_the_header_stays_readable_while_folded() -> void:
	# "…while the header bar stays visible so the hand can be expanded
	# again", and the title keeps the count plus s30's [+] marker.
	var hand: StackHand = await _hand_window()
	hand.toggle_collapsed()
	assert_true(hand.is_collapsed())
	assert_string_contains(hand._title.text, "[+]")
	assert_true(hand._title_bg.visible)


func test_the_H_key_folds_the_hand_from_the_duel_screen() -> void:
	# The whole point of the key: reachable mid-declaration, when the
	# pointer is busy picking creatures the hand is sitting on top of.
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	if not (screen._hand_rows.size() > 1 and screen._hand_rows[1] is StackHand):
		pass_test("this build runs the fan hand, which covers nothing")
		return
	var hand: StackHand = screen._hand_rows[1]
	assert_false(hand.is_collapsed())
	var key := InputEventKey.new()
	key.keycode = KEY_H
	key.pressed = true
	screen._unhandled_key_input(key)
	assert_true(hand.is_collapsed(), "H folds")
	screen._unhandled_key_input(key)
	assert_false(hand.is_collapsed(), "H unfolds")
