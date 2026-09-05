extends GutTest
## Unit tests for ManaCost parsing and ManaPool payment — pure logic, no
## game required.


func test_parse_simple_colored() -> void:
	var cost := ManaCost.parse("{R}")
	assert_eq(cost.colored[Mtg.ManaColor.R], 1)
	assert_eq(cost.generic, 0)
	assert_eq(cost.mana_value(), 1)


func test_parse_mixed_cost() -> void:
	var cost := ManaCost.parse("{2}{W}{W}")
	assert_eq(cost.generic, 2)
	assert_eq(cost.colored[Mtg.ManaColor.W], 2)
	assert_eq(cost.mana_value(), 4)
	assert_eq(cost.color_mask(), Mtg.ManaColor.W)


func test_parse_x_cost() -> void:
	var cost := ManaCost.parse("{X}{R}")
	assert_true(cost.has_x)
	assert_eq(cost.mana_value(), 1)   # X counts as 0 unresolved (CR 203.3b)


func test_parse_empty_is_free() -> void:
	var cost := ManaCost.parse("")
	assert_eq(cost.mana_value(), 0)


func test_gold_cost_color_mask() -> void:
	var cost := ManaCost.parse("{W}{U}")
	assert_eq(cost.color_mask(), Mtg.ManaColor.W | Mtg.ManaColor.U)


func test_pool_pay_colored_and_generic() -> void:
	var pool := ManaPool.new()
	pool.add(Mtg.ManaColor.W, 2)
	pool.add(Mtg.ManaColor.G, 2)
	var cost := ManaCost.parse("{2}{W}{W}")
	assert_true(pool.can_pay(cost))
	pool.pay(cost)
	assert_eq(pool.total(), 0)


func test_pool_refuses_wrong_colors() -> void:
	var pool := ManaPool.new()
	pool.add(Mtg.ManaColor.G, 3)
	assert_false(pool.can_pay(ManaCost.parse("{R}")),
		"three green cannot pay {R}")
	assert_true(pool.can_pay(ManaCost.parse("{2}")))


func test_pool_colorless_pays_generic_only() -> void:
	var pool := ManaPool.new()
	pool.add(Mtg.ManaColor.C, 2)
	assert_true(pool.can_pay(ManaCost.parse("{2}")))
	assert_false(pool.can_pay(ManaCost.parse("{W}")),
		"colorless cannot pay a colored requirement")


func test_pool_pay_with_x() -> void:
	var pool := ManaPool.new()
	pool.add(Mtg.ManaColor.R, 1)
	pool.add(Mtg.ManaColor.G, 3)
	var cost := ManaCost.parse("{X}{R}")
	assert_true(pool.can_pay(cost, 3))
	assert_false(pool.can_pay(cost, 4))
	pool.pay(cost, 3)
	assert_eq(pool.total(), 0)


func test_pool_clear() -> void:
	var pool := ManaPool.new()
	pool.add(Mtg.ManaColor.U, 5)
	pool.clear()
	assert_eq(pool.total(), 0)


func test_a_usage_key_named_twice_counts_its_restricted_mana_once() -> void:
	# `_spendable` used to add a restricted bucket once per mention of its
	# key, so `["creature", "creature"]` saw two mana where there was one:
	# `can_pay` said yes to a cost `pay` could not finish, and `pay`'s
	# generic loop was bounded only by an assert — a frozen game in a
	# release build (2026-09-02).
	var pool := ManaPool.new()
	pool.add_restricted(Mtg.ManaColor.G, 1, "creature")
	var cost := ManaCost.parse("{2}")
	assert_false(pool.can_pay(cost, 0, ["creature", "creature"]),
		"one restricted mana is one mana however often its key is named")
	assert_true(pool.can_pay(ManaCost.parse("{1}"), 0, ["creature", "creature"]))
	pool.pay(ManaCost.parse("{1}"), 0, ["creature", "creature"])
	assert_eq(pool.total(), 0, "and paying it once empties the pool")
