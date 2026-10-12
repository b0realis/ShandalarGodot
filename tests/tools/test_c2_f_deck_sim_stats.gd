extends GutTest
## Robustness campaign 2026-10-12 (r1-5) — the Deck Lab's median.
## An even number of games has two middle values; the median is their
## mean, rounded to a whole turn, not the upper one alone.


func _records(turns: Array) -> Array:
	var out: Array = []
	for t in turns:
		out.append({"stalled": false, "a_on_play": true, "a_won": true, "turns": t})
	return out


func test_an_even_count_takes_the_mean_of_the_two_middle_values() -> void:
	assert_eq(SimStats.summarize(_records([13, 50])).median_turns, 32, "(13 + 50) / 2 = 31.5, rounded")
	assert_eq(SimStats.summarize(_records([9, 12, 14, 40])).median_turns, 13)
	assert_eq(SimStats.summarize(_records([10, 12])).median_turns, 11)


func test_an_odd_count_is_unchanged() -> void:
	assert_eq(SimStats.summarize(_records([9, 12, 15])).median_turns, 12)
	assert_eq(SimStats.summarize(_records([7])).median_turns, 7)


func test_still_a_whole_number_after_a_json_round_trip() -> void:
	var records: Array = JSON.parse_string(JSON.stringify(_records([12, 9, 15, 20])))
	var s := SimStats.summarize(records)
	assert_eq(typeof(s.median_turns), TYPE_INT)
	assert_eq(s.median_turns, 14, "(12 + 15) / 2 = 13.5, rounded")
