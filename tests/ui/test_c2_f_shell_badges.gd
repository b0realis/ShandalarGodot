extends GutTest
## A SET BADGE CLICKED WHILE THE CARD POOL STILL BUILDS (bug campaign
## 2026-10-12, finding r2-7). The title stands seconds before the pool is
## in — on its thread — and is meant never to wait for it; but the badge's
## popup counted the set's cards in this game, which joined the build: the
## window froze until it ended (4.8 s on the desk with five packs, longer
## on a handheld). While the pool builds, the popup leaves the count out
## and says so.


func after_each() -> void:
	CardRegistry.ensure_loaded()


func test_describe_does_not_wait_for_a_building_pool() -> void:
	CardRegistry.unload()
	assert_true(CardRegistry.load_in_background(), "a build is in flight")
	var text := SetBadges.describe("arn")
	assert_true(CardRegistry.is_loading() or not CardRegistry.poll(),
		"describe() returned without joining the build")
	assert_string_contains(text, "still loading", "the popup says why there is no count")
	assert_string_contains(text, "December 1993", "and still gives the date")
	CardRegistry.ensure_loaded()
	assert_false(SetBadges.describe("arn").contains("still loading"), "once in, the count is back")


func test_the_title_badge_opens_its_popup_while_the_pool_builds() -> void:
	var menu: Control = load("res://game/main.tscn").instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	CardRegistry.unload()
	assert_true(CardRegistry.load_in_background())
	var row := menu.find_child("OriginalSets", true, false)
	var t := Time.get_ticks_msec()
	row.set_clicked.emit("arn")
	var took := Time.get_ticks_msec() - t
	assert_true(CardRegistry.is_loading() or not CardRegistry.poll(), "the click did not join the build")
	assert_lt(took, 500, "the click answered at once (%d ms)" % took)
	var popup := UiChrome.open_popup(menu)
	assert_not_null(popup, "the set's window opened")
	CardRegistry.ensure_loaded()
