extends GameTest
## THE SMALL CARD — `game/duel/mini_card.gd`, the single generator for every
## card on the table, in the hand pile, in the graveyard and exile views, in
## the deck builder and on the help screen's icon pages.
##
## Three things live here, and each is a fidelity pin the code alone cannot
## defend:
##
##   1. **The 1997 STATE VOCABULARY.** `@CUECARD_SMALLCARD`
##      (`UIStrings.txt:732`) names the ten states a card on the table can
##      be in. The overlays draw them and the tooltips SAY them, verbatim.
##   2. **P/T belongs to the SMALL card.** Manual p.114/p.118: the card in
##      play shows what CHANGED, the Showcase shows what was PRINTED. Both
##      halves of that are pinned here, including the one that stops s30's
##      `power/(toughness − damage)` being ported by mistake.
##   3. **The BADGES.** Which ability-sheet cells we draw, that they are
##      deduped, that they carry no black backdrop, and that the blank cell
##      17 stays blank.


var _card: MiniCard = null


func _mini(inst: CardInstance, with_game := true) -> MiniCard:
	var w := MiniCard.new(inst)
	if with_game:
		w.game = g
	add_child_autofree(w)
	_card = w
	return w


func _states(inst: CardInstance, with_game := true) -> Array[int]:
	return _mini(inst, with_game).active_states()


# ============================================== §2.9 — stats and damage ==

func test_the_small_card_shows_the_live_power_and_toughness() -> void:
	# Manual p.114: "the CURRENT power and toughness of each creature is
	# displayed on the card in play".
	var lion := put_battlefield(0, "Savannah Lions")
	put_battlefield(0, "Crusade")
	g.recalculate()
	assert_eq(_mini(lion)._pt_label.text, "3/2", "Crusade's +1/+1 shows here")


func test_the_showcase_shows_the_printed_power_and_toughness() -> void:
	# THE 1997 PIN, manual p.114: "(The SHOWCASE always shows the ORIGINAL
	# power and toughness.)" and p.118: changes are noted "on the
	# representation of the card IN PLAY, not here."
	var lion := put_battlefield(0, "Savannah Lions")
	put_battlefield(0, "Crusade")
	g.recalculate()
	assert_eq(_mini(lion)._pt_label.text, "3/2", "the table card is live")
	assert_eq(CardPreview._power_toughness(lion), "2/1",
		"the Showcase is printed — manual p.114")


func test_the_showcase_keeps_its_star_slash_star_quirk() -> void:
	# A printed 0/0 whose statics set its size still reads */* — the
	# fifteenth pass's rule, unchanged by the printed-P/T fix.
	var nightmare := put_battlefield(0, "Nightmare")
	assert_eq(CardPreview._power_toughness(nightmare), "*/*")


func test_a_pumped_creature_letters_its_stats_green() -> void:
	var lion := put_battlefield(0, "Savannah Lions")
	put_battlefield(0, "Crusade")
	g.recalculate()
	var ink := _mini(lion).pt_color()
	assert_gt(ink.g, ink.r, "pumped reads GREEN (s30 duel.go:3402-3416)")
	assert_gt(ink.g, ink.b)


func test_a_weakened_creature_letters_its_stats_red() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var weakness := _make_instance(1, "Weakness")
	g.attach_aura_from_anywhere(weakness, bears, 1)
	var ink := _mini(bears).pt_color()
	assert_gt(ink.r, ink.g, "weakened reads RED")
	assert_gt(ink.r, ink.b)


func test_an_unmodified_creature_letters_its_stats_white() -> void:
	var lion := put_battlefield(0, "Savannah Lions")
	assert_eq(_mini(lion).pt_color(), Color.WHITE)


func test_a_plus_two_minus_two_reads_as_pumped() -> void:
	# s30's rule is an OR across both stats with PUMPED TESTED FIRST, so a
	# creature that grew in one stat and shrank in the other reads green.
	# Made explicit so nobody "fixes" it later.
	var lion := put_battlefield(0, "Savannah Lions")
	lion.cur_power = lion.data.power + 2
	lion.cur_toughness = lion.data.toughness - 2
	var ink := _mini(lion).pt_color()
	assert_gt(ink.g, ink.r, "pumped wins the OR")


func test_a_card_in_hand_is_never_coloured() -> void:
	var lion := give_hand(0, "Savannah Lions")
	assert_eq(_mini(lion).pt_color(), Color.WHITE,
		"a hand card has no live values to differ from")


func test_damage_does_not_change_the_printed_toughness() -> void:
	# THE ANTI-s30 PIN. s30 prints `power/(toughness − damage)`, so its 3/4
	# with 2 damage reads "3/2" (duel_stats_test.go:10-26). The ORIGINAL
	# prints the live P/T AND a separate `Damage: %d` marker — manual p.114
	# plus the cue card — which is what we do. Porting
	# `displayedCreatureStats` would double-count against the dagger.
	var wall := put_battlefield(0, "Wall of Bone")   # 1/4
	wall.damage = 2
	var card := _mini(wall)
	assert_eq(card._pt_label.text, "1/4", "toughness is NOT reduced by damage")
	assert_true(card.active_states().has(MiniCard.State.DAMAGE))
	assert_eq(card._damage_count.text, "2", "the marker carries the amount")


func test_the_damage_marker_says_the_1997_cue_card_with_its_number() -> void:
	var wall := put_battlefield(0, "Wall of Bone")
	wall.damage = 3
	var card := _mini(wall)
	assert_true(card.tooltip_text.contains("Damage: 3"),
		"`Damage: %d` filled in — @CUECARD_SMALLCARD")


# ================================ §2.10 / §6.15 — the state vocabulary ==

func test_every_state_carries_its_1997_cue_card_string_verbatim() -> void:
	# THE WORDING PIN — what stops the vocabulary drifting back to ours.
	# `@CUECARD_SMALLCARD`, UIStrings.txt:732 (latin-1; grep needs -a).
	assert_eq(MiniCard.STATE_CUE[MiniCard.State.SUMMONING_SICK],
		"Summoning sickness")
	assert_eq(MiniCard.STATE_CUE[MiniCard.State.DAMAGE], "Damage: %d")
	assert_eq(MiniCard.STATE_CUE[MiniCard.State.DYING], "Dying")
	assert_eq(MiniCard.STATE_CUE[MiniCard.State.WILL_UNTAP],
		"This card will untap")
	assert_eq(MiniCard.STATE_CUE[MiniCard.State.NOT_OWNED],
		"Card is not controlled by owner")
	assert_eq(MiniCard.STATE_CUE[MiniCard.State.IS_TARGET], "Is a target")
	assert_eq(MiniCard.STATE_CUE[MiniCard.State.CANT_TARGET],
		"Can't target this")
	assert_eq(MiniCard.STATE_CUE[MiniCard.State.TARGET_AGAIN],
		"Is a target, can't target again")


func test_every_state_overlay_wears_its_own_cue_card_as_a_tooltip() -> void:
	var lion := put_battlefield(0, "Savannah Lions")
	var card := _mini(lion)
	for state in MiniCard.State.values():
		if not card._overlays.has(state):
			continue          # NOT_OWNED is lettered, not drawn
		assert_eq((card._overlays[state] as TextureRect).tooltip_text,
			String(MiniCard.STATE_CUE[state]),
			"overlay %d says its own cue card" % state)


func test_a_summoning_sick_creature_wears_the_spiral() -> void:
	var lion := put_battlefield(0, "Savannah Lions", true)
	assert_true(_states(lion).has(MiniCard.State.SUMMONING_SICK))
	assert_true(_card.tooltip_text.contains("Summoning sickness"))


