extends GutTest
## PHASED-OUT PERMANENTS ON THE DUEL SCREEN (Pack 8, the Mirage block).
##
## A phased-out permanent is treated as though it does not exist (CR
## 702.26b), so the engine lifts it out of `MtgPlayer.battlefield` into
## `MtgPlayer.phased_out` — and until this pass the board, which drew only
## the first list, simply lost it for a turn. It is PUBLIC: it lies face up
## on the table and comes back at its controller's next untap step (CR
## 502.1). These pin the board drawing both seats' phased-out permanents
## ghosted, with the 1997 `Phased` cue (`@CUECARD_SMALLCARD`,
## `UIStrings.txt:743`) and a line saying when each comes back; Auras
## riding along drawn on their host; nothing about one clickable as a
## target, attacker or source; and a small window still drawing them.

var screen: DuelScreen
var _saved_stops: Variant = null


func before_each() -> void:
	_saved_stops = Settings.get_value(PhaseStops.SETTING_KEY, null) \
		if Settings.has_value(PhaseStops.SETTING_KEY) else null
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 0.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.stops.clear_all()
	var g: MtgGame = screen.game
	g._probing = true
	for p in g.players:
		p.hand.clear()
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.awaiting_attackers = false
	g.awaiting_blockers = false
	g.priority_player = 0
	g._probing = false
	screen.mode = DuelScreen.Mode.NORMAL


func after_each() -> void:
	CardPacks.set_enabled("pack-8", false)
	if _saved_stops == null:
		Settings.clear_value(PhaseStops.SETTING_KEY)
	else:
		Settings.set_value(PhaseStops.SETTING_KEY, _saved_stops)


# ---------------------------------------------------------------- fixture --

static func _raiders() -> CardData:
	return CardData.new("Test Raiders", "{1}{U}", Mtg.CardType.CREATURE).pt(1, 3) \
		.with_keywords([Mtg.Keyword.PHASING])


static func _bear(card_name := "Test Bear") -> CardData:
	return CardData.new(card_name, "{1}{G}", Mtg.CardType.CREATURE).pt(2, 2)


