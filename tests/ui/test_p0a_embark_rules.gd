extends GutTest
## P0a — THE CARD HOLD AND THE BAN LIST ON THE EMBARK SCREEN (the owner,
## 2026-10-28): two choices in "Your rules", each words and a list as the
## final battle's is ([method EmbarkScreen._build_life_rule]) — "Card hold":
## "1997 card hold limit" (the default) or "Unlimited card hold"; "Ban
## list": "1998 (the original game's)", "1998 + modern" (the default) or
## "Modern", greyed with a tooltip unless the card rule is the Classic MTG
## rules, the one rule that reads it. Chosen, the record, the next visit and
## the adventure carry them; Randomize leaves them; the arrival says the
## card hold; and the screen stays whole at 1280 × 800 and at 800 × 600
## (1280 × 960 inside the window, the project's stretch), with the 1997 art
## and without it, with the Big buttons on.

var screen: EmbarkScreen
var _big: Variant


func before_each() -> void:
	AdventureSetup.forget()
	_big = Settings.get_value(WorldHud.BIG_SETTING, null)
	Settings.set_value(WorldHud.BIG_SETTING, true, false)
	screen = load("res://game/adventure/embark_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	AdventureSetup.forget()
	if _big == null:
		Settings.clear_value(WorldHud.BIG_SETTING)
	else:
		Settings.set_value(WorldHud.BIG_SETTING, _big, false)
	GameSkin.clear_caches()


func _find(node_name: String, under: Node = null) -> Node:
	return (under if under != null else screen).find_child(node_name, true, false)


func _names(option: OptionButton) -> Array[String]:
	var out: Array[String] = []
	for i in option.item_count:
		out.append(option.get_item_text(i))
	return out


func test_the_card_hold_is_chosen_at_the_embark() -> void:
	var hold := _find("CardHold") as OptionButton
	assert_not_null(hold, "the choice, in Your rules")
	assert_eq(_names(hold), ["1997 card hold limit", "Unlimited card hold"] as Array[String], "the owner's names")
	assert_eq(hold.selected, 0, "the 1997 limit by default")
	assert_string_contains(hold.tooltip_text, "500")
	assert_eq((_find("CardHoldWords") as Label).text, "Card hold")
	assert_true(_find("CampaignSettingsWindow").is_ancestor_of(hold), "[0.50.65] in the Campaign Settings")
	hold.select(1)
	hold.item_selected.emit(1)
	assert_eq(screen.setup.card_hold, AdventurePlayer.HOLD_UNLIMITED)
	assert_string_contains(hold.tooltip_text, "any number")
	screen.choose_card_hold("a bottomless sack")
	assert_eq(screen.setup.card_hold, AdventurePlayer.HOLD_UNLIMITED, "an odd one changes nothing")
	watch_signals(screen)
	(_find("HeroName") as LineEdit).text = "Ysolde Starfall"
	screen.embark()
	var record: Dictionary = get_signal_parameters(screen, "embarked")[0]
	assert_eq(String(record["card_hold"]), AdventurePlayer.HOLD_UNLIMITED, "the record carries it")
	assert_eq(AdventureSetup.restore([] as Array[String]).card_hold, AdventurePlayer.HOLD_UNLIMITED, "and the next visit")
	assert_string_contains(screen.summary(record), EmbarkScreen.HOLD_SUMMARY[AdventurePlayer.HOLD_UNLIMITED],
		"the arrival says so")
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	assert_eq(hero.card_hold, AdventurePlayer.HOLD_UNLIMITED, "the adventure plays by it")
	var plain := AdventureSetup.new()
	plain.player_name = "Ysolde Starfall"
	assert_string_contains(screen.summary(plain.resolve({})), EmbarkScreen.HOLD_SUMMARY[AdventurePlayer.HOLD_1997],
		"the 1997 limit said too")


func test_the_ban_list_is_chosen_at_the_embark_and_greyed_without_classic() -> void:
	var bans := _find("BanList") as OptionButton
	assert_not_null(bans, "the choice, in Your rules")
	assert_eq(_names(bans), ["1998 (the original game's)", "1998 + modern", "Modern"] as Array[String],
		"the owner's names")
	assert_eq(bans.selected, 1, "1998 + modern by default")
	assert_eq((_find("BanListWords") as Label).text, "Ban list")
	assert_true(_find("CampaignSettingsWindow").is_ancestor_of(bans), "[0.50.65] in the Campaign Settings")
	screen.open_settings()
	for i in 3:
		await get_tree().process_frame
	assert_lt(_find("CardRule").get_global_rect().end.y, bans.get_global_rect().position.y + 1.0,
		"under the card rule it belongs to")
	screen.close_settings()
	assert_true(bans.disabled, "greyed: the 1997 card rule reads no list")
	assert_string_contains(bans.tooltip_text, "Classic MTG rules", "and says why")
	screen.choose_card_rule(AdventurePlayer.RULE_CLASSIC)
	assert_false(bans.disabled, "the Classic rule reads it")
	assert_string_contains(bans.tooltip_text, "Mind Twist")
	bans.select(0)
	bans.item_selected.emit(0)
	assert_eq(screen.setup.ban_list, ClassicBans.OLD)
	assert_string_contains(bans.tooltip_text, "The Duelist")
	screen.choose_ban_list("Type 2")
	assert_eq(screen.setup.ban_list, ClassicBans.OLD, "an odd one changes nothing")
	screen.choose_card_rule(AdventurePlayer.RULE_SHIPPED)
	assert_true(bans.disabled, "greyed again")
	assert_eq(bans.selected, 0, "the choice kept")
	watch_signals(screen)
	(_find("HeroName") as LineEdit).text = "Ysolde Starfall"
	screen.choose_card_rule(AdventurePlayer.RULE_CLASSIC)
	screen.embark()
	var record: Dictionary = get_signal_parameters(screen, "embarked")[0]
	assert_eq(String(record["ban_list"]), ClassicBans.OLD, "the record carries it")
	assert_eq(AdventureSetup.restore([] as Array[String]).ban_list, ClassicBans.OLD, "and the next visit")
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	assert_eq(hero.ban_list, ClassicBans.OLD, "the adventure plays by it")


func test_a_second_visit_opens_on_both_and_randomize_leaves_them() -> void:
	screen.choose_card_hold(AdventurePlayer.HOLD_UNLIMITED)
	screen.choose_card_rule(AdventurePlayer.RULE_CLASSIC)
	screen.choose_ban_list(ClassicBans.MODERN)
	screen.setup.remember()
	var again: EmbarkScreen = load("res://game/adventure/embark_screen.tscn").instantiate()
	add_child_autofree(again)
	await get_tree().process_frame
	var hold := _find("CardHold", again) as OptionButton
	var bans := _find("BanList", again) as OptionButton
	assert_eq(hold.selected, 1, "Unlimited, as chosen before")
	assert_eq(bans.selected, 2, "Modern, as chosen before")
	assert_false(bans.disabled, "Classic remembered too")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 6:
		again.randomize_all(rng)
		assert_eq(again.setup.card_hold, AdventurePlayer.HOLD_UNLIMITED, "not drawn")
		assert_eq(again.setup.ban_list, ClassicBans.MODERN, "not drawn")
	assert_eq([hold.selected, bans.selected], [1, 2])


## THE SCREEN STAYS WHOLE with the four rules: at 1280 × 800 no column
## scrolls (with the skin as the machine has it — the 1997 skin on a dev
## checkout, none on CI) and the rules' column is whole with the art and the
## title face taken away; at 800 × 600 the window shows 1280 × 960 (the
## project's canvas-items stretch, aspect expand) and nothing scrolls.
func test_the_screen_stays_whole_with_the_four_rules() -> void:
	await _whole(screen, Vector2(1280, 800), "1280 × 800 with the skin as it is", true)
	await _whole(screen, Vector2(1280, 960), "800 × 600 with the skin as it is", true)
	GameSkin._texture_cache[EmbarkScreen.BACKGROUND_KEY] = null
	GameSkin._texture_cache["stat_buttons"] = null
	GameSkin._font_cache["font_title"] = null
	var bare: EmbarkScreen = load("res://game/adventure/embark_screen.tscn").instantiate()
	add_child_autofree(bare)
	await get_tree().process_frame
	bare.choose_card_rule(AdventurePlayer.RULE_CLASSIC)
	await _whole(bare, Vector2(1280, 800), "1280 × 800 without the art", false)
	await _whole(bare, Vector2(1280, 960), "800 × 600 without the art", false)


func _whole(on: EmbarkScreen, size: Vector2, how: String, every_column: bool) -> void:
	on.size = size
	for i in 3:
		await get_tree().process_frame
	var columns := _find("Columns", on) as Control
	var scroll := columns.get_parent() as ScrollContainer
	var magic := _find("MagicPanel", on) as Control
	if every_column:
		assert_false(scroll.get_v_scroll_bar().visible, "%s: the columns do not scroll" % how)
		assert_lte(columns.get_combined_minimum_size().y, scroll.size.y, "%s: they fit" % how)
	assert_false(scroll.get_h_scroll_bar().visible, "%s: nothing scrolls sideways" % how)
	assert_lte(magic.get_combined_minimum_size().y, scroll.size.y, "%s: the rules' column fits" % how)
	# [0.50.65] The rules in the Campaign Settings' window, the window on
	# the screen, the lists whole.
	on.open_settings()
	for i in 3:
		await get_tree().process_frame
	var window := _find("CampaignSettingsWindow", on) as Control
	assert_true(Rect2(Vector2.ZERO, on.size).encloses(window.get_global_rect()), "%s: the window on the screen" % how)
	for name in ["LifeRuleRow", "CardRuleRow", "BanListRow", "CardHoldRow"]:
		var row := _find(name, on) as Control
		assert_true(window.get_global_rect().encloses(row.get_global_rect()), "%s: %s in its window" % [how, name])
	for name in ["LifeRule", "CardHold", "BanList"]:
		var option := _find(name, on) as OptionButton
		assert_lte(option.get_combined_minimum_size().x, option.size.x + 0.5, "%s: %s whole" % [how, name])
	on.close_settings()


## Help's Embark page tells both rules by their names, and no Help page
## tells of "one deck for all duels" (the owner, 2026-10-28).
func test_help_tells_the_card_hold_and_the_ban_list() -> void:
	var text := HelpPages.all_text()
	for words in ["Card hold sets how many cards your magic bag holds", "1997 card hold limit: 500",
			"Unlimited card hold: any number", "Ban list, under the card rule",
			"1998 (the original game's)", "1998 + modern", "Modern: today's Vintage lists",
			"With a full bag (under the 1997 card hold limit)"]:
		assert_string_contains(text, words)
	assert_false(text.to_lower().contains("one deck for all"), "the dropped clue told nowhere")
	assert_false(text.contains("colour"), "Help says color")
