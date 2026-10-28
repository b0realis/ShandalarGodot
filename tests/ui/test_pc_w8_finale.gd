extends GutTest
## PART C, W8 — THE FINALE OVER THE WORLD ([AdventureFinale]): the fifth
## wizard's question ("Face me now" / "Return to Shandalar first"), the
## battle's way in (BANISH, the deck builder, Arzakon's door and its save),
## the battle's doors under both Embark rules, its result settled and saved
## before anything is shown (a win in the Hall of Fame before the movie), a
## loss's quest-failed end, the win's pages (the picture and its words, the
## record, the Hall and the last choice: End or Return to Shandalar), the
## load's hooks ([method AdventureFinale.after_load]) and the portal's own
## pane on the world ([method AdventureFinale.at_portal]). Headless: no
## movie ([member AdventureFinale.movie_forced] 0), no transitions; the
## world a real generated one, its saves and its leaving counted.

const SAVES := "user://adventure_tests_pc_w8_finale"
const HALL := "user://adventure_tests_pc_w8_finale_hall"


## A world screen that counts its saves, its leaving and its quitting.
class Probe extends WorldScreen:
	var saves := 0
	var titles := 0
	var quits := 0

	func _write_autosave() -> String:
		saves += 1
		return super()

	func _go_to_title() -> void:
		titles += 1
		_leaving = true

	func _end_process() -> void:
		quits += 1


var viewport: SubViewport
var screen: Probe


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	HallOfFame.file = HALL + "/hall_of_fame.json"
	AdventureFinale.movie_forced = 0
	_clear()
	await _open_world()


func after_each() -> void:
	AdventureFinale.movie_forced = -1
	TileReveal.forced = -1
	_clear()
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	HallOfFame.file = HallOfFame.FILE
	AdventurePlayer.forget_saves()


func _clear() -> void:
	for folder in [SAVES, HALL]:
		var dir := DirAccess.open(folder)
		if dir == null:
			continue
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(folder)


func _open_world(life_rule := AdventurePlayer.LIFE_RELOAD) -> void:
	if viewport != null and is_instance_valid(viewport):
		viewport.queue_free()
		await _frames()
	var setup := AdventureSetup.new()
	setup.player_name = "Ysolde Starfall"
	setup.color = "blue"
	setup.difficulty = 1
	setup.walker = "female"
	setup.seed_text = "12345"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	screen = Probe.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.set_process(false)
	var hero := screen.player
	hero.life_rule = life_rule
	hero.food = 50
	hero.monsters = [] as Array
	hero.defeated_wizards.assign(AdventurePlayer.COLORS)
	screen.saves = 0


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


## The finale over the world, its guard passed (as if its moment had gone by).
func _finale() -> AdventureFinale:
	var finale := AdventureFinale.showing(screen)
	if finale != null:
		finale._shown_at -= 100000
	return finale


## The finale's way to the battle: Face me now, Continue, the builder done.
func _to_battle() -> AdventureFinale:
	AdventureFinale.after_fifth_wizard(screen, screen.player)
	await _frames()
	_finale().choose("face")
	_finale().go_on()
	await _frames()
	var finale := _finale()
	assert_eq(finale.step, AdventureFinale.BUILDER)
	finale.builder.closed.emit()
	await _frames(2)
	return finale


## The outcomes [param finale] finishes with, as they come (the finale is
## freed as it finishes: no signal watcher may hold it).
func _outcomes(finale: AdventureFinale) -> Array[String]:
	var out: Array[String] = []
	finale.finished.connect(func(outcome: String) -> void: out.append(outcome))
	return out


## A finished duel's report: [param result] for the hero, Arzakon from
## [param his_start] to [param his_end].
func _report(result: int, his_start: int, his_end: int) -> DuelReport:
	var report := DuelReport.new()
	report.finished = true
	report.result = result
	report.winner = 0 if result == DuelReport.WIN else (1 if result == DuelReport.LOSS else -1)
	report.lives_start = [20, his_start] as Array[int]
	report.lives_end = [7, his_end] as Array[int]
	return report


# ------------------------------------------------------------- the moment --