static func _aura() -> CardData:
	return CardData.new("Test Veil", "{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature())


static func _shock() -> CardData:
	return CardData.new("Test Shock", "{R}", Mtg.CardType.INSTANT) \
		.spell(DamageEffect.new(1).any_target())


## Set-up surgery under the engine's own "emit nothing" switch, so the
## screen's automatic pass does not walk the human's priority away while
## the table is still being laid.
func _put(pid: int, data: CardData) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._probing = true
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	inst.summoning_sick = false
	g.recalculate()
	g._probing = false
	return inst


func _give(pid: int, data: CardData) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = Mtg.Zone.HAND
	g.players[pid].hand.append(inst)
	return inst


## Every MiniCard on screen showing [param inst].
func _widgets_for(inst: CardInstance) -> Array:
	var out: Array = []
	var stack: Array = [screen]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MiniCard and (node as MiniCard).instance == inst \
				and node.is_inside_tree() and not node.is_queued_for_deletion():
			out.append(node)
		stack.append_array(node.get_children())
	return out


func _one_widget(inst: CardInstance) -> MiniCard:
	var all := _widgets_for(inst)
	assert_eq(all.size(), 1, "%s is drawn exactly once" % inst.data.card_name)
	return all[0] if not all.is_empty() else null


# ------------------------------------------------------------------ tests --

func test_a_phased_out_creature_stays_on_the_table_ghosted_with_its_cue() -> void:
	var g: MtgGame = screen.game
	var raiders := _put(0, _raiders())
	screen._refresh()
	assert_eq(_widgets_for(raiders).size(), 1, "control: drawn while phased in")
	assert_true(g.phase_out(raiders))
	assert_false(g.players[0].battlefield.has(raiders), "the engine lifted it out")
	screen._refresh()
	var card := _one_widget(raiders)
	if card == null:
		return
	assert_true(card.active_states().has(MiniCard.State.PHASED))
	assert_eq(MiniCard.STATE_CUE[MiniCard.State.PHASED], "Phased",
		"@CUECARD_SMALLCARD's own word, UIStrings.txt:743")
	assert_string_contains(card.tooltip_text, "Phased")
	assert_string_contains(card.tooltip_text,
		"Phases in at %s's next untap step" % g.players[0].player_name)
	assert_eq(card.modulate, MiniCard.PHASED_GHOST, "drawn as a ghost of itself")
	var mark := card.find_child("PhasedMark", true, false) as Label
	assert_not_null(mark)
	if mark != null:
		assert_true(mark.visible)
		assert_eq(mark.text, "Phased out")
	# In the creature row of its own side.
	var row: Container = screen._field_rows[0][DuelScreen.Row.CREATURES]
	assert_true(row.is_ancestor_of(card), "in its controller's creature row")
	# ...and it comes back at the untap step, phased in and unghosted.
	g._phasing_step(0)
	screen._refresh()
	var back := _one_widget(raiders)
	if back != null:
		assert_false(back.active_states().has(MiniCard.State.PHASED))
		assert_eq(back.find_child("PhasedMark", true, false), null,
			"a card that never phased builds no mark")


func test_the_opponents_phased_permanents_are_public_too() -> void:
	var g: MtgGame = screen.game
	var theirs := _put(1, _raiders())
	assert_true(g.phase_out(theirs))
	screen._refresh()
	var card := _one_widget(theirs)
	if card == null:
		return
	assert_true(screen._field_rows[1][DuelScreen.Row.CREATURES].is_ancestor_of(card),
		"on the opponent's side of the table")
	assert_false(card.face_down, "face up: phasing hides nothing")
	assert_string_contains(card.tooltip_text,
		"Phases in at %s's next untap step" % g.players[1].player_name)


func test_an_aura_rides_out_with_its_host_and_is_drawn_on_it() -> void:
	var g: MtgGame = screen.game
	var host := _put(0, _bear())
	var veil := _give(0, _aura())
	g._probing = true
	g.players[0].mana_pool.add(Mtg.ManaColor.U, 1)
	g.priority_player = 0
	assert_eq(g.cast_spell(0, veil, [TargetRef.card(host)]), "")
	g._resolve_top()
	g._probing = false
	assert_eq(veil.attached_to, host.id)
	assert_true(g.phase_out(host))
	assert_true(veil.phased_out and veil.phased_indirectly, "702.26g: it rode along")
	screen._refresh()
	var host_card := _one_widget(host)
	var veil_card := _one_widget(veil)
	if host_card == null or veil_card == null:
		return
	assert_eq(veil_card.get_parent(), host_card.get_parent(),
		"the aura peeks out from behind its host, as on any host")
	assert_true(veil_card.active_states().has(MiniCard.State.PHASED))
	assert_string_contains(veil_card.tooltip_text, "Phases in with Test Bear")


func test_a_held_permanent_names_its_holder() -> void:
	var g: MtgGame = screen.game
	var holder := _put(1, CardData.new("Test Oubliette", "{1}{B}{B}",
		Mtg.CardType.ENCHANTMENT))
	var bear := _put(0, _bear())
	assert_true(g.phase_out(bear, holder))
	screen._refresh()
	var card := _one_widget(bear)
	if card == null:
		return
	assert_string_contains(card.tooltip_text,
		"Held by Test Oubliette: phases in when Test Oubliette leaves the battlefield")
	assert_eq(MiniCard.phase_note(g, bear), "Held by Test Oubliette: phases in when "
		+ "Test Oubliette leaves the battlefield")


func test_a_phased_land_keeps_a_slot_of_its_own_beside_a_pile() -> void:
	var g: MtgGame = screen.game
	var lands: Array[CardInstance] = []
	for i in 3:
		lands.append(_put(0, CardRegistry.get_card("Island")))
	assert_true(g.phase_out(lands[1]))
	screen._refresh()
	var card := _one_widget(lands[1])
	if card == null:
		return
	assert_false(card.get_parent() is Button and card.get_parent().get_parent() is CardPile,
		"never folded into a pile, where its letters would be covered")
	assert_true(card.active_states().has(MiniCard.State.PHASED))
	for other in [lands[0], lands[2]]:
		assert_eq(_widgets_for(other).size(), 1, "the other lands are still drawn")


func test_nothing_about_a_phased_card_is_clickable() -> void:
	var g: MtgGame = screen.game
	var raiders := _put(1, _raiders())
	var bear := _put(0, _bear())
	assert_true(g.phase_out(raiders))
	# Targeting: the ghost is no target and wears no "can't target" slash.
	var shock := _give(0, _shock())
	g.players[0].mana_pool.add(Mtg.ManaColor.R, 1)
	screen._click_hand_card(shock)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	assert_eq(screen._highlight_for(raiders), MiniCard.Highlight.NONE)
	assert_eq(screen._target_state_for(raiders), -1)
	screen._on_card_clicked(raiders)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING, "the click took nothing")
	assert_true(screen._pending_groups[0].is_empty())
	assert_string_contains(screen._prompt_label.text, "Test Raiders is phased out")
	screen._on_cancel()
	assert_eq(g.stack.size(), 0)
	# Attacking: my phased creature cannot join the lineup.
	assert_true(g.phase_out(bear))
	g._probing = true
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS))
	g._probing = false
	g.awaiting_attackers = true
	screen._refresh()
	assert_eq(screen.mode, DuelScreen.Mode.ATTACKERS)
	assert_eq(screen._highlight_for(bear), MiniCard.Highlight.NONE)
	screen._on_card_clicked(bear)
	assert_false(screen._selected_attackers.has(bear.id))