func test_a_hasty_creature_is_never_drawn_as_sick() -> void:
	var bolt := put_battlefield(0, "Ball Lightning", true)      # haste
	assert_false(_states(bolt).has(MiniCard.State.SUMMONING_SICK))


func test_a_dying_creature_wears_the_dying_overlay() -> void:
	# "Dying" = lethal damage marked, i.e. this goes at the next
	# state-based check. Our SBAs run synchronously, so the window it is
	# visible in is the damage-division loop and any deferred check.
	var wall := put_battlefield(0, "Wall of Bone")   # 1/4
	wall.damage = 4
	var states := _states(wall)
	assert_true(states.has(MiniCard.State.DYING))
	assert_true(_card.tooltip_text.contains("Dying"))
	wall.damage = 3
	assert_false(_states(wall).has(MiniCard.State.DYING),
		"three damage on a 1/4 is not lethal")


func test_an_indestructible_creature_with_lethal_damage_is_not_dying() -> void:
	var wall := put_battlefield(0, "Wall of Bone")
	wall.damage = 9
	wall.cur_indestructible = true
	assert_false(_states(wall).has(MiniCard.State.DYING),
		"it is not dying, and saying so would be a lie")


func test_a_stolen_creature_says_it_is_not_controlled_by_its_owner() -> void:
	# A Control Magic'd creature used to look exactly like one of your own.
	var lion := put_battlefield(1, "Savannah Lions")
	assert_false(_states(lion).has(MiniCard.State.NOT_OWNED))
	g.change_control(lion, 0)
	var card := _mini(lion)
	assert_true(card.active_states().has(MiniCard.State.NOT_OWNED))
	assert_true(card.tooltip_text.contains("Card is not controlled by owner"))
	assert_true(card._status_label.text.contains(MiniCard.NOT_OWNED_MARK),
		"the state with no 1997 art is LETTERED, not invented")


func test_a_targeted_permanent_wears_the_target_overlay() -> void:
	var lion := put_battlefield(1, "Savannah Lions")
	assert_false(_states(lion).has(MiniCard.State.IS_TARGET))
	var bolt := StackItem.new()
	bolt.kind = Mtg.StackKind.SPELL
	bolt.controller = 0
	bolt.card = lion
	bolt.targets = [TargetRef.card(lion)]
	g.stack.append(bolt)
	assert_true(_states(lion).has(MiniCard.State.IS_TARGET))
	assert_true(_card.tooltip_text.contains("Is a target"))
	g.stack.clear()


func test_is_a_target_needs_a_game_and_stays_quiet_without_one() -> void:
	# The pile views and the deck builder build MiniCards with no game.
	var lion := put_battlefield(1, "Savannah Lions")
	var bolt := StackItem.new()
	bolt.kind = Mtg.StackKind.SPELL
	bolt.controller = 0
	bolt.card = lion
	bolt.targets = [TargetRef.card(lion)]
	g.stack.append(bolt)
	assert_false(_states(lion, false).has(MiniCard.State.IS_TARGET),
		"no game, no answer — and no crash")
	g.stack.clear()


func test_a_tapped_permanent_says_it_will_untap() -> void:
	var lion := put_battlefield(0, "Savannah Lions")
	assert_false(_states(lion).has(MiniCard.State.WILL_UNTAP),
		"an untapped card is not going to untap")
	lion.tapped = true
	assert_true(_states(lion).has(MiniCard.State.WILL_UNTAP))
	assert_true(_card.tooltip_text.contains("This card will untap"))


func test_a_meekstone_locked_creature_does_not_say_it_will_untap() -> void:
	# The INVERSE of the lock, which is the whole point of the state.
	var giant := put_battlefield(0, "Craw Wurm")       # power 6
	giant.tapped = true
	assert_true(_states(giant).has(MiniCard.State.WILL_UNTAP))
	put_battlefield(1, "Meekstone")
	g.recalculate()
	assert_true(giant.cur_skips_untap, "Meekstone holds a big creature down")
	assert_false(_states(giant).has(MiniCard.State.WILL_UNTAP))


func test_a_one_shot_untap_skip_also_silences_the_mark() -> void:
	var lion := put_battlefield(0, "Savannah Lions")
	lion.tapped = true
	lion.skip_next_untap = true
	assert_false(_states(lion).has(MiniCard.State.WILL_UNTAP))
	lion.skip_next_untap = false
	lion.skip_untaps = 2
	assert_false(_states(lion).has(MiniCard.State.WILL_UNTAP))


func test_a_global_untap_throttle_silences_the_mark_too() -> void:
	# Winter Orb and Smoke cap how many permanents untap at all, so while
	# one is out the small card cannot promise anything.
	var lion := put_battlefield(0, "Savannah Lions")
	lion.tapped = true
	assert_true(_states(lion).has(MiniCard.State.WILL_UNTAP))
	g.untap_caps["land"] = 1
	assert_false(_states(lion).has(MiniCard.State.WILL_UNTAP))
	g.untap_caps.clear()


func test_the_targeting_states_are_pushed_down_by_the_screen() -> void:
	# "Can't target this" and "Is a target, can't target again" are about
	# the PROMPT, not the card, so the duel screen hands them over.
	var lion := put_battlefield(0, "Savannah Lions")
	var card := _mini(lion)
	assert_false(card.active_states().has(MiniCard.State.CANT_TARGET))
	card.set_target_state(MiniCard.State.CANT_TARGET)
	assert_true(card.active_states().has(MiniCard.State.CANT_TARGET))
	assert_true(card.tooltip_text.contains("Can't target this"))
	card.set_target_state(MiniCard.State.TARGET_AGAIN)
	assert_false(card.active_states().has(MiniCard.State.CANT_TARGET))
	assert_true(card.tooltip_text.contains("Is a target, can't target again"))
	card.set_target_state(-1)
	assert_false(card.active_states().has(MiniCard.State.TARGET_AGAIN))


func test_only_one_centre_stamp_is_drawn_at_a_time() -> void:
	# The original stamps ONE mark over a card's art. A card that is both
	# on the stack's target list and refused by the current spec shows the
	# refusal, which is the news.
	var lion := put_battlefield(0, "Savannah Lions")
	var bolt := StackItem.new()
	bolt.kind = Mtg.StackKind.SPELL
	bolt.controller = 0
	bolt.card = lion
	bolt.targets = [TargetRef.card(lion)]
	g.stack.append(bolt)
	var card := _mini(lion)
	card.set_target_state(MiniCard.State.CANT_TARGET)
	var states := card.active_states()
	assert_true(states.has(MiniCard.State.IS_TARGET), "both states are true")
	assert_true(states.has(MiniCard.State.CANT_TARGET))
	var drawn := 0
	for state in MiniCard.CENTRE_STAMPS:
		if (card._overlays[state] as TextureRect).visible:
			drawn += 1
	if GameSkin.is_present():
		assert_eq(drawn, 1, "one stamp on the art, not two")
	g.stack.clear()


func test_a_face_down_card_shows_no_state_at_all() -> void:
	var lion := put_battlefield(0, "Savannah Lions", true)
	lion.damage = 1
	var card := _mini(lion)
	card.face_down = true
	card.refresh()
	assert_eq(card.active_states().size(), 0,
		"a face-down card tells the table nothing about itself")
	for state in card._overlays:
		assert_false((card._overlays[state] as TextureRect).visible,
			"overlay %s is hidden" % state)