func test_the_fifth_wizard_asks_and_holds_the_world() -> void:
	AdventureFinale.after_fifth_wizard(screen, screen.player)
	await _frames()
	var finale := AdventureFinale.showing(screen)
	assert_not_null(finale, "the finale over the world")
	assert_eq(finale.step, AdventureFinale.FIFTH)
	assert_true(screen.modal(), "the world held under it")
	assert_false(screen.view.visible, "the world hidden")
	assert_eq((finale.find_child("Words", true, false) as Label).text, "\n".join(FinalBattle.fifth_lines()),
		"@CASTLEWIN 6, word for word")
	var choices := finale.find_child("Choices", true, false)
	assert_eq([(choices.get_child(0) as Button).text, (choices.get_child(1) as Button).text],
		[FinalBattle.FACE_NOW, FinalBattle.RETURN_FIRST])
	finale.choose("face")
	assert_eq(finale.step, AdventureFinale.FIFTH, "nothing is taken in its first moment")
	AdventureFinale.after_fifth_wizard(screen, screen.player)
	await _frames()
	var finales := screen.get_children().filter(func(child: Node) -> bool: return child is AdventureFinale)
	assert_eq(finales.size(), 1, "a second call is the same finale")


func test_return_first_opens_the_portal_saves_and_gives_the_world_back() -> void:
	AdventureFinale.after_fifth_wizard(screen, screen.player)
	await _frames()
	var finale := _finale()
	var outcomes := _outcomes(finale)
	finale.choose("return")
	await _frames()
	var hero := screen.player
	assert_eq(String(hero.portal.get("state", "")), FinalBattle.PORTAL_OPEN, "the portal stands, open")
	assert_true(FinalBattle.portal_told(hero), "the journal says where")
	assert_eq(FinalBattle.portal_tile_of(hero), FinalBattle.portal_tile(hero.world), "near the map's middle")
	assert_eq(screen.saves, 1, "the adventure saved with it")
	assert_eq(outcomes, [AdventureFinale.RETURNED] as Array[String])
	assert_null(AdventureFinale.showing(screen), "the finale gone")
	assert_false(screen.modal(), "the world given back")
	assert_true(screen.view.visible)
	assert_false(hero.at_door, "no battle begun")


# ------------------------------------------------------- the way to battle --

func test_face_me_now_goes_through_the_builder_to_the_door_and_the_battle() -> void:
	AdventureFinale.after_fifth_wizard(screen, screen.player)
	await _frames()
	var finale := _finale()
	finale.choose("face")
	assert_eq(finale.step, AdventureFinale.BANISH)
	assert_eq((finale.find_child("Below", true, false) as Label).text,
		"\n".join(FinalBattle.banish_lines(FinalBattle.score(screen.player))), "@CASTLEWIN 7–8 with the score so far")
	finale.go_on()
	assert_eq(finale.step, AdventureFinale.BANISH, "a click in its first moment reads nothing past")
	_finale().go_on()
	await _frames()
	assert_eq(finale.step, AdventureFinale.BUILDER)
	var builder := finale.builder
	assert_true(builder is AdventureFinale.FinalBuilder, "the adventure's builder, the battle's way")
	assert_false(builder.looking, "cards may move")
	assert_eq(builder.sell_site, -1, "nothing sold")
	assert_true(builder._menu_entries().has(AdventureFinale.TO_BATTLE))
	assert_false(builder._menu_entries().has(AdventureBuilder.BACK_TO_WORLD))
	assert_eq(screen.saves, 0, "nothing saved before the door")
	builder.closed.emit()
	await _frames(2)
	assert_eq(finale.step, AdventureFinale.BATTLE)
	assert_true(screen.player.at_door, "at Arzakon's door")
	assert_false(FinalBattle.portal_told(screen.player),
		"Face me now: the portal stands for a reload, the journal says nothing of it (the owner)")
	assert_eq(screen.saves, 1, "saved at the door")
	var saved := AdventurePlayer.load_from(screen.player.save_path(AdventurePlayer.AUTOSAVE))
	assert_true(saved.at_door, "the save holds the door")
	assert_false(screen.player.portal.is_empty(), "the portal stood for the door's save")
	var duel := finale.duel
	assert_not_null(duel, "the battle over the world")
	assert_eq(duel.foe, FinalBattle.ARZAKON_NAME)
	assert_eq(duel.menu_words, AdventureFinale.MENU_RELOAD, "Reload allowed: the door's save stands")
	assert_eq(duel.duel.leave_question, AdventureFinale.LEAVE_RELOAD)
	assert_eq(duel.config.start_in_play[1], FinalBattle.IN_PLAY, "Black Lotus and Celestial Prism for him")
	duel._finish(_report(DuelReport.LOSS, 200, 150))
	await _frames()


