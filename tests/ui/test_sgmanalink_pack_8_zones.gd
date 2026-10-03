extends GameTest
## PACK 8 ZONE ACTIONS AT AN SGMANALINK TABLE — the Mirage block's new ways
## for a HUMAN seat to act from somewhere other than its hand, and the one
## new way a permanent lies on the table, played through the referee
## (`SgPracticeMatch`) and the real networked screen (`SgDuelView`).
##
##  * Bösium Strip: "you may cast instant and sorcery spells from the top of
##    your graveyard" (`MtgGame.can_cast_from_graveyard`). The referee's
##    action list (`SgDuelActions.options`) knew the hand and face-UP exile
##    only, so the networked seat had no way to cast it.
##  * Three Wishes: a card exiled FACE DOWN that only its owner may look at
##    and play (`exile_visible_to`, `MtgGame.can_play_from_exile`). The
##    viewer was shown the card but `options` refused it for being face
##    down; the other seat must never learn its name (rule 8).
##  * Circling Vultures: a hand card discarded as a SPECIAL ACTION
##    (`MtgGame.discard_as_special_action`) — no stack, priority kept. The
##    projection would have run the discard on its own copy of the table.
##    The screen-driven cases use the printed card: the client reads a hand
##    card's own definition (both ends share the catalogue), and a test-only
##    synthetic has none at the client.
##  * Phasing: a phased-out permanent is off every battlefield list but
##    still on the table, public to both seats (CR 702.26). The view sent
##    the battlefield list only, so it vanished at both seats.

var referee: SgPracticeMatch
var revision := 1
var commands: Array = []
var refusals: Array = []


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	super.before_each()
	referee = SgPracticeMatch.new(42)
	referee.game = g
	revision = 1
	commands.clear()
	refusals.clear()
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())


func after_each() -> void:
	referee = null
	CardPacks.set_enabled("pack-8", false)


# ---------------------------------------------------------------- fixture --

func _room(seat := 0) -> Dictionary:
	return {"id": "r1", "name": "Pack eight", "seat": seat,
		"names": ["Azure Fox", "Amber Owl"], "revision": revision,
		"ready": [true, true], "connected": [true, true], "game": referee.view(seat),
		"deck_names": referee.deck_names.duplicate(), "deck": {}}


func _screen(seat := 0) -> SgDuelView:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var screen := SgDuelView.new()
	screen.stops.from_masks(PackedInt32Array([255, 255, 255, 255]))
	viewport.add_child(screen)
	screen.action_requested.connect(_act.bind(screen, seat))
	screen.present(_room(seat), true, false)
	return screen


func _act(action: Dictionary, screen: SgDuelView, seat: int) -> void:
	commands.append(action.duplicate(true))
	var error := referee.act(seat, action)
	if not error.is_empty():
		refusals.append(error)
		screen.show_notice(error)
	else: revision += 1
	screen.present.call_deferred(_room(seat), true, false)


func _pump() -> void:
	for i in 8: await get_tree().process_frame


func _local(screen: SgDuelView, card: CardInstance) -> CardInstance:
	return screen.game.find_instance(screen.projection.local_id(referee._handle(int(screen._room.seat), card)))


## [param card]'s face in [param view] (built for [param viewer]), or {}.
func _face(view: Dictionary, card: CardInstance, viewer := 0) -> Dictionary:
	var handle := referee._handle(viewer, card)
	var zones: Array = [view.hand]
	for p in view.players:
		for key in ["battlefield", "graveyard", "exile", "ante", "revealed", "phased_out"]:
			if p.has(key): zones.append(p[key])
	for zone in zones:
		for face in zone:
			if face.id == handle: return face
	return {}


func _row(view: Dictionary, card: CardInstance, viewer := 0) -> Dictionary:
	var handle := referee._handle(viewer, card)
	for row in view.presentation.cards:
		if row.id == handle: return row
	return {}


static func _casts(face: Dictionary) -> bool:
	for option in face.get("actions", []):
		if option.kind == "spell": return true
	return false


