extends GameTest
## Campaign 2026-10-12 (b3-7) — counters come off through remove_counters.
##
## Venarian Gold, Living Artifact, Cocoon and Tetravus took their counters
## off with add_counters(..., -1): the last one left a counter "at 0" on
## the card ("Kobold Drill Sergeant has 0 sleep counters"), the log said
## "gets -1 counter(s)", and no COUNTERS_REMOVED event was sent.
## MtgGame.add_counters now refuses a count of 0 or less, and the four
## cards use MtgGame.remove_counters.

var removed: Array = []


func before_each() -> void:
	super()
	removed = []
	g.event_occurred.connect(_heard)
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null


func _heard(e: GameEvent) -> void:
	if e.type == Mtg.EventType.COUNTERS_REMOVED:
		removed.append(e.data.duplicate())


func _log_mentions(text: String) -> bool:
	for line in g.log_lines:
		if String(line).contains(text): return true
	return false


func _to_upkeep_of(pid: int) -> void:
	var guard := 0
	while not (g.active_player == pid and g.current_step() == Mtg.Step.UPKEEP) and guard < 400:
		_advance_once()
		guard += 1
	resolve_stack()


# ------------------------------------------------------------- engine --

func test_add_counters_refuses_zero_and_negative_counts() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var lines := g.log_lines.size()
	g.add_counters(bears, "+1/+1", 0)
	g.add_counters(bears, "+1/+1", -2)
	assert_false(bears.counters.has("+1/+1"), "no counter key appears")
	assert_eq(g.log_lines.size(), lines, "nothing is logged")
	g.add_counters(bears, "+1/+1", 2)
	g.add_counters(bears, "+1/+1", -1)
	assert_eq(int(bears.counters["+1/+1"]), 2, "a negative count is not a removal")
	g.recalculate()
	assert_eq(bears.cur_power, 4)


# ------------------------------------------------------------- cards --

func test_venarian_gold_takes_the_last_sleep_counter_off_cleanly() -> void:
	var host := put_battlefield(1, "Grizzly Bears")
	var gold := give_hand(0, "Venarian Gold")
	g.attach_aura_from_anywhere(gold, host, 0)
	resolve_stack()
	g.add_counters(host, "sleep", 1)
	_to_upkeep_of(1)
	assert_false(host.counters.has("sleep"), "the last sleep counter is gone, not left at 0")
	assert_false(_log_mentions("0 sleep counters"))
	assert_false(_log_mentions("gets -1"))
	assert_eq(removed.size(), 1, "one COUNTERS_REMOVED event")
	if removed.size() == 1:
		assert_eq(removed[0]["kind"], "sleep")
		assert_eq(int(removed[0]["removed"]), 1)
		assert_eq(int(removed[0]["remaining"]), 0)


func test_living_artifact_spends_its_last_vitality_counter_cleanly() -> void:
	var rock := put_battlefield(0, "Sol Ring")
	var aura := give_hand(0, "Living Artifact")
	g.attach_aura_from_anywhere(aura, rock, 0)
	resolve_stack()
	g.add_counters(aura, "vitality", 1)
	g.players[0].life = 10
	_to_upkeep_of(0)
	assert_false(aura.counters.has("vitality"), "the last vitality counter is gone")
	assert_eq(g.players[0].life, 11, "one counter, one life")
	assert_eq(removed.size(), 1)
	assert_false(_log_mentions("gets -1"))


func test_cocoon_counts_down_its_pupa_counters_cleanly() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var cocoon := give_hand(0, "Cocoon")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, cocoon, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(int(cocoon.counters.get("pupa", 0)), 3)
	for left in [2, 1, 0]:
		advance_to_next_turn()
		advance_to_next_turn()
		if left > 0:
			assert_eq(int(cocoon.counters.get("pupa", 0)), left)
		else:
			assert_false(cocoon.counters.has("pupa"), "no pupa counter left at 0")
			assert_eq(cocoon.zone, Mtg.Zone.BATTLEFIELD, "it hatches only when it can't remove one")
	assert_eq(removed.size(), 3, "three removals announced")
	assert_false(_log_mentions("0 pupa counters"))
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(cocoon.zone, Mtg.Zone.GRAVEYARD, "then it hatches")
	assert_true(bears.has_keyword(Mtg.Keyword.FLYING))


func test_tetravus_sends_out_every_counter_cleanly() -> void:
	var tetravus := put_battlefield(0, "Tetravus")
	if not tetravus.counters.has("+1/+1"):
		g.add_counters(tetravus, "+1/+1", 3)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.active_player, 0)
	assert_false(tetravus.counters.has("+1/+1"), "every counter sent out, none left at 0")
	var tokens := 0
	for inst in g.players[0].battlefield:
		if inst.is_token: tokens += 1
	assert_eq(tokens, 3, "three Tetravites")
	var announced := 0
	for row in removed:
		if row["kind"] == "+1/+1": announced += int(row["removed"])
	assert_eq(announced, 3, "the removal is announced")
	assert_false(_log_mentions("gets -3"))
