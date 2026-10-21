extends GutTest
## A PROBABILITY OF TWO (bug hunt 2026-10-21, ai; the morning review's
## "Deck Lab accepts profile knobs out of range").
##
## [member AiProfile.mistake_chance] and [member AiProfile.aggression] are
## documented as probabilities in [0, 1]. The Lab checked a knob's NAME and
## its TYPE (2026-09-26) but not its range: `--profile-a
## wizard:mistake_chance=2` played a run of a pilot that fumbles every
## action, and the report's settings line printed it as if it were a
## setting. `--sweep` and `--null` took the same values. All three refuse a
## value outside the documented range now, before a game is played.

const DUEL := ["--deck-a", "big_green.deck", "--deck-b", "white_knights.deck"]


func _parse(args: Array) -> Dictionary:
	return autofree(load("res://DeckLab/simulate.gd").new())._parse_args(PackedStringArray(args))


func test_a_profile_probability_outside_zero_to_one_is_refused() -> void:
	assert_string_contains(str(_parse(DUEL + ["--profile-a", "wizard:mistake_chance=2"]).get("error", "")),
		"mistake_chance")
	assert_string_contains(str(_parse(DUEL + ["--profile-b", "wizard:aggression=-0.5"]).get("error", "")),
		"aggression")
	var good := _parse(DUEL + ["--profile-a", "wizard:mistake_chance=0.25,aggression=1"])
	assert_false(good.has("error"), str(good.get("error", "")))


func test_a_sweep_probability_outside_zero_to_one_is_refused() -> void:
	var lab = load("res://DeckLab/simulate.gd")
	assert_string_contains(str(lab.parse_sweep("mistake_chance=0,1.5").get("error", "")),
		"mistake_chance takes a value from 0")
	assert_false(lab.parse_sweep("aggression=0.3,0.7").has("error"), "in range: a sweep")
	assert_eq(lab.knob_range_error("counter_threshold", "40"), "", "a knob with no range")
