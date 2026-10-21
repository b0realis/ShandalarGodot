extends GutTest
## THE SECOND BUG HUNT (2026-10-21), the screens: Test hands' `Clear all`
## after `Edit test`.
##
## WAS: `Clear all` promises "the starting lives" — the Magic Battle
## screen's — and gave them only on a bench opened from Magic Battle. A
## test duel's config carries the position's lives (`DuelConfig.for_test`),
## and `Edit test` hands that config back to a new bench, so there
## `Clear all` reset each life to the last test's: build a test at 9 and
## 7 life, play it, Edit test, Clear all — 9 and 7 again, test after test.
## NOW the test config remembers the lives it was built under
## (`DuelConfig.setup_lives`, read through `starting_lives`), however many
## tests ago that was.

var bench: TestHandsScreen
var _handed: Array[Node] = []


func before_each() -> void:
	Settings.clear_value(TestHandsScreen.LAST_KEY)
	Settings.clear_value(TestHandsScreen.SAVED_KEY)
	var config := DuelConfig.vs_ai_default(AiProfile.wizard())
	config.lives.assign([20, 18])
	bench = load("res://game/test_hands_screen.tscn").instantiate()
	bench.config = config
	add_child_autofree(bench)
	await get_tree().process_frame


func after_each() -> void:
	for node in _handed:
		if is_instance_valid(node):
			node.queue_free()
	_handed.clear()
	Settings.clear_value(TestHandsScreen.LAST_KEY)
	Settings.clear_value(TestHandsScreen.SAVED_KEY)
	SetupScreen.forget_choices()
	await get_tree().process_frame


## `Go test!` from [param from], then `Edit test`: the bench it reopened.
func _play_and_edit(from: TestHandsScreen) -> TestHandsScreen:
	var started: Array[Node] = []
	from.test_started.connect(func(duel: Control) -> void: started.append(duel))
	from.go_test()
	assert_eq(started.size(), 1, "Go test! started one duel")
	if started.is_empty():
		return null
	var duel := started[0] as DuelScreen
	_handed.append(duel)
	await get_tree().process_frame
	var next: Array[Node] = []
	duel.handed_over.connect(func(screen: Control) -> void: next.append(screen))
	duel.edit_test()
	assert_eq(next.size(), 1, "Edit test opened the bench")
	if next.is_empty():
		return null
	_handed.append(next[0])
	await get_tree().process_frame
	return next[0] as TestHandsScreen


func test_clear_all_on_a_fresh_bench_takes_magic_battles_lives() -> void:
	bench.test_position.lives[0] = 9
	bench._clear_all()
	assert_eq(bench.test_position.lives, [20, 18] as Array[int])


func test_clear_all_after_edit_test_takes_magic_battles_lives() -> void:
	bench.test_position.lives[0] = 9
	bench.test_position.lives[1] = 7
	var again := await _play_and_edit(bench)
	if again == null:
		return
	assert_eq(again.test_position.lives, [9, 7] as Array[int], "Edit test: the test as it was")
	again._clear_all()
	assert_eq(again.test_position.lives, [20, 18] as Array[int],
		"Clear all: Magic Battle's starting lives, not the last test's")


func test_the_starting_lives_survive_test_after_test() -> void:
	bench.test_position.lives[0] = 9
	var second := await _play_and_edit(bench)
	if second == null:
		return
	second.test_position.lives[1] = 3
	var third := await _play_and_edit(second)
	if third == null:
		return
	assert_eq(third.test_position.lives, [9, 3] as Array[int], "the second test as it was")
	third._clear_all()
	assert_eq(third.test_position.lives, [20, 18] as Array[int])


func test_a_test_config_still_plays_its_positions_lives() -> void:
	var position := DuelPosition.new()
	position.lives[0] = 4
	var test := bench.config.for_test(position, 7)
	assert_eq(test.lives, [4, 20] as Array[int], "the duel's lives are the position's")
	assert_eq(test.starting_lives(), [20, 18] as Array[int], "the bench's are Magic Battle's")
	assert_eq(bench.config.starting_lives(), [20, 18] as Array[int], "a plain config: its own")