func test_exit_game_in_the_builder_saves_and_ends_before_any_battle() -> void:
	AdventureFinale.after_fifth_wizard(screen, screen.player)
	await _frames()
	_finale().choose("face")
	_finale().go_on()
	await _frames()
	var finale := _finale()
	finale.builder.exit_requested.emit()
	await _frames()
	assert_eq(screen.saves, 1, "saved first, as the world's Exit game")
	assert_eq(screen.quits, 1, "then the game ends")
	assert_false(screen.player.at_door, "no battle begun")
	assert_true(screen.player.portal.is_empty(), "the question waits for the next load")


func test_one_life_battle_says_leaving_is_a_loss() -> void:
	await _open_world(AdventurePlayer.LIFE_ONE)
	var finale := await _to_battle()
	assert_eq(finale.duel.menu_words, AdventureFinale.MENU_ONE_LIFE)
	assert_eq(finale.duel.duel.leave_question, AdventureFinale.LEAVE_ONE_LIFE)
	assert_eq(HallOfFame.one_life_state(screen.player.adventure_id), HallOfFame.BEGUN, "marked begun")
	finale.duel._finish(_report(DuelReport.LOSS, 200, 150))
	await _frames()


# ------------------------------------------------------------- the result --

func test_a_won_battle_is_saved_and_in_the_hall_then_the_win_the_record_the_hall_and_roam() -> void:
	var finale := await _to_battle()
	var outcomes := _outcomes(finale)
	var saves_before := screen.saves
	finale.duel._finish(_report(DuelReport.WIN, 200, 0))
	await _frames()
	var hero := screen.player
	assert_eq(hero.ended, AdventurePlayer.ENDED_WON)
	assert_eq(screen.saves, saves_before + 1, "saved at once")
	var saved := AdventurePlayer.load_from(hero.save_path(AdventurePlayer.AUTOSAVE))
	assert_eq(saved.ended, AdventurePlayer.ENDED_WON, "the save marked won")
	var hall := HallOfFame.entries()
	assert_eq(hall.size(), 1, "the Hall's line written")
	assert_eq(String(hall[0]["id"]), hero.adventure_id)
	assert_eq(finale.hall_place, 1)
	var score := int(finale.settled["score"])
	assert_eq(score, FinalBattle.shown(FinalBattle.score(hero)) + 2000, "200 lives lost, 10 years each")
	await _frames()
	assert_eq(finale.step, AdventureFinale.WIN, "no movie headless: the picture")
	assert_eq((finale.find_child("Words", true, false) as Label).text, "\n".join(FinalBattle.win_lines(score)),
		"@CASTLEWIN 9–10 with the final score")
	assert_true(screen.modal(), "the world still held")
	_finale().go_on()
	assert_eq(finale.step, AdventureFinale.STATS)
	var record := finale.find_child("Record", true, false)
	assert_not_null(record, "the record over the picture")
	assert_eq((record.find_child("Years", true, false) as Label).text, finale.years_line())
	assert_string_contains(finale.years_line(), "%d years" % score)
	assert_not_null(record.find_child("HeroStats", true, false), "the hero's stats")
	(record.find_child("RecordDone", true, false) as Button).pressed.emit()
	await _frames()
	assert_eq(finale.step, AdventureFinale.HALL)
	var pane := finale.find_child("HallOfFame", true, false) as HallOfFamePane
	assert_not_null(pane, "the Hall after the win")
	assert_eq(pane.lit_place(), 1, "the new line lit")
	assert_not_null(pane.find_child("Choice_" + AdventureFinale.ENDED, true, false))
	assert_not_null(pane.find_child("Choice_" + AdventureFinale.ROAMING, true, false))
	saves_before = screen.saves
	finale.last_choice(AdventureFinale.ROAMING)
	await _frames()
	assert_eq(outcomes, [AdventureFinale.ROAMING] as Array[String])
	assert_eq(String(hero.portal["state"]), FinalBattle.PORTAL_PETRIFIED, "the portal a monument")
	assert_true(bool(hero.final.get("roamed", false)))
	assert_eq(screen.saves, saves_before + 1, "saved walking on")
	assert_false(screen.modal(), "the world at peace, given back")
	assert_true(hero.at_peace())


