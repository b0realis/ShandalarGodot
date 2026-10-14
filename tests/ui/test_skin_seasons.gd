extends GutTest
## The seasons' card backs ([constant GameSkin.SEASON_BACKS]): for the week
## up to Halloween and the two weeks over Christmas and the New Year every
## card back is one of the two pictures in `game/art/`; on any other day
## it is what it always was. The suite itself runs on a day in no season
## (`tests/support/pin_calendar.gd`); each test here sets its own day and
## puts that one back.

var _pinned: Dictionary


func before_each() -> void:
	_pinned = GameSkin.season_date.duplicate()


func after_each() -> void:
	GameSkin.season_date = _pinned


func test_the_seasons_by_the_calendar() -> void:
	assert_eq(GameSkin.season_for(10, 24), "")
	assert_eq(GameSkin.season_for(10, 25), "halloween")
	assert_eq(GameSkin.season_for(10, 31), "halloween")
	assert_eq(GameSkin.season_for(11, 1), "")
	assert_eq(GameSkin.season_for(12, 20), "")
	assert_eq(GameSkin.season_for(12, 21), "christmas")
	assert_eq(GameSkin.season_for(12, 31), "christmas")
	assert_eq(GameSkin.season_for(1, 1), "christmas")
	assert_eq(GameSkin.season_for(1, 3), "christmas")
	assert_eq(GameSkin.season_for(1, 4), "")


func test_a_week_and_two_weeks_a_year() -> void:
	var days := {"halloween": 0, "christmas": 0, "": 0}
	var lengths := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	for month in 12:
		for day in lengths[month]:
			days[GameSkin.season_for(month + 1, day + 1)] += 1
	assert_eq(days.halloween, 7)
	assert_eq(days.christmas, 14)


func test_the_suite_runs_on_a_day_in_no_season() -> void:
	assert_false(_pinned.is_empty(), "the runner pinned the calendar")
	assert_eq(GameSkin.season(), "")


func test_in_season_every_back_is_the_seasons_own() -> void:
	GameSkin.season_date = {"month": 10, "day": 31}
	assert_eq(GameSkin.texture("card_back"), GameSkin.our_art("card_back_moon"))
	GameSkin.season_date = {"month": 12, "day": 25}
	var holly := GameSkin.our_art("card_back_holly")
	assert_eq(GameSkin.texture("card_back"), holly)
	var preview := CardPreview.new()
	add_child_autofree(preview)
	preview.show_back()
	var box := preview._back.get_theme_stylebox("panel") as StyleBoxTexture
	assert_not_null(box, "the big card's back is a picture, skin or no skin")
	if box != null:
		assert_eq(box.texture, holly)
	assert_null(GameSkin.texture("no_such_skin_asset"), "nothing else changes")
	assert_null(GameSkin.our_art("card_back"),
		"the year-round back is still the skin's business")


func test_out_of_season_the_back_is_what_it_was() -> void:
	GameSkin.season_date = {"month": 10, "day": 31}
	var seasonal := GameSkin.texture("card_back")
	GameSkin.season_date = {"month": 6, "day": 15}
	assert_ne(GameSkin.texture("card_back"), seasonal)


func test_the_two_backs_are_card_shaped() -> void:
	for key in GameSkin.SEASON_BACKS.values():
		var tex := GameSkin.our_art(String(key))
		assert_not_null(tex, key)
		if tex == null:
			continue
		assert_eq(Vector2i(tex.get_width(), tex.get_height()), Vector2i(342, 479), key)
		var aspect := float(tex.get_width()) / tex.get_height()
		var card := CardPreview.SIZE.x / CardPreview.SIZE.y
		assert_almost_eq(aspect, card, card * 0.02, "%s is a card's shape" % key)