func test_flipping_a_card_face_down_hides_its_mana_stripes() -> void:
	# THE BUG THIS PINS: `refresh()`'s face-down branch hid the name, art,
	# P/T, badges and every state overlay — but not `_stripes`. A card
	# built face-down never has stripes (`_rebuild_stripes` runs only on
	# the face-up path), but a widget FLIPPED face-down kept the ones it
	# already had, so a face-down Black Lotus wore all five colour slashes:
	# exactly the information a card back exists to withhold.
	var lotus := put_battlefield(0, "Black Lotus")
	var card := _mini(lotus)
	assert_true(card._stripes.visible, "a Black Lotus wears its slashes")
	assert_gt(card._stripes.get_child_count(), 0)
	card.face_down = true
	card.refresh()
	assert_false(card._stripes.visible, "and a card back wears none")


func test_a_card_flipped_back_face_up_is_clickable_again() -> void:
	# The face-down branch set `disabled = true` and nothing ever set it
	# back, so a widget turned face up again was permanently unclickable —
	# the one piece of face-down state that was applied and not restored.
	#
	# The card is in HAND, which is where a card back the player cannot act
	# on lives; the battlefield case is the test below.
	var lion := give_hand(0, "Savannah Lions")
	var card := _mini(lion)
	card.face_down = true
	assert_true(card.disabled, "a card back in a hand takes no clicks")
	card.face_down = false
	assert_false(card.disabled, "turned face up, it does again")


func test_a_face_down_permanent_is_still_clickable() -> void:
	# **A FACE-DOWN PERMANENT IS STILL A PERMANENT** — it attacks, it
	# blocks, it is a legal target, and every one of those is a click on
	# this widget. `refresh()` disabled every face-down card flatly, which
	# cost nothing while nothing in the shipped game set the flag; the
	# moment `DuelScreen._make_card` began carrying
	# `CardInstance.face_down` (§5.1) a masked Illusionary Mask creature
	# would have become impossible to declare as an attacker.
	var lion := put_battlefield(0, "Savannah Lions")
	var card := _mini(lion)
	card.face_down = true
	assert_false(card.disabled,
		"a masked creature can still be declared, blocked and targeted")
	assert_false(card._name_label.visible, "...and still tells you nothing")


func test_the_flag_refreshes_the_face_by_itself() -> void:
	# `face_down` used to be a bare field, so every caller had to remember
	# a `refresh()` after it — and the builders that now set it
	# (`DuelScreen._make_card`, `CardPile._make_card`,
	# `GraveyardView._card`) set it between other calls that also refresh.
	# It is a setter now, like `castable` and `hovered`.
	var lion := put_battlefield(0, "Savannah Lions")
	var card := _mini(lion)
	assert_true(card._name_label.visible)
	card.face_down = true          # no refresh() of our own
	assert_false(card._name_label.visible, "the setter re-derived the face")
	assert_false(card._art.visible)
	card.face_down = false
	assert_true(card._name_label.visible)


func test_a_card_in_hand_wears_no_battlefield_state() -> void:
	var lion := give_hand(0, "Savannah Lions")
	lion.damage = 3
	lion.tapped = true
	assert_eq(_states(lion).size(), 0)


func test_the_state_art_decodes_from_the_1997_mask() -> void:
	if not GameSkin.is_present():
		pass_test("no 1997 skin imported — the overlays stay hidden")
		return
	for state in MiniCard.STATE_SPRITE:
		var tex := MiniCard.masked_sprite(MiniCard.STATE_SPRITE[state])
		assert_not_null(tex, "state %d decodes" % state)
		if tex == null:
			continue
		assert_gt(tex.get_width(), 0)
		var img := tex.get_image()
		var clear := 0
		for x in img.get_width():
			if img.get_pixel(x, 0).a < 0.5:
				clear += 1
		assert_gt(clear, 0,
			"state %d has real transparency — the mask half was applied" % state)


func test_phased_and_damage_to_player_are_recorded_as_unanswerable() -> void:
	# The two of the original's ten this widget does NOT draw, so that the
	# next pass does not go hunting for them:
	#   * `Damage to player` (Poison.pic) is the LIFE REGISTER's state.
	#   * `Phased` cannot reach a widget — MtgGame.phase_out takes the
	#     instance out of players[pid].battlefield and there is no
	#     Mtg.Zone.PHASED_OUT, so the board never builds a card for one.
	assert_false(MiniCard.STATE_CUE.values().has("Damage to player"))
	assert_false(MiniCard.STATE_CUE.values().has("Phased"))
	assert_false("PHASED_OUT" in Mtg.Zone.keys(),
		"if this ever fails, `Phased` has become answerable")


# ====================================== the P/T, and how big it letters ==
#
# The owner, 2026-09-03: *"The power and defense numbers on mini cards
# should be a bit more prominent (mini card builder) — like original."*
# The measurement behind the answer is s30's, ported as a RATIO rather
# than as a number: its battlefield card is 100x83 and it letters the
# pair at 20 (`duel.go:1360-1364`), right-padded 3 and standing 2 clear
# of the bottom edge. Everything below is that ratio, the corner it lives
# in, and the things it must not walk over.

func test_the_power_and_toughness_letters_at_the_1997_share_of_the_card() -> void:
	var lion := put_battlefield(0, "Savannah Lions")
	var card := _mini(lion)
	assert_eq(card._pt_label.get_theme_font_size("font_size"),
		MiniCard.PT_FONT_SIZE, "the pair letters at the card's own size")
	# s30's 20 on an 83-tall card is 0.241 of its height. Ours may not be
	# meaner than that — this is the whole of the owner's complaint.
	assert_gte(float(MiniCard.PT_FONT_SIZE) / MiniCard.SIZE.y, 0.22,
		"at least s30's share of the card's height (20/83)")
	assert_gt(MiniCard.PT_FONT_SIZE, MiniCard.NAME_FONT_SIZE,
		"and plainly bigger than the name it shares the card with")


func test_the_power_and_toughness_wears_a_hard_dark_outline() -> void:
	# OUTLINE, not shadow, and for the reason the zone column found on the
	# pile counts (2026-09-03): the numbers sit on whatever art the card
	# happens to carry, and a 1px shadow disappears on a pale one.
	var lion := put_battlefield(0, "Savannah Lions")
	var card := _mini(lion)
	assert_eq(card._pt_label.get_theme_constant("outline_size"),
		MiniCard.PT_OUTLINE_SIZE, "a real outline, sized in one place")
	assert_gt(MiniCard.PT_OUTLINE_SIZE, 0)
	var ink: Color = card._pt_label.get_theme_color("font_outline_color")
	assert_almost_eq(ink.r, 0.0, 0.01, "black")
	assert_almost_eq(ink.g, 0.0, 0.01)
	assert_almost_eq(ink.b, 0.0, 0.01)
	assert_almost_eq(ink.a, 1.0, 0.01, "and opaque — a hard floor")


func test_the_power_and_toughness_keeps_the_bottom_right_corner() -> void:
	# The owner's photograph of a tapped Avenging Ghoul: 6/4 large, white,
	# in the card's bottom-right corner. The eighth pass measured the same
	# thing off the table-card reference.
	var lion := put_battlefield(0, "Savannah Lions")
	var card := _mini(lion)
	var pt := card._pt_label
	assert_eq(pt.anchor_right, 1.0, "anchored to the card's right edge")
	assert_eq(pt.anchor_bottom, 1.0, "and to its bottom")
	assert_eq(pt.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT)
	assert_eq(pt.vertical_alignment, VERTICAL_ALIGNMENT_BOTTOM)
	assert_lt(pt.offset_right, 0.0, "inset from the right edge")
	assert_lt(pt.offset_bottom, 0.0, "and standing clear of the bottom one")
	assert_gte(pt.offset_left, -MiniCard.SIZE.x,
		"and never wider than the card it is on")