func test_a_press_that_cuts_the_reveal_short_shows_the_words_and_goes_no_further() -> void:
	TileReveal.forced = 1
	var finale := await _to_battle()
	finale.duel._finish(_report(DuelReport.WIN, 200, 0))
	await _frames(2)
	assert_eq(finale.step, AdventureFinale.WIN)
	var reveal := finale.find_child("WinReveal", true, false) as TileReveal
	TileReveal.forced = -1
	if reveal == null:
		# No skin: no picture to reveal, the words at once.
		assert_ne((finale.find_child("Words", true, false) as Label).text, "")
		return
	assert_eq((finale.find_child("Words", true, false) as Label).text, "", "the words wait for the picture")
	finale._shown_at -= 100000
	reveal.finish()
	finale.go_on()
	assert_eq(finale.step, AdventureFinale.WIN, "the press that ended the reveal reads nothing past")
	assert_eq((finale.find_child("Words", true, false) as Label).text,
		"\n".join(FinalBattle.win_lines(int(finale.settled["score"]))))


func test_end_after_the_win_leaves_for_the_title_saved_as_won() -> void:
	var finale := await _to_battle()
	finale.duel._finish(_report(DuelReport.WIN, 200, 0))
	await _frames(2)
	_finale().go_on()
	finale._after_stats()
	await _frames()
	finale.last_choice(AdventureFinale.ENDED)
	await _frames()
	assert_eq(screen.titles, 1, "the title")
	var saved := AdventurePlayer.load_from(screen.player.save_path(AdventurePlayer.AUTOSAVE))
	assert_eq(saved.ended, AdventurePlayer.ENDED_WON)
	assert_false(bool(saved.final.get("roamed", false)), "not walked on")


func test_a_lost_battle_under_reload_allowed_ends_the_quest_and_waits_at_the_door() -> void:
	var finale := await _to_battle()
	var outcomes := _outcomes(finale)
	var saves_before := screen.saves
	finale.duel.concede()
	await _frames()
	var hero := screen.player
	assert_eq(outcomes, [AdventureFinale.FAILED] as Array[String])
	assert_eq(hero.ended, "", "Reload allowed: not closed")
	assert_true(hero.at_door, "the hero kept at the door")
	assert_eq(hero.final_attempts, 1)
	assert_eq(screen.saves, saves_before + 1, "saved before the end")
	assert_true(screen.ended(), "the quest-failed end")
	assert_eq(screen._end.lines, AdventureFinale.failed_parts(true))
	assert_eq(screen._end.lines.back(), FinalBattle.RELOAD_HINT)
	assert_eq(HallOfFame.entries().size(), 0, "no line in the Hall")


func test_a_lost_battle_under_one_life_closes_the_adventure() -> void:
	await _open_world(AdventurePlayer.LIFE_ONE)
	var finale := await _to_battle()
	finale.duel._finish(_report(DuelReport.DRAW, 200, 60))
	await _frames()
	var hero := screen.player
	assert_eq(hero.ended, AdventurePlayer.ENDED_FAILED, "a draw is no win: closed")
	assert_eq(screen._end.lines, AdventureFinale.failed_parts(false))
	var saved := AdventurePlayer.load_from(hero.save_path(AdventurePlayer.AUTOSAVE))
	assert_eq(saved.ended, AdventurePlayer.ENDED_FAILED, "saved failed")
	assert_eq(HallOfFame.one_life_state(hero.adventure_id), HallOfFame.FAILED)


func test_leaving_the_battle_for_the_menu_under_one_life_is_a_loss() -> void:
	await _open_world(AdventurePlayer.LIFE_ONE)
	var finale := await _to_battle()
	var outcomes := _outcomes(finale)
	finale.duel._to_menu()
	await _frames()
	var hero := screen.player
	assert_eq(outcomes, [AdventureFinale.LEFT] as Array[String])
	assert_eq(hero.ended, AdventurePlayer.ENDED_FAILED)
	assert_true(bool(hero.final.get("left", false)))
	var saved := AdventurePlayer.load_from(hero.save_path(AdventurePlayer.AUTOSAVE))
	assert_eq(saved.ended, AdventurePlayer.ENDED_FAILED, "saved as lost")
	assert_eq(screen.titles, 1, "to the title")