static func _shock(card_name := "Test Shock") -> CardData:
	return CardData.new(card_name, "{R}", Mtg.CardType.INSTANT) \
		.spell(DamageEffect.new(2).any_target())


static func _vultures(card_name := "Test Vultures") -> CardData:
	return CardData.new(card_name, "{B}", Mtg.CardType.CREATURE).pt(3, 2) \
		.with_keywords([Mtg.Keyword.FLYING]).with_discard_special_action()


static func _raiders() -> CardData:
	return CardData.new("Test Raiders", "{1}{U}", Mtg.CardType.CREATURE).pt(1, 3) \
		.with_keywords([Mtg.Keyword.PHASING])


static func _veil() -> CardData:
	return CardData.new("Test Veil", "{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature())


static func _instant_or_sorcery(c: CardInstance) -> bool:
	return c.data.is_type(Mtg.CardType.INSTANT) or c.data.is_type(Mtg.CardType.SORCERY)


func _to_graveyard(pid: int, data: CardData) -> CardInstance:
	var inst := give_synthetic(pid, data)
	g.card_to_graveyard_from_anywhere(inst)
	return inst


# ============================================== casting from a graveyard --

func test_bosium_strip_casts_the_top_of_the_graveyard_over_the_network() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var under := _to_graveyard(0, _shock("Test Spark"))
	var top := _to_graveyard(0, _shock())
	var view := referee.view(0)
	assert_false(_casts(_face(view, top)), "control: no permission, no cast")
	g.grant_graveyard_cast(0, _instant_or_sorcery, "instant and sorcery spells", true, true)
	add_mana(0, Mtg.ManaColor.R)
	view = referee.view(0)
	assert_true(SgViewProtocol.game(view), "the view stays valid")
	assert_true(_casts(_face(view, top)), "the referee offers the top card's cast")
	assert_false(_casts(_face(view, under)), "only the TOP card")
	assert_true(_row(view, top).castable, "and lights it")
	assert_false(_casts(_face(referee.view(1), top, 1)), "the permission is not the other seat's")
	var screen := _screen()
	await _pump()
	var local_top := _local(screen, top)
	assert_true(screen.game.can_cast_from_graveyard(0, local_top), "the graveyard view rings it")
	assert_false(screen.game.can_cast_from_graveyard(0, _local(screen, under)))
	screen._on_graveyard_card(local_top)
	await _pump()
	assert_eq(refusals, [])
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING, "the hand's own cast chain")
	screen._on_life_clicked(1)
	await _pump()
	assert_eq(refusals, [])
	assert_eq(top.zone, Mtg.Zone.STACK, "cast from the graveyard")
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	assert_eq(top.zone, Mtg.Zone.EXILE, "exiled instead of returning to the graveyard")


# ===================================== a face-down card its seat may play --

func _wish(card_name := "Secret Spark") -> CardInstance:
	var secret := give_synthetic(0, _shock(card_name))
	g.put_from_hand_on_top_of_library(secret)
	var exiled := g.exile_top_of_library(0, true, 0)
	assert_eq(exiled, secret)
	g.grant_exile_play(secret, 0, true)
	return secret


func test_three_wishes_card_is_hidden_from_the_other_seat() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var secret := _wish()
	assert_true(secret.face_down)
	var theirs := referee.view(1)
	assert_true(SgViewProtocol.game(theirs))
	assert_false(SgProtocol.encode(theirs).contains("Secret Spark"),
		"rule 8: nothing in the other seat's view names it")
	var face := _face(theirs, secret, 1)
	assert_eq(face.get("name"), "Face-down card")
	assert_true(face.get("masked", false))
	assert_false(face.get("exile_playable", true))
	assert_eq(face.get("actions"), [])
	assert_false(_row(theirs, secret, 1).castable)


