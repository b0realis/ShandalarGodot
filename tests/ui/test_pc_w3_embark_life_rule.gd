extends GutTest
## PART C, W3 — THE FINAL BATTLE'S RULE ON THE EMBARK SCREEN (the owner,
## 2026-10-27: "A setting at Embark" — "Reload allowed" or "One life"): a
## real choice, the first row of the Campaign Settings since 2026-10-29
## (it stood on the line of "Your rules" before), above the card rule, named as
## the owner named them, "Reload allowed" by default, its tooltip saying
## what it does; chosen, the record, the next visit and the adventure carry
## it; Randomize leaves it; and the
## screen stays whole at 1280 × 800, its columns unscrolled, with the 1997
## art and without it.

var screen: EmbarkScreen


func before_each() -> void:
	AdventureSetup.forget()
	screen = load("res://game/adventure/embark_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	AdventureSetup.forget()
	GameSkin.clear_caches()


func _find(node_name: String, under: Node = null) -> Node:
	return (under if under != null else screen).find_child(node_name, true, false)


func test_the_final_battles_rule_is_chosen_at_the_embark() -> void:
	var rule := _find("LifeRule") as OptionButton
	assert_not_null(rule, "the choice, under the card rule")
	var names: Array[String] = []
	for i in rule.item_count:
		names.append(rule.get_item_text(i))
	assert_eq(names, ["Reload allowed", "One life"] as Array[String], "the owner's names, in order")
	assert_eq(rule.selected, 0, "reload allowed by default")
	assert_string_contains(rule.tooltip_text, "Arzakon's door")
	assert_eq((_find("LifeRuleWords") as Label).text, "Final battle")
	# [0.50.65] In the Campaign Settings, their first row.
	assert_true(_find("CampaignSettingsWindow").is_ancestor_of(rule), "in the Campaign Settings")
	screen.open_settings()
	for i in 3:
		await get_tree().process_frame
	assert_lt(rule.get_global_rect().end.y, (_find("CardRule") as Control).global_position.y + 1.0,
		"above the card rule")
	screen.close_settings()
	rule.select(1)
	rule.item_selected.emit(1)
	assert_eq(screen.setup.life_rule, AdventurePlayer.LIFE_ONE)
	assert_string_contains(rule.tooltip_text, "over for good")
	screen.choose_life_rule("nine lives")
	assert_eq(screen.setup.life_rule, AdventurePlayer.LIFE_ONE, "an odd one changes nothing")
	watch_signals(screen)
	(_find("HeroName") as LineEdit).text = "Ysolde Starfall"
	screen.embark()
	var record: Dictionary = get_signal_parameters(screen, "embarked")[0]
	assert_eq(String(record["life_rule"]), AdventurePlayer.LIFE_ONE, "the record carries it")
	assert_eq(AdventureSetup.restore([] as Array[String]).life_rule, AdventurePlayer.LIFE_ONE, "and the next visit")
	assert_string_contains(screen.summary(record), EmbarkScreen.ONE_LIFE_SUMMARY, "the arrival says so")
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	assert_eq(hero.life_rule, AdventurePlayer.LIFE_ONE, "the adventure plays by it")


func test_a_second_visit_opens_on_the_rule_chosen_and_randomize_leaves_it() -> void:
	screen.choose_life_rule(AdventurePlayer.LIFE_ONE)
	screen.setup.remember()
	var again: EmbarkScreen = load("res://game/adventure/embark_screen.tscn").instantiate()
	add_child_autofree(again)
	await get_tree().process_frame
	var rule := _find("LifeRule", again) as OptionButton
	assert_eq(rule.selected, 1, "One life, as chosen before")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 6:
		again.randomize_all(rng)
		assert_eq(again.setup.life_rule, AdventurePlayer.LIFE_ONE, "not drawn")
	assert_eq(rule.selected, 1)
	var plain := AdventureSetup.new()
	plain.player_name = "Ysolde Starfall"
	assert_false(screen.summary(plain.resolve({})).contains(EmbarkScreen.ONE_LIFE_SUMMARY),
		"reload allowed, the default, needs no words on arrival")


## THE SCREEN STAYS WHOLE at 1280 × 800: no column scrolls, the rule's row
## inside its window and above the buttons — with the skin as the machine
## has it (the 1997 skin on a dev checkout, none on CI: both measured,
## 2026-10-27, the Magic column at 606 and 629 of 646 and 635) — and the
## rule's own column whole with the art and the title face taken away (the
## fallback lettering stands taller; that half-skin is no one's, so the
## other columns are not held to it).
func test_the_screen_stays_whole_at_1280_by_800() -> void:
	await _whole(screen, "with the skin as it is", true)
	GameSkin._texture_cache[EmbarkScreen.BACKGROUND_KEY] = null
	GameSkin._texture_cache["stat_buttons"] = null
	GameSkin._font_cache["font_title"] = null
	var bare: EmbarkScreen = load("res://game/adventure/embark_screen.tscn").instantiate()
	add_child_autofree(bare)
	await get_tree().process_frame
	await _whole(bare, "without the art", false)


func _whole(on: EmbarkScreen, how: String, every_column: bool) -> void:
	on.size = Vector2(1280, 800)
	for i in 3:
		await get_tree().process_frame
	var columns := _find("Columns", on) as Control
	var scroll := columns.get_parent() as ScrollContainer
	var magic := _find("MagicPanel", on) as Control
	if every_column:
		assert_false(scroll.get_v_scroll_bar().visible, "%s: the columns do not scroll" % how)
		assert_lte(columns.get_combined_minimum_size().y, scroll.size.y, "%s: they fit" % how)
	assert_lte(magic.get_combined_minimum_size().y, scroll.size.y, "%s: the rules' column fits" % how)
	# [0.50.65] The rule in the Campaign Settings' window, the window on the
	# screen.
	on.open_settings()
	for i in 3:
		await get_tree().process_frame
	var window := _find("CampaignSettingsWindow", on) as Control
	var row := _find("LifeRuleRow", on) as Control
	assert_true(window.get_global_rect().encloses(row.get_global_rect()), "%s: the rule in its window" % how)
	assert_true(Rect2(Vector2.ZERO, on.size).encloses(window.get_global_rect()), "%s: the window on the screen" % how)
	on.close_settings()