func test_the_big_numbers_clear_the_damage_marker_and_the_badges() -> void:
	# Three things share the card's bottom edge and the order is decided,
	# not accidental: the damage dagger and its count sit ABOVE the pair,
	# the keyword badges keep the bottom-LEFT and are clipped at the
	# numbers' edge, and the numbers themselves own the corner.
	var lion := put_battlefield(0, "Savannah Lions")
	var card := _mini(lion)
	assert_lte(card._damage_icon.offset_bottom, card._pt_label.offset_top,
		"the dagger sits above the pair, never across it")
	assert_lte(card._damage_count.offset_bottom, card._pt_label.offset_top,
		"and so does its number")
	assert_true(card._badges.clip_contents,
		"the badge row is clipped rather than allowed into the corner")
	assert_lte(card._badges.offset_right, card._pt_label.offset_left,
		"and it stops before the numbers begin")


func test_the_numbers_stay_over_the_dying_cracks() -> void:
	# Both of 2026-09-03's changes land on the same corner. The pair is
	# z 1 and the state overlays are z 0, so a destroyed creature's cracks
	# pass UNDER its numbers rather than through them.
	var lion := put_battlefield(0, "Savannah Lions")
	var card := _mini(lion)
	card.force_dying = true
	card.refresh()
	assert_eq(card._pt_label.z_index, 1)
	var cracks: TextureRect = card._overlays.get(MiniCard.State.DYING)
	assert_not_null(cracks, "the cracks were built")
	assert_lt(cracks.z_index, card._pt_label.z_index,
		"and they pass under the numbers")


func test_the_badge_row_still_holds_every_badge_the_pool_can_print() -> void:
	# The clip is a GUARD, not a routine cost. Sweeping every CardData in
	# the pool (897 cards, printed keywords plus one activation-cost badge)
	# the worst case is THREE — Nalathni Dragon, flying + banding + its
	# {R} ability, and it is the only card that reaches three; thirty reach
	# two and the other 866 wear one or none. The row is 3 badges wide, so
	# nothing the pool PRINTS is ever clipped. What can pass three is a
	# RUNTIME grant (Zombie Master handing out regeneration, an Artifact
	# Ward adding its shield), which is exactly the case the clip is for.
	var row := MiniCard.SIZE.x - MiniCard.PT_BOX.x - MiniCard.PT_INSET.x - 4
	assert_gte(row, 3.0 * MiniCard.BADGE + 2.0,
		"three badges and their separations still fit beside the numbers")
	var dragon := put_battlefield(0, "Nalathni Dragon")
	if dragon != null:
		var card := _mini(dragon)
		assert_eq(card._badges.get_child_count(), 3,
			"the pool's worst case draws all three")
		assert_lte(card._badges.get_minimum_size().x, row,
			"and the row it needs fits in the space the numbers leave it")


func test_a_non_creature_permanent_grows_no_numbers() -> void:
	var forest := put_battlefield(0, "Forest")
	assert_eq(_mini(forest)._pt_label.text, "", "a land letters no pair")
	var vise := put_battlefield(0, "Black Vise")
	assert_eq(_mini(vise)._pt_label.text, "",
		"and neither does a non-creature artifact")


func test_a_pumped_pair_is_still_the_live_one_in_the_bigger_type() -> void:
	# Growing the type must not disturb what it says or what colour it
	# says it in (s30's three-way colouring, duel.go:3402-3416).
	var lion := put_battlefield(0, "Savannah Lions")     # 2/1
	put_battlefield(0, "Crusade")
	g.recalculate()
	var card := _mini(lion)
	assert_eq(card._pt_label.text, "3/2")
	assert_eq(card.pt_color(), Color8(100, 255, 100), "pumped letters green")


# ================================================ §2.11 — the badges ==

func test_a_regenerating_permanent_badges_slot_15() -> void:
	# There is no Mtg.Keyword.REGENERATION: regeneration in this pool is an
	# activated ability whose effect is a RegenerateEffect shield builder.
	var skeletons := put_battlefield(0, "Drudge Skeletons")
	assert_true(_mini(skeletons).regenerates_itself())
	assert_true(_badge_slots(_card).has(MiniCard.REGENERATION_SLOT))


func test_a_creature_that_regenerates_something_else_is_not_badged() -> void:
	# Elephant Graveyard and Ragnar regenerate OTHER creatures; the badge
	# is a statement about THIS card.
	var yard := put_battlefield(0, "Elephant Graveyard")
	assert_false(_mini(yard).regenerates_itself())
	assert_false(_badge_slots(_card).has(MiniCard.REGENERATION_SLOT))


func test_regeneration_granted_at_runtime_is_badged_too() -> void:
	# Zombie Master hands regeneration to every Zombie; the predicate reads
	# cur_activated_abilities, so it sees the gift.
	var zombies := put_battlefield(0, "Scathe Zombies")
	assert_false(_mini(zombies).regenerates_itself())
	put_battlefield(0, "Zombie Master")
	g.recalculate()
	assert_true(_mini(zombies).regenerates_itself())


func test_protection_from_artifacts_badges_slot_10() -> void:
	# `cur_protection` is a COLOUR bitmask with no room for artifacts, so
	# Artifact Ward expresses protection as its three clauses. We ask for
	# the two that define it.
	var bears := put_battlefield(0, "Grizzly Bears")
	assert_false(_mini(bears).warded_from_artifacts())
	var ward := _make_instance(0, "Artifact Ward")
	g.attach_aura_from_anywhere(ward, bears, 0)
	assert_true(_mini(bears).warded_from_artifacts())
	assert_true(_badge_slots(_card).has(MiniCard.ARTIFACT_PROTECTION_SLOT))


func test_colour_protection_still_badges_its_own_shield() -> void:
	var knight := put_battlefield(0, "White Knight")   # pro black
	assert_true(_badge_slots(_mini(knight)).has(
		MiniCard.PROTECTION_SLOT[Mtg.ManaColor.B]))


func test_menace_is_not_badged() -> void:
	# SLOT 17 OF THE 1997 SHEET IS BLANK — 484/484 px of (0,0,0,255), one
	# unique colour, on the s30 conversion and on our import alike. s30
	# maps Menace there (duel.go:1047-1121); the 1997 game had no menace
	# keyword and no icon, so that mapping blits a black square.
	# duel-todo.md §3.4: no card in this pool needs menace.
	assert_false(MiniCard.BADGE_SLOT.values().has(17),
		"nothing is ever drawn from cell 17")
	assert_false(MiniCard.PROTECTION_SLOT.values().has(17))
	assert_ne(MiniCard.REGENERATION_SLOT, 17)
	assert_ne(MiniCard.ARTIFACT_PROTECTION_SLOT, 17)
	assert_false("MENACE" in Mtg.Keyword.keys(),
		"and the engine has no menace keyword either")


func test_badges_are_deduped_by_slot() -> void:
	# s30's own case (duel_ability_icons_test.go:35-52): flying twice plus
	# trample plus first strike is THREE icons, not four.
	var lion := put_battlefield(0, "Savannah Lions")
	lion.cur_keywords = [Mtg.Keyword.FLYING, Mtg.Keyword.FLYING,
		Mtg.Keyword.TRAMPLE, Mtg.Keyword.FIRST_STRIKE]
	assert_eq(_badge_slots(_mini(lion)).size(), 3)


func test_badges_only_show_in_play() -> void:
	var lion := give_hand(0, "Savannah Lions")
	lion.cur_keywords = [Mtg.Keyword.FLYING]
	assert_eq(_badge_slots(_mini(lion)).size(), 0,
		"the original badges the table, not your hand")


