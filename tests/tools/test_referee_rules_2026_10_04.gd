extends GutTest
## THE REFEREE'S `--rules` (2026-10-04): the decision bridge's
## `Env(rules=...)` was refused with exit 2 — the referee had no switch for
## the rules forks. `--rules PRESET` names one of the Options screen's
## presets (RulesOptions.PRESETS: modern, modern_mana_burn, fifth); unset,
## the standard table (modern rules, mana burn on). `hello.rules` says
## which, the duel plays under it (the view's `presentation.rules` carries
## the forks), a hosted table sends it with its host command, and a joined
## table plays its host's rules — `--rules` there is refused.

const REFEREE := "res://DeckLab/referee.gd"
const DECKS := ["--deck-a", "big_green.deck", "--deck-b", "white_knights.deck", "--seed", "5"]

var _lines: Array = []


func before_each() -> void:
	_lines.clear()


## The referee with a pipe that closes at once: the first decision is
## conceded (`reason: eof`), which is a whole duel's worth of lines.
func _referee():
	var ref = autofree(load(REFEREE).new())
	ref.writer = func(line: String) -> void: _lines.append(JSON.parse_string(line))
	ref.reader = func() -> Variant: return null
	return ref


func _of(type: String) -> Array:
	return _lines.filter(func(line: Variant) -> bool: return line is Dictionary and line.get("type", "") == type)


func test_a_fifth_edition_duel_says_so_and_plays_under_it() -> void:
	var ref = _referee()
	assert_eq(ref._main(PackedStringArray(DECKS + ["--rules", "fifth"])), 0)
	var hello: Dictionary = _of("hello")[0]
	assert_eq(hello.rules, "fifth")
	var decision: Dictionary = _of("decision")[0]
	var rules: Dictionary = decision.view.presentation.rules
	assert_true(bool(rules.mana_burn), "Fifth Edition burns unspent mana")
	assert_true(bool(rules.damage_prevention_window), "and holds the damage-prevention window")
	assert_true(bool(rules.life_checked_at_phase_end))
	assert_eq(_of("result")[0].reason, "eof", "the duel ran to its end")


func test_the_default_is_the_standard_table() -> void:
	var ref = _referee()
	assert_eq(ref._main(PackedStringArray(DECKS)), 0)
	assert_eq(_of("hello")[0].rules, RulesOptions.DEFAULT_PRESET)
	var rules: Dictionary = _of("decision")[0].view.presentation.rules
	assert_true(bool(rules.mana_burn), "mana burn on, as every host's table")
	assert_false(bool(rules.damage_prevention_window), "modern rules otherwise")


func test_modern_turns_mana_burn_off_and_the_plan_names_it() -> void:
	var ref = _referee()
	assert_eq(ref._main(PackedStringArray(DECKS + ["--rules", "MODERN", "--dry-run"])), 0)
	assert_eq(_lines[0].rules, "modern", "the plan names it, any case")
	_lines.clear()
	assert_eq(ref._main(PackedStringArray(DECKS + ["--rules", "modern"])), 0)
	assert_false(bool(_of("decision")[0].view.presentation.rules.mana_burn))


func test_an_unknown_preset_and_a_joined_table_are_refused() -> void:
	var ref = _referee()
	assert_eq(ref._main(PackedStringArray(DECKS + ["--rules", "fith"])), 2)
	var error: Dictionary = _lines[0].error
	assert_true(String(error.message).contains("unknown rules 'fith'"))
	assert_eq(error.flag, "--rules")
	assert_eq(Array(error.presets), ["modern", "modern_mana_burn", "fifth"])
	assert_true(Array(error.get("suggestions", [])).has("fifth"))
	_lines.clear()
	assert_eq(ref._main(PackedStringArray(["--join", "sglan1:nothing", "--deck", "big_green.deck", "--rules", "fifth"])), 2)
	assert_true(String(_lines[0].error.message).contains("--rules is the host's to choose"))
	assert_eq(ref.table_rules("fifth").forks.damage_prevention_window, true, "the host command's table rules")
	assert_true(SgTableRules.valid(ref.table_rules("")))