func test_a_small_window_still_draws_the_ghosts() -> void:
	var g: MtgGame = screen.game
	screen.size = Vector2(1024, 640)
	await get_tree().process_frame
	var mine: Array[CardInstance] = []
	for i in 6:
		mine.append(_put(0, _bear("Test Bear %d" % i)))
	assert_true(g.phase_out(mine[2]))
	assert_true(g.phase_out(mine[5]))
	screen._refresh()
	await get_tree().process_frame
	for inst in mine:
		var card := _one_widget(inst)
		if card == null:
			continue
		assert_true(card.visible)
		var rect := card.get_global_rect()
		var half: Control = screen._half_rows[0]
		assert_true(half.get_global_rect().grow(4).encloses(rect),
			"%s fits its half of a small window" % inst.data.card_name)
	assert_true(_one_widget(mine[2]).active_states().has(MiniCard.State.PHASED))


## A stand-in for `CardPacks`: the suite's packs are metadata-only and
## ship no pictures, so the real one has nothing to hand back here.
class FakePacks extends RefCounted:
	var picture := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGB8))
	var asked: Array = []
	func art_texture(card_name: String, set_code: String, _full := false, _number := "") -> Texture2D:
		asked.append([card_name, set_code])
		return picture


func test_a_pack_card_wears_its_own_pack_art_on_the_table() -> void:
	# Found staging this board (and in the shot it produced): a pack card
	# with no pinned printing was a blank frame on the table — phased or
	# not — while its Showcase was illustrated; the small card never asked
	# the pack for its art (MiniCard.table_art).
	var raider := CardData.new("Test Raider", "{1}{U}", Mtg.CardType.CREATURE).pt(1, 3) \
		.with_keywords([Mtg.Keyword.PHASING])
	raider.set_code = "mir"
	var inst := _put(0, raider)
	var packs := FakePacks.new()
	assert_eq(MiniCard.table_art(inst, packs), packs.picture,
		"no printing pinned and nothing in the skin: the pack's own art")
	assert_eq(packs.asked.back(), ["Test Raider", "mir"], "asked for its own set")
	assert_true(screen.game.phase_out(inst))
	var ghost := MiniCard.new(inst, screen.game)
	ghost.packs_service = packs
	add_child_autofree(ghost)
	ghost.refresh()
	assert_true(ghost.active_states().has(MiniCard.State.PHASED))
	assert_eq(ghost._art.texture, packs.picture, "the phased ghost wears the same art")
	assert_true(ghost._art.visible)