func test_leaving_the_battle_under_reload_allowed_keeps_the_door() -> void:
	var finale := await _to_battle()
	var saves_before := screen.saves
	finale.duel._to_menu()
	await _frames()
	assert_eq(screen.player.ended, "")
	assert_true(screen.player.at_door)
	assert_eq(screen.saves, saves_before, "the door's save stands")
	assert_eq(screen.titles, 1)


# ------------------------------------------------------------ the load --

func test_after_load_one_life_at_the_door_is_the_quest_failed() -> void:
	await _open_world(AdventurePlayer.LIFE_ONE)
	var hero := screen.player
	hero.at_door = true
	assert_true(AdventureFinale.after_load(screen, hero))
	assert_eq(hero.ended, AdventurePlayer.ENDED_FAILED)
	assert_eq(screen.saves, 1, "saved so")
	assert_true(screen.ended(), "its end, not the world")


func test_after_load_a_failed_adventure_opens_on_its_end() -> void:
	var hero := screen.player
	hero.ended = AdventurePlayer.ENDED_FAILED
	assert_true(AdventureFinale.after_load(screen, hero))
	assert_true(screen.ended())
	assert_eq(screen.saves, 0)


## The door after a lost battle, as the owner ruled it (2026-10-28): fight
## or return.
func _at_the_door() -> AdventureFinale:
	var hero := screen.player
	FinalBattle.door(hero)
	hero.final_attempts = 2
	assert_true(AdventureFinale.after_load(screen, hero))
	await _frames()
	var finale := _finale()
	assert_eq(finale.step, AdventureFinale.DOOR)
	return finale


func test_after_load_at_the_door_asks_fight_or_return() -> void:
	var finale := await _at_the_door()
	assert_eq((finale.find_child("Note", true, false) as Label).text, AdventureFinale.LOST_BEFORE % 2)
	assert_eq((finale.find_child("Appears", true, false) as Label).text, AdventureFinale.ARZAKON_AWAITS)
	var choices := finale.find_child("Choices", true, false)
	assert_eq([(choices.get_child(0) as Button).text, (choices.get_child(1) as Button).text],
		[AdventureFinale.FACE_AGAIN, FinalBattle.RETURN_FIRST])
	assert_true(screen.modal())
	finale.choose("face")
	assert_eq(finale.step, AdventureFinale.BANISH, "Face him again: the way to the battle")


func test_returning_from_the_door_keeps_the_portal_and_tells_it_once() -> void:
	var finale := await _at_the_door()
	var hero := screen.player
	assert_false(FinalBattle.portal_told(hero), "faced at once: the portal stood silently")
	var outcomes := _outcomes(finale)
	finale.choose("return")
	await _frames()
	assert_eq(outcomes, [AdventureFinale.RETURNED] as Array[String])
	assert_false(hero.at_door, "off the door")
	assert_true(FinalBattle.portal_open(hero), "the portal stays open")
	assert_eq(FinalBattle.portal_target(hero)["kind"], FinalBattle.PORTAL_KIND, "the arrows point to it")
	assert_true(FinalBattle.portal_told(hero), "the journal says where")
	assert_eq(screen.saves, 1, "saved so")
	assert_false(screen.modal(), "the world again: shop, trade, rebuild")
	var saved := AdventurePlayer.load_from(hero.save_path(AdventurePlayer.AUTOSAVE))
	assert_false(saved.at_door, "a reload opens on the world")
	assert_false(AdventureFinale.after_load(screen, saved), "the portal waits")
	var lines := hero.journal.size()
	hero.at_door = true
	FinalBattle.leave_door(hero)
	assert_eq(hero.journal.size(), lines, "told once")


func test_after_load_at_the_question_asks_again() -> void:
	assert_true(AdventureFinale.after_load(screen, screen.player))
	await _frames()
	assert_eq(AdventureFinale.showing(screen).step, AdventureFinale.FIFTH)