func test_a_badge_has_no_opaque_backdrop() -> void:
	# THE KEYING PIN. The 1997 sheet stores every icon as a disc on an
	# opaque near-black square; a bare AtlasTexture drew a dark 22px block
	# behind every badge. Measured: across all 18 cells the furthest
	# non-black pixel sits at r=11.068 and the nearest black one at
	# r=11.34, so the cut at cell*0.51 removes the corners and nothing else.
	if not GameSkin.is_present():
		pass_test("no 1997 skin imported")
		return
	for slot in [11, 12, 13, 14, MiniCard.REGENERATION_SLOT, 16,
			MiniCard.ARTIFACT_PROTECTION_SLOT]:
		var tex := MiniCard.badge_from_slot(slot)
		assert_not_null(tex, "slot %d resolves" % slot)
		if tex == null:
			continue
		var img := tex.get_image()
		var w := img.get_width()
		for corner in [Vector2i(0, 0), Vector2i(w - 1, 0),
				Vector2i(0, w - 1), Vector2i(w - 1, w - 1)]:
			assert_eq(img.get_pixel(corner.x, corner.y).a, 0.0,
				"slot %d corner %s is transparent" % [slot, corner])
		assert_gt(img.get_pixel(w / 2, w / 2).a, 0.5,
			"slot %d keeps its disc" % slot)


func test_the_badge_cells_are_still_square_and_in_one_column() -> void:
	# A re-import that changed the sheet's shape would silently shift every
	# icon; this is the cheapest guard against it.
	if not GameSkin.is_present():
		pass_test("no 1997 skin imported")
		return
	var sheet := GameSkin.texture("ability_icons")
	assert_not_null(sheet)
	assert_eq(sheet.get_height() % sheet.get_width(), 0,
		"whole cells, one column wide")
	assert_eq(sheet.get_height() / sheet.get_width(), 18, "18 cells")


# ================================================ the border vocabulary ==

func test_the_highlight_colours_follow_the_manuals_code() -> void:
	# Manual p.128: "Mandatory effects are highlighted in ORANGE, while
	# optional effects are in YELLOW."
	var optional: Color = MiniCard.HIGHLIGHT_COLORS[MiniCard.Highlight.OPTIONAL]
	var mandatory: Color = MiniCard.HIGHLIGHT_COLORS[MiniCard.Highlight.MANDATORY]
	var committed: Color = MiniCard.HIGHLIGHT_COLORS[MiniCard.Highlight.COMMITTED]
	assert_gt(optional.g, mandatory.g, "orange is redder than yellow")
	assert_gt(committed.g, committed.r, "committed is green")


func test_a_chosen_target_draws_a_thicker_border() -> void:
	# s30's one width distinction (duel.go:3302-3377, block 5).
	assert_eq(MiniCard.HIGHLIGHT_WIDTH[MiniCard.Highlight.TARGET_CHOSEN], 3)
	assert_eq(MiniCard.HIGHLIGHT_WIDTH[MiniCard.Highlight.TARGET_LEGAL], 2)
	assert_eq(MiniCard.HIGHLIGHT_WIDTH[MiniCard.Highlight.NONE], 1)


# ---- §5.2: the width has to survive a TEXTURED frame ----
#
# The highlight is a COLOUR and a WIDTH. The unskinned frame is a
# `StyleBoxFlat` and carries both. The skinned frame is a
# `StyleBoxTexture` — and a `StyleBoxTexture` HAS NO BORDER WIDTH, so
# `_boxes_for` could only apply the colour, as `modulate_color`. With the
# 1997 art imported the two green states therefore rendered
# BYTE-IDENTICALLY: the catalogue's `22_highlight_committed.png` and
# `24_highlight_target_chosen.png` came out the same file, and s30's one
# width distinction (`duel.go:3302-3377`, block 5) was invisible to every
# player who had imported the original graphics.

func _ring_width(card: MiniCard) -> int:
	if card._highlight_ring == null or not card._highlight_ring.visible:
		return 0
	var box := card._highlight_ring.get_theme_stylebox("panel")
	return (box as StyleBoxFlat).border_width_top


func test_the_skinned_frame_carries_the_highlight_width() -> void:
	var lion := put_battlefield(0, "Savannah Lions")
	var card := _mini(lion)
	if GameSkin.texture(card._frame_skin_key()) == null:
		pass_test("no 1997 skin imported — the flat frame draws its own widths")
		return
	for mode in [MiniCard.Highlight.OPTIONAL, MiniCard.Highlight.MANDATORY,
			MiniCard.Highlight.COMMITTED, MiniCard.Highlight.TARGET_LEGAL,
			MiniCard.Highlight.TARGET_CHOSEN]:
		card.set_highlight(mode)
		assert_eq(_ring_width(card), int(MiniCard.HIGHLIGHT_WIDTH[mode]),
			"highlight %d draws at its own width over the 1997 frame" % mode)


func test_a_chosen_target_outdraws_a_committed_one_on_the_1997_frame() -> void:
	# THE DEFECT ITSELF, at the pair that proved it. Same hue, different
	# width — and the width was the whole of the difference.
	var lion := put_battlefield(0, "Savannah Lions")
	var card := _mini(lion)
	if GameSkin.texture(card._frame_skin_key()) == null:
		pass_test("no 1997 skin imported")
		return
	card.set_highlight(MiniCard.Highlight.COMMITTED)
	var committed := _ring_width(card)
	card.set_highlight(MiniCard.Highlight.TARGET_CHOSEN)
	var chosen := _ring_width(card)
	assert_gt(chosen, committed,
		"a chosen target draws thicker than a committed one, skin or no skin")
	assert_eq(card._highlight_ring.get_theme_stylebox("panel").border_color,
		MiniCard.HIGHLIGHT_COLORS[MiniCard.Highlight.TARGET_CHOSEN],
		"and in the state's own colour")


func test_a_resting_card_grows_no_ring_at_all() -> void:
	# "Keep the resting card exactly as it is now": `Highlight.NONE` is
	# nearly every card nearly all of the time, and it must cost no node,
	# no draw and no theme propagation.
	var lion := put_battlefield(0, "Savannah Lions")
	var card := _mini(lion)
	assert_null(card._highlight_ring, "no highlight, no ring node")
	card.set_highlight(MiniCard.Highlight.TARGET_CHOSEN)
	card.set_highlight(MiniCard.Highlight.NONE)
	assert_eq(_ring_width(card), 0, "and it comes back down again")