func test_three_wishes_card_is_cast_by_its_viewer() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var secret := _wish()
	add_mana(0, Mtg.ManaColor.R)
	var mine := referee.view(0)
	var face := _face(mine, secret)
	assert_eq(face.get("name"), "Secret Spark", "its owner may look at it")
	assert_true(face.get("exile_playable", false))
	assert_true(_casts(face), "and the referee offers the cast")
	assert_true(_row(mine, secret).castable)
	var screen := _screen()
	await _pump()
	screen._on_graveyard_card(_local(screen, secret))
	await _pump()
	assert_eq(refusals, [])
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	screen._on_life_clicked(1)
	await _pump()
	assert_eq(refusals, [])
	assert_eq(secret.zone, Mtg.Zone.STACK)
	assert_false(secret.face_down, "played face up")
	assert_true(SgProtocol.encode(referee.view(1)).contains("Secret Spark"),
		"on the stack it is public")


func test_a_three_wishes_land_is_played_by_its_viewer() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var forest := give_hand(0, "Forest")
	g.put_from_hand_on_top_of_library(forest)
	assert_eq(g.exile_top_of_library(0, true, 0), forest)
	g.grant_exile_play(forest, 0, true)
	assert_true(_face(referee.view(0), forest).get("playable", false), "a land drop it may take")
	assert_false(_face(referee.view(1), forest, 1).get("playable", true))
	var screen := _screen()
	await _pump()
	screen._on_graveyard_card(_local(screen, forest))
	await _pump()
	assert_eq(refusals, [])
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD, "played from exile")
	assert_false(forest.face_down, "face up")


# =============================================== a hand special action --

func test_circling_vultures_is_discarded_as_a_special_action_from_the_hand() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var vultures := give_hand(0, "Circling Vultures")
	var screen := _screen()
	await _pump()
	var local := _local(screen, vultures)
	screen._click_hand_card(local)
	assert_eq(screen._hand_action_inst, local, "Cast or Discard is asked, as at a local table")
	screen._on_hand_action_chosen(DuelScreen.HAND_ACTION_DISCARD)
	await _pump()
	assert_eq(refusals, [])
	assert_eq(vultures.zone, Mtg.Zone.GRAVEYARD, "discarded at the referee")
	assert_true(g.stack.is_empty(), "no stack")
	assert_eq(g.priority_player, 0, "the player keeps priority")
	assert_eq(screen.game.players[0].hand.size(), 0, "the projection followed the referee")
	assert_eq(screen.game.players[0].graveyard.size(), 1)


func test_the_right_click_discard_goes_to_the_referee_not_the_projection() -> void:
	advance_to_step(Mtg.Step.UPKEEP)
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)
	var vultures := give_hand(1, "Circling Vultures")
	var screen := _screen(1)
	await _pump()
	var local := _local(screen, vultures)
	screen._card_menu_inst = local
	screen._on_card_menu_chosen(DuelScreen.CARD_MENU_DISCARD_SPECIAL)
	assert_eq(local.zone, Mtg.Zone.HAND, "the projection never discards on its own")
	await _pump()
	assert_eq(refusals, [])
	assert_eq(vultures.zone, Mtg.Zone.GRAVEYARD, "the opponent's turn: any time it could cast an instant")
	assert_eq(g.priority_player, 1)


func test_the_hand_menus_cast_line_casts_over_the_network() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var vultures := give_hand(0, "Circling Vultures")
	add_mana(0, Mtg.ManaColor.B)
	var screen := _screen()
	await _pump()
	screen._click_hand_card(_local(screen, vultures))
	screen._on_hand_action_chosen(DuelScreen.HAND_ACTION_CAST)
	await _pump()
	assert_eq(refusals, [])
	assert_eq(vultures.zone, Mtg.Zone.STACK, "cast through the referee's announcement")


func test_the_referee_judges_the_special_discard() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var vultures := give_synthetic(0, _vultures())
	var bear := give_synthetic(0, CardData.new("Test Bear", "{1}{G}", Mtg.CardType.CREATURE).pt(2, 2))
	var command := {"v": SgProtocol.VERSION, "type": "command", "seq": 1, "room": "r1",
		"revision": 1, "action": {"op": "discard_special", "card": referee._handle(0, vultures)}}
	assert_true(SgProtocol.valid(command), "a wire command of its own")
	assert_refused(referee.act(1, {"op": "discard_special", "card": "c1"}), "Wait for your decision")
	assert_refused(referee.act(0, {"op": "discard_special", "card": referee._handle(0, bear)}),
		"can't be discarded this way")
	assert_ok(referee.act(0, {"op": "discard_special", "card": referee._handle(0, vultures)}))
	assert_eq(vultures.zone, Mtg.Zone.GRAVEYARD)


