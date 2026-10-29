extends GutTest
## THE POISON COUNTERS ON THE DUEL'S LIFE REGISTER (the polish pass,
## 2026-10-28). P5 drew the counter as our own picture ([PoisonCounters]:
## one sprite per counter on 1997's grid, the life number drawn again on
## top); the duel screen hangs one on each seat's life register, under the
## `N/10` clock, and keeps its count with the engine's.

var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	await get_tree().process_frame


func test_each_register_carries_its_marks_under_the_number() -> void:
	assert_eq(screen._poison_marks.size(), 2, "one per seat")
	for pid in 2:
		var marks: PoisonCounters = screen._poison_marks[pid]
		assert_not_null(marks)
		assert_eq(marks.get_parent(), screen._life_buttons[pid], "on the life register")
		assert_eq(marks.get_index(), 0, "first child: under the clock and every badge")
		assert_eq(marks.count, 0, "no counters, nothing drawn")


func test_n_counters_show_n_marks_at_both_seats() -> void:
	var g: MtgGame = screen.game
	g.players[0].poison = 3
	g.players[1].poison = 7
	screen._refresh()
	assert_eq(screen._poison_marks[0].count, 3)
	assert_eq(screen._poison_marks[1].count, 7)
	assert_eq(screen._poison_labels[0].text, "3/10", "control: the clock says the same")
	g.players[0].poison = 0
	screen._refresh()
	assert_eq(screen._poison_marks[0].count, 0, "and they go with the counters")