func test_after_load_a_won_adventure_asks_end_or_return_again() -> void:
	var hero := screen.player
	hero.ended = AdventurePlayer.ENDED_WON
	hero.final = {"score": 1130}
	FinalBattle.open_portal(hero, false)
	hero.portal["state"] = FinalBattle.PORTAL_PETRIFIED
	var lines := hero.journal.size()
	assert_true(AdventureFinale.after_load(screen, hero), "the owner's ruling: asked again")
	await _frames()
	var finale := _finale()
	assert_eq(finale.step, AdventureFinale.HALL)
	assert_not_null(finale.find_child("Choice_" + AdventureFinale.ENDED, true, false))
	assert_not_null(finale.find_child("Choice_" + AdventureFinale.ROAMING, true, false))
	assert_not_null((finale.find_child("Art", true, false) as TextureRect), "over the win's picture")
	assert_true(screen.modal())
	finale.last_choice(AdventureFinale.ROAMING)
	await _frames()
	assert_eq(hero.journal.size(), lines + 1, "the roaming line")
	assert_false(screen.modal())
	assert_true(AdventureFinale.after_load(screen, hero), "loaded again: asked again")
	await _frames()
	_finale().last_choice(AdventureFinale.ROAMING)
	await _frames()
	assert_eq(hero.journal.size(), lines + 1, "the line once")


func test_after_load_an_adventure_going_on_is_left_alone() -> void:
	var hero := screen.player
	hero.defeated_wizards.clear()
	assert_false(AdventureFinale.after_load(screen, hero))
	hero.defeated_wizards.assign(AdventurePlayer.COLORS)
	FinalBattle.open_portal(hero)
	assert_false(AdventureFinale.after_load(screen, hero), "the portal waits on the world")
	assert_null(AdventureFinale.showing(screen))


# ------------------------------------------------------------ the portal --

func test_the_portal_walked_onto_asks_and_enters() -> void:
	var hero := screen.player
	assert_null(AdventureFinale.at_portal(screen, hero), "no portal yet")
	FinalBattle.open_portal(hero)
	var pane := AdventureFinale.at_portal(screen, hero)
	assert_not_null(pane)
	assert_eq(pane.place["name"], FinalBattle.PORTAL_NAME)
	assert_eq(pane.words(), "\n".join(AdventureFinale.PORTAL_LINES))
	assert_eq(WorldCursors.FOR_PLACE[AdventureFinale.place_at(hero, FinalBattle.portal_tile_of(hero))["kind"]],
		WorldCursors.Kind.PORTAL, "the portal's pointer")
	assert_not_null(pane.find_child("Choice_leave", true, false))
	pane.choose("leave")
	await _frames()
	assert_false(is_instance_valid(pane) and not pane.is_queued_for_deletion(), "Not yet: gone")
	assert_null(AdventureFinale.showing(screen))
	pane = AdventureFinale.at_portal(screen, hero)
	pane.choose("enter")
	await _frames()
	var finale := AdventureFinale.showing(screen)
	assert_not_null(finale, "in: the battle's way")
	assert_eq(finale.step, AdventureFinale.BANISH)


func test_the_monument_tells_the_years() -> void:
	var hero := screen.player
	FinalBattle.open_portal(hero)
	hero.portal["state"] = FinalBattle.PORTAL_PETRIFIED
	hero.ended = AdventurePlayer.ENDED_WON
	hero.final = {"score": 1130}
	var pane := AdventureFinale.at_portal(screen, hero)
	assert_eq(pane.place["name"], FinalBattle.MONUMENT_NAME)
	assert_string_contains(pane.words(), "Ysolde Starfall banished him from Shandalar for 1130 years.")
	assert_null(pane.find_child("Choice_enter", true, false), "no way in")
	var at := FinalBattle.portal_tile_of(hero)
	assert_eq(AdventureFinale.place_at(hero, at),
		{"kind": "monument", "name": FinalBattle.MONUMENT_NAME, "subtitle": AdventureFinale.MONUMENT_KIND})
	assert_eq(WorldCursors.FOR_PLACE[AdventureFinale.place_at(hero, at)["kind"]], WorldCursors.Kind.MONUMENT,
		"its own pointer")
	assert_eq(AdventureFinale.place_at(hero, at + Vector2i(1, 0)), {})
	pane.queue_free()