func test_the_ring_never_eats_a_click() -> void:
	# A `Panel` is a `Control` and a `Control` defaults to STOP. A ring
	# across the whole card at STOP would swallow the press that taps the
	# land under it — four defects this week came from exactly that.
	var lion := put_battlefield(0, "Savannah Lions")
	var card := _mini(lion)
	card.set_highlight(MiniCard.Highlight.TARGET_LEGAL)
	if card._highlight_ring == null:
		pass_test("no 1997 skin imported — no ring to test")
		return
	assert_eq(card._highlight_ring.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_only_the_textured_frame_gets_a_ring() -> void:
	# The flat frame already draws `HIGHLIGHT_WIDTH` in its own border, and
	# doubling it would move the unskinned look `37`/`38`/`39` pin.
	var lion := put_battlefield(0, "Savannah Lions")
	var card := _mini(lion)
	card.set_highlight(MiniCard.Highlight.TARGET_CHOSEN)
	card._refresh_highlight_ring(false)      # as an unskinned frame asks
	assert_eq(_ring_width(card), 0, "the flat frame keeps its own border")


func test_a_face_down_card_still_shows_the_prompts_ring() -> void:
	# The ring is a question about the PROMPT — "this is a legal target" —
	# not about the card, so a masked creature wears one and says nothing
	# about itself by doing so. It is also the ordering pin: the duel
	# screen sets `face_down` and THEN pushes the highlight down.
	var lion := put_battlefield(0, "Savannah Lions")
	var card := _mini(lion)
	card.face_down = true
	card.set_highlight(MiniCard.Highlight.TARGET_LEGAL)
	assert_false(card._name_label.visible,
		"the highlight did not re-derive the face-up frame over the back")
	if GameSkin.texture("card_back") != null:
		assert_eq(_ring_width(card),
			int(MiniCard.HIGHLIGHT_WIDTH[MiniCard.Highlight.TARGET_LEGAL]))


# ---- §5.6: the art is always MINIFIED, so it needs a mipmap chain ----

func test_the_small_cards_art_is_mipmapped() -> void:
	# A ~582x467 Scryfall crop drawn in a ~110px window is better than a
	# 5:1 minification, and a plain LINEAR filter samples one source pixel
	# per screen pixel at that ratio — a regular diamond lattice over fur,
	# chainmail and foliage (`docs/card-states.md` §5.6). Two halves, and
	# BOTH are needed: the chain has to exist, and the small card has to
	# ask for it. Everything else that draws the same texture — the
	# Showcase above all — still draws mip 0.
	var art := GameSkin.card_art("Savannah Lions")
	if art == null:
		pass_test("no card art in this checkout")
		return
	assert_true(art.get_image().has_mipmaps(),
		"GameSkin.card_art builds the chain")
	var card := _mini(put_battlefield(0, "Savannah Lions"))
	assert_eq(card._art.texture_filter,
		CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
		"and the small card's art rect asks for it")


# ---- §5.4: which of the two rules letters the title bar ----

func test_the_name_follows_the_castable_rule_on_any_bar() -> void:
	# `_tint_face`'s comment claimed *"the name reads DARK on a light bar
	# (white/tan cards) and GOLD on a dark one"* — a contrast rule the code
	# has never applied to the NAME. The name is `name_color()`
	# unconditionally, and that is right: the yellow/white pair is
	# INFORMATION (can you cast this?), and a name that went dark on a
	# marble bar would be saying "not castable" in the one place a player
	# reads castability. Its 3px shadow outline is what keeps it legible.
	var pale := _mini(put_battlefield(0, "Savannah Lions"))
	var dark := _mini(put_battlefield(0, "Drudge Skeletons"))
	assert_gt(MiniCard.frame_color(pale.instance.data).get_luminance(), 0.52,
		"a white card's title bar is light")
	assert_lt(MiniCard.frame_color(dark.instance.data).get_luminance(), 0.52,
		"a black card's is dark")
	for card in [pale, dark]:
		assert_eq(card._name_label.get_theme_color("font_color"),
			card.name_color(), "the bar does not letter the name")
		card.castable = true
		assert_eq(card._name_label.get_theme_color("font_color"),
			Color(1.0, 0.90, 0.30), "castable is yellow on either bar")
	# The contrast rule is real — it just belongs to the STATUS line.
	assert_ne(pale._status_label.get_theme_color("font_color"),
		pale._name_label.get_theme_color("font_color"),
		"the status line takes the bar's ink, the name does not")


func test_the_file_says_so_in_its_own_words() -> void:
	# The comment and the code disagreed for two passes and nothing could
	# catch it, because a comment is not executable. This is the cheapest
	# thing that can: `docs/card-states.md` §5.4 named the sentence, so
	# the sentence is what gets pinned.
	var src := FileAccess.get_file_as_string("res://game/duel/mini_card.gd")
	assert_gt(src.length(), 0, "the file reads")
	assert_false(src.contains("the name reads DARK on a light bar"),
		"the comment no longer claims a contrast rule for the NAME")


func test_the_old_highlight_names_still_resolve() -> void:
	# Kept as aliases for one pass so in-flight callers keep compiling.
	assert_eq(MiniCard.Highlight.CASTABLE, MiniCard.Highlight.OPTIONAL)
	assert_eq(MiniCard.Highlight.TARGET, MiniCard.Highlight.TARGET_LEGAL)
	assert_eq(MiniCard.Highlight.SELECTED, MiniCard.Highlight.COMMITTED)


# ==================================================== §2.9 — THE TAP TURN ==
#
# `Duel.hlp`, topic **Tapping**: *"Tapping a card means turning it
# sideways."* The 90° is 1997's; the TWEEN through it is `[QoL]` (a 1997
# sprite blit has no in-between), and what these pin is that the animation
# can never leave the card anywhere except flat or square.


## A card set up exactly as the board sets one up: inside its turn holder,
## pivoting on its own centre. [param animated] is the seam a headless run
## turns off — see [member MiniCard.animate_turn].
func _turning(inst: CardInstance, animated := false) -> MiniCard:
	var card := MiniCard.new(inst)
	card.animate_turn = animated
	add_child_autofree(MiniCard.turn_holder(card))
	return card


func test_a_tapped_card_is_square_before_a_single_frame_is_drawn() -> void:
	# THE HEADLESS PIN. Tests and the soak draw nothing, and a tween that
	# never advances would leave the angle wherever the first frame's delta
	# happened to land — measured on the live screen 2026-09-03 as 0°,
	# 79.9° and 87.5° on three consecutive readings of the same board. With
	# no frames the FINAL angle is the true one, and it is applied at once.
	MiniCard._turn_book.clear()
	var giant := put_battlefield(0, "Hill Giant")
	giant.tapped = true
	var card := _turning(giant)
	assert_eq(card.rotation_degrees, 90.0,
		"the turn is complete the moment the card is on screen")


func test_the_turn_goes_to_the_right() -> void:
	# Clockwise: `rotation_degrees` is positive-clockwise in Godot's y-down
	# screen space, so the card's name band swings to the card's right.
	MiniCard._turn_book.clear()
	var giant := put_battlefield(0, "Hill Giant")
	giant.tapped = true
	assert_gt(_turning(giant).rotation_degrees, 0.0, "to the right, not the left")
	assert_eq(MiniCard.TAP_TURN_DEGREES, 90.0, "a right angle, and no more")


func test_an_untapped_card_is_left_flat() -> void:
	MiniCard._turn_book.clear()
	var giant := put_battlefield(0, "Hill Giant")
	assert_eq(_turning(giant).rotation_degrees, 0.0)


func test_a_card_that_is_not_the_one_turning_is_left_flat() -> void:
	# A [CardPile] row is CLIPPED to a title bar and a [DeathMark] ghost is
	# a stamp, so neither gives its card a centre pivot — and a card turning
	# inside either would be sliced. The pivot IS the contract.
	MiniCard._turn_book.clear()
	var giant := put_battlefield(0, "Hill Giant")
	giant.tapped = true
	var card := MiniCard.new(giant)
	card.animate_turn = false
	add_child_autofree(card)
	assert_true(card.wants_rotation(), "the card knows it is tapped")
	assert_eq(card.rotation_degrees, 0.0,
		"but nothing gave it a centre to turn about, so it does not turn")


func test_the_holder_reserves_the_footprint_the_turn_sweeps_out() -> void:
	MiniCard._turn_book.clear()
	var giant := put_battlefield(0, "Hill Giant")
	giant.tapped = true
	var card := MiniCard.new(giant)
	var holder := MiniCard.turn_holder(card)
	add_child_autofree(holder)
	assert_eq(holder.custom_minimum_size,
		Vector2(MiniCard.SIZE.y + 8.0, MiniCard.SIZE.x + 8.0),
		"the swapped axes, plus 4px of slack all round")
	assert_eq(card.size, MiniCard.SIZE, "a tapped card is turned, never resized")
	assert_eq(card.pivot_offset, MiniCard.SIZE / 2.0, "it turns about its middle")
	assert_eq(card.position, (holder.custom_minimum_size - MiniCard.SIZE) / 2.0,
		"and it is centred in the box the turn sweeps out")
	assert_eq(holder.size_flags_vertical, Control.SIZE_SHRINK_CENTER,
		"the holder shrinks, or a taller row slides the turning card off it")


func test_the_turn_is_a_monotone_ease_out() -> void:
	# PURE arithmetic, which is what makes a resumed turn testable without a
	# frame. Monotone matters more than the look: a rebuild lands in the
	# middle of the turn and picks it up from the angle it reads here, and
	# an overshoot resumed from inside its own overshoot wobbles.
	assert_eq(MiniCard.turn_angle(0.0), 0.0, "it starts flat")
	assert_eq(MiniCard.turn_angle(MiniCard.TAP_TURN_SECONDS), 90.0)
	assert_eq(MiniCard.turn_angle(9.0), 90.0, "and never goes past square")
	var last := -1.0
	for step in 21:
		var at := MiniCard.turn_angle(MiniCard.TAP_TURN_SECONDS * step / 20.0)
		assert_gt(at, last, "the turn never goes backwards at step %d" % step)
		assert_true(at <= 90.0, "and never overshoots at step %d" % step)
		last = at
	assert_gt(MiniCard.turn_angle(MiniCard.TAP_TURN_SECONDS / 3.0), 45.0,
		"EASE_OUT: over half the travel is done in the first third, so the "
		+ "card leaves its resting angle the instant it is clicked")


func test_a_rebuilt_widget_resumes_the_turn_rather_than_restarting_it() -> void:
	# THE BOARD IS IMMEDIATE-MODE. Tapping a land for mana fires several
	# refreshes inside the 0.22s, each of which frees the turning card and
	# builds another. The replacement must arrive at the angle its
	# predecessor had reached.
	MiniCard._turn_book.clear()
	var giant := put_battlefield(0, "Hill Giant")
	giant.tapped = true
	MiniCard._turn_book[giant.get_instance_id()] = \
		Time.get_ticks_msec() - int(MiniCard.TAP_TURN_SECONDS * 1000.0 / 2.0)
	var card := _turning(giant, true)
	assert_almost_eq(card.rotation_degrees,
		MiniCard.turn_angle(MiniCard.TAP_TURN_SECONDS / 2.0), 4.0,
		"the new widget starts where the old one had got to")
	assert_not_null(card._turn, "and carries the rest of the turn itself")
	assert_true(card._turn.is_valid())


func test_a_card_tapped_long_ago_arrives_already_turned() -> void:
	# The other half of the same rule, and the one that stops the table
	# SPINNING: a widget rebuilt for a card that has been tapped since
	# before it existed animates nothing at all.
	MiniCard._turn_book.clear()
	var giant := put_battlefield(0, "Hill Giant")
	giant.tapped = true
	MiniCard._turn_book[giant.get_instance_id()] = Time.get_ticks_msec() - 5000
	var card := _turning(giant, true)
	assert_eq(card.rotation_degrees, 90.0, "it is simply square")
	assert_null(card._turn, "and nothing is animating")


func test_the_turn_retargets_instead_of_stacking() -> void:
	# INTERRUPTIBLE. Two tweens on one angle is how a card ends up at 47°:
	# a second turn kills the first rather than joining it.
	MiniCard._turn_book.clear()
	var giant := put_battlefield(0, "Hill Giant")
	giant.tapped = true
	var card := _turning(giant, true)
	var first := card._turn
	assert_not_null(first, "the first turn is running")
	card.tap_turn()
	assert_false(first.is_valid(), "the first turn was killed, not left running")
	assert_true(card._turn != first and card._turn.is_valid(),
		"exactly one turn is live")


func test_untapping_forgets_the_turn_so_the_next_tap_animates_again() -> void:
	MiniCard._turn_book.clear()
	var giant := put_battlefield(0, "Hill Giant")
	giant.tapped = true
	_turning(giant, true)
	assert_true(MiniCard._turn_book.has(giant.get_instance_id()),
		"the tap was recorded")
	giant.tapped = false
	_turning(giant, true)
	assert_false(MiniCard._turn_book.has(giant.get_instance_id()),
		"and untapping forgets it")


func test_a_card_that_left_the_table_while_tapped_forgets_its_turn() -> void:
	# The guard is `wants_rotation`, never `zone == BATTLEFIELD`: a creature
	# bounced to hand while tapped and recast used to arrive at 90° with no
	# turn at all, because nothing had forgotten the first tap.
	MiniCard._turn_book.clear()
	var giant := put_battlefield(0, "Hill Giant")
	giant.tapped = true
	_turning(giant, true)
	g.return_to_hand(giant)
	_turning(giant, true)
	assert_false(MiniCard._turn_book.has(giant.get_instance_id()),
		"a card off the table has no turn in progress")


func test_the_turn_book_sweeps_cards_that_are_gone() -> void:
	# It is static and outlives a duel, so a dead entry is dead weight —
	# and a later card landing on a recycled object id would arrive already
	# turned. It holds INTS ONLY: CONTRIBUTING.md forbids a static holding a
	# CardInstance, and this is keyed by one rather than holding one.
	MiniCard._turn_book.clear()
	for _spare in 40:
		# A REAL object id, and gone by the next line: a `RefCounted` with
		# no reference left to it is freed at once. Fabricated ids would
		# not do — an id outside the object table is an engine error, not
		# an invalid instance.
		var ghost := RefCounted.new()
		MiniCard._turn_book[ghost.get_instance_id()] = Time.get_ticks_msec()
	var giant := put_battlefield(0, "Hill Giant")
	giant.tapped = true
	_turning(giant)
	assert_eq(MiniCard._turn_book.size(), 1,
		"the sweep left only the card that is actually turning")
	assert_true(MiniCard._turn_book.has(giant.get_instance_id()))


# ===================== §2.9b — THE FLAT TAP CUE, where a card cannot turn ==
#
# A [CardPile] row is [constant CardPile.OVERLAP] — 17px — of CLIPPED title
# bar, and lands, artifacts and enchantments are IN a pile the moment there
# are two of them. The 90° turn above cannot show inside a strip that thin,
# so the cards the player taps most had NO tap cue at all: the lettered
# mark sat at `offset_top = 21` on a row clipped at 17, i.e. off the bottom
# of every covered card, and what was left was a quarter-stop of dimming.
# That is the owner's *"Mini cards do not tap visually now?"* (2026-09-03).
#
# The sources do not settle what 1997 drew here — `Duel.hlp` topic **Tap**
# knows only the turn, `@CUECARD_SMALLCARD` (`UIStrings.txt:732`) lists ten
# card states and TAPPED IS NOT ONE OF THEM, and the 1996-97 art ships no
# tap glyph (it ships `Willuntap.pic`, which is the contrast that proves
# the point). So the cue below is `[QoL]`, and it is pinned here.


## A card drawn with NO centre pivot — which is exactly what a pile row is,
## and what every flat placement is. See [method MiniCard.turn_holder] for
## the other half.
func _flat(inst: CardInstance) -> MiniCard:
	var card := MiniCard.new(inst)
	card.animate_turn = false
	add_child_autofree(card)
	return card


func _rows(pile: CardPile) -> Array[MiniCard]:
	var out: Array[MiniCard] = []
	for holder in pile.get_children():
		for face in holder.get_children():
			if face is MiniCard:
				out.append(face)
	return out


func test_a_tapped_card_that_cannot_turn_says_so_in_letters() -> void:
	MiniCard._turn_book.clear()
	var land := put_battlefield(0, "Mountain")
	land.tapped = true
	var card := _flat(land)
	assert_true(card.shows_tap_mark(), "nothing turns it, so it letters it")
	assert_true(card._tap_mark.visible, "the mark is up")
	assert_eq(card._tap_mark.text, MiniCard.TAPPED_MARK)
	assert_true(card._tap_wash.visible, "and the title bar goes dark")


func test_the_whole_cue_fits_the_strip_a_covered_row_shows() -> void:
	# THE DEFECT, in three assertions. A covered row shows the card's top
	# `CardPile.OVERLAP` pixels and nothing else, so a cue below that line
	# is a cue nobody sees.
	MiniCard._turn_book.clear()
	var land := put_battlefield(0, "Mountain")
	land.tapped = true
	var card := _flat(land)
	assert_lt(card._tap_wash.offset_top, CardPile.OVERLAP,
		"the wash is inside the visible strip")
	assert_eq(card._tap_mark.offset_top, card._name_label.offset_top,
		"and the letters ride the title bar, exactly where the NAME does")
	assert_gt(card._status_label.offset_top, CardPile.OVERLAP,
		"which the status line is not — that is where the mark used to sit")


func test_a_card_in_a_pile_wears_the_mark_covered_or_not() -> void:
	MiniCard._turn_book.clear()
	var loose := put_battlefield(0, "Forest")
	var tapped := put_battlefield(0, "Mountain")
	tapped.tapped = true
	var front := put_battlefield(0, "Island")
	front.tapped = true
	var pile := CardPile.new()
	add_child_autofree(pile)
	pile.populate([loose, tapped, front], false, func(_i): pass,
		func(_i): return MiniCard.Highlight.NONE)
	var rows := _rows(pile)
	assert_eq(rows.size(), 3, "one face per card")
	assert_false(rows[0]._tap_mark.visible, "the untapped row is unmarked")
	assert_true(rows[1]._tap_mark.visible, "the COVERED tapped row is marked")
	assert_true(rows[2]._tap_mark.visible,
		"and so is the pile's front card, which cannot turn either")


func test_a_turning_card_wears_the_LETTERS_AND_THE_WASH_AS_WELL() -> void:
	# THE OWNER'S RULING, 2026-09-04: *"Cards should tap even in the stack —
	# and show tapped symbol along with being darker."* All three cues at
	# once, on every tapped permanent. The exclusion this replaces
	# (`wants_rotation() and not turns_when_tapped()`) only ever existed
	# because a clipped pile row could not turn; it can now.
	MiniCard._turn_book.clear()
	var giant := put_battlefield(0, "Hill Giant")
	giant.tapped = true
	var card := _turning(giant)
	assert_eq(card.rotation_degrees, 90.0, "this one turns...")
	assert_true(card.shows_tap_mark())
	assert_true(card._tap_mark.visible, "...and letters it as well")
	assert_true(card._tap_wash.visible, "...and its title bar goes dark")


func test_the_cue_no_longer_asks_whether_the_card_turns() -> void:
	# The pivot decided the cue until 2026-09-04, which made the answer
	# depend on WHO BUILT THE CARD and change between the constructor and
	# `_ready`. It is the card's own state now and nothing else.
	MiniCard._turn_book.clear()
	var land := put_battlefield(0, "Mountain")
	land.tapped = true
	var flat := _flat(land)
	var turning := _turning(put_battlefield(0, "Forest"))
	turning.instance.tapped = true
	turning.refresh()
	assert_eq(flat.shows_tap_mark(), turning.shows_tap_mark(),
		"same state, same cue, whoever is holding the card")
	assert_true(flat.shows_tap_mark())


func test_the_letters_are_never_on_the_card_twice() -> void:
	MiniCard._turn_book.clear()
	var land := put_battlefield(0, "Mountain")
	land.tapped = true
	var flat := _flat(land)
	assert_false(flat._status_label.text.contains(MiniCard.TAPPED_MARK),
		"the mark MOVED to the title bar; it did not get a twin")
	var giant := put_battlefield(0, "Hill Giant")
	giant.tapped = true
	assert_false(_turning(giant)._status_label.text.contains(MiniCard.TAPPED_MARK),
		"and a turning card carries it in the title bar too, not twice")


func test_the_status_line_never_carries_the_tap_mark_again() -> void:
	# It sat there until 2026-09-03 at `offset_top = 21`, off the bottom of
	# every covered pile row, and the branch that could still put it there
	# ("tapped but not showing the title-bar mark") is now unreachable:
	# every face-up tapped permanent shows the bar, and a FACE-DOWN one
	# draws no status line at all.
	MiniCard._turn_book.clear()
	var land := put_battlefield(0, "Mountain")
	land.tapped = true
	var flat := _flat(land)
	assert_false(flat._status_label.text.contains(MiniCard.TAPPED_MARK))
	var down := _flat(put_battlefield(0, "Forest"))
	down.instance.tapped = true
	down.face_down = true
	down.refresh()
	assert_false(down.shows_tap_mark(), "no name band, so no bar to letter")
	assert_false(down._status_label.visible,
		"and a card back tells the table nothing about itself")


func test_the_name_gives_way_to_the_mark_and_takes_the_room_back() -> void:
	MiniCard._turn_book.clear()
	var land := put_battlefield(0, "Mountain")
	var card := _flat(land)
	var square := card._name_label.offset_left
	land.tapped = true
	card.refresh()
	assert_eq(card._name_label.offset_left, square + MiniCard.TAP_MARK_W,
		"the name steps aside for the mark")
	land.tapped = false
	card.refresh()
	assert_false(card._tap_mark.visible, "untapping takes the mark down")
	assert_false(card._tap_wash.visible)
	assert_eq(card._name_label.offset_left, square, "and gives the room back")


func test_the_wash_dims_the_mana_slashes_but_never_the_name() -> void:
	# The slashes are what a land's tap SPENDS (`Duel.hlp`, **Tap**: the
	# card's *"effects have been temporarily used up"*), so they go under
	# the wash and a tapped Mountain's red reads duller than an untapped
	# one's. The name stays bright: it is the one thing a 17px row must
	# always be readable for.
	MiniCard._turn_book.clear()
	var land := put_battlefield(0, "Mountain")
	land.tapped = true
	var card := _flat(land)
	assert_eq(card._tap_wash.z_index, card._stripes.z_index,
		"same layer as the stripes...")
	assert_gt(card._tap_wash.get_index(), card._stripes.get_index(),
		"...and drawn after them, so it covers them")
	assert_gt(card._name_label.z_index, card._tap_wash.z_index,
		"the name is above the wash")
	assert_gt(card._tap_mark.z_index, card._tap_wash.z_index)


func test_only_a_permanent_on_the_table_is_ever_marked() -> void:
	MiniCard._turn_book.clear()
	var in_hand := give_hand(0, "Mountain")
	in_hand.tapped = true     # nonsense in hand, and drawn as nonsense too
	assert_false(_flat(in_hand)._tap_mark.visible,
		"a card in hand has no tapped state to show")
	var land := put_battlefield(0, "Mountain")
	land.tapped = true
	var down := _flat(land)
	down.face_down = true
	down.refresh()
	assert_false(down._tap_mark.visible,
		"a face-down card tells the table nothing about itself")
	assert_false(down._tap_wash.visible)


# ------------------------------------------------------------- helpers --

func _badge_slots(card: MiniCard) -> Array[int]:
	# The cost row is an HBoxContainer of mana icons; the badges are bare
	# TextureRects, one per slot.
	var out: Array[int] = []
	for child in card._badges.get_children():
		if child is TextureRect:
			out.append(_slot_of(child as TextureRect))
	return out


func _slot_of(rect: TextureRect) -> int:
	for slot in range(0, 18):
		if MiniCard.badge_from_slot(slot) == rect.texture:
			return slot
	return -1