# ============================================================ phasing --

func test_a_phased_out_permanent_is_public_and_phased_at_both_seats() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var raiders := put_synthetic(0, _raiders())
	assert_true(g.phase_out(raiders))
	assert_false(g.players[0].battlefield.has(raiders))
	for viewer in 2:
		var view := referee.view(viewer)
		assert_true(SgViewProtocol.game(view), "seat %d's view is valid" % viewer)
		var listed: Array = []
		for face in view.players[0].get("phased_out", []): listed.append(face.name)
		assert_eq(listed, ["Test Raiders"], "seat %d sees it lying phased out" % viewer)
		for face in view.players[0].battlefield:
			assert_ne(face.name, "Test Raiders", "and not as present")
		assert_eq(_face(view, raiders, viewer).get("actions"), [], "nothing to activate")
		assert_true(_row(view, raiders, viewer).get("flags", {}).get("phased_out", false))
	for seat in 2:
		var screen := _screen(seat)
		await _pump()
		var local := _local(screen, raiders)
		var side := screen.projection.local_seat(0)
		assert_not_null(local)
		if local == null: continue
		assert_true(local.phased_out)
		assert_true(screen.game.players[side].phased_out.has(local))
		assert_false(screen.game.players[side].battlefield.has(local))
		assert_true(screen._table_cards(side).has(local), "drawn on its controller's side")
		assert_string_contains(MiniCard.phase_note(screen.game, local),
			"Phases in at Azure Fox's next untap step")


func test_a_phased_out_permanent_is_not_clickable_over_the_network() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var raiders := put_synthetic(0, CardData.new("Test Raiders", "{1}{U}", Mtg.CardType.CREATURE) \
		.pt(1, 3).with_keywords([Mtg.Keyword.PHASING]) \
		.activated(ActivatedAbility.new("{0}", false, [PumpEffect.new(1, 1).self_buff()], "{0}: +1/+1.")))
	assert_true(g.phase_out(raiders))
	var screen := _screen()
	await _pump()
	var sent := commands.size()
	screen._on_card_clicked(_local(screen, raiders))
	await _pump()
	assert_eq(commands.size(), sent, "no command for a permanent that does not exist")
	assert_string_contains(screen._prompt_label.text, "Test Raiders is phased out")


func test_an_aura_rides_out_and_a_held_permanent_names_its_holder() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var host := put_synthetic(0, CardData.new("Test Bear", "{1}{G}", Mtg.CardType.CREATURE).pt(2, 2))
	var veil := give_synthetic(0, _veil())
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, veil, [TargetRef.card(host)]))
	resolve_stack()
	assert_eq(veil.attached_to, host.id)
	var holder := put_synthetic(1, CardData.new("Test Oubliette", "{1}{B}{B}", Mtg.CardType.ENCHANTMENT))
	assert_true(g.phase_out(host, holder))
	assert_true(veil.phased_indirectly)
	var view := referee.view(1)
	assert_true(SgViewProtocol.game(view))
	var screen := _screen(1)
	await _pump()
	var local_host := _local(screen, host)
	var local_veil := _local(screen, veil)
	assert_not_null(local_veil)
	if local_host == null or local_veil == null: return
	assert_true(local_veil.phased_out and local_veil.phased_indirectly, "702.26g: it rode along")
	assert_eq(local_veil.attached_to, local_host.id)
	assert_string_contains(MiniCard.phase_note(screen.game, local_veil), "Phases in with Test Bear")
	assert_string_contains(MiniCard.phase_note(screen.game, local_host),
		"Held by Test Oubliette: phases in when Test Oubliette leaves the battlefield")
