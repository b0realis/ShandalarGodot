extends GameTest
## Gap review 2026-11-10, r1b-2: [method EffectIntent.damage_on] and
## [method EffectIntent.kills_on] read what ONE target of a divided spell
## takes — Pyrotechnics' announced share (CR 601.2d), Fireball's even split
## over the N targets chosen ("divided evenly, rounded down").


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	super()


func after_each() -> void:
	g = null


func _their_main() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)


## Fireball X=7 at three targets: 2 each (floor(7/3)); one target takes all 7.
func test_fireball_shares_evenly() -> void:
	var angel := put_battlefield(0, "Serra Angel")
	var bears := put_battlefield(0, "Grizzly Bears")
	_their_main()
	var ball := give_hand(1, "Fireball")
	add_mana(1, Mtg.ManaColor.R, 10)
	assert_ok(g.cast_spell(1, ball, [TargetRef.card(angel), TargetRef.card(bears),
		TargetRef.player(0)], 7))
	var top: StackItem = g.stack.back()
	var intent := EffectIntent.read(top.effects, "Fireball")
	assert_true(intent.divided_evenly)
	assert_false(intent.divided_shares)
	for t in top.targets:
		assert_eq(intent.damage_on(t, top.x_value, top.targets.size()), 2)
	assert_eq(intent.damage_on(top.targets[0], top.x_value, 1), 7, "one target takes the whole X")
	assert_eq(intent.damage_on(top.targets[0], top.x_value), 7, "no count given: the whole X, as before")
	assert_false(intent.kills_on(angel, top.targets[0], top.x_value, top.targets.size()))
	assert_true(intent.kills_on(bears, top.targets[1], top.x_value, top.targets.size()))
	assert_eq(intent.damage_from(top, top.targets[1]), 2, "the stack item's own reading")


## Pyrotechnics: 1 at the Angel, 3 at the Bears — each its announced share.
func test_pyrotechnics_shares_as_announced() -> void:
	var angel := put_battlefield(0, "Serra Angel")
	var bears := put_battlefield(0, "Grizzly Bears")
	_their_main()
	var pyro := give_hand(1, "Pyrotechnics")
	add_mana(1, Mtg.ManaColor.R, 5)
	assert_ok(g.cast_spell(1, pyro, [TargetRef.card(angel, 1), TargetRef.card(bears, 3)]))
	var top: StackItem = g.stack.back()
	var intent := EffectIntent.read(top.effects, "Pyrotechnics")
	assert_true(intent.divided_shares)
	assert_eq(intent.damage_on(top.targets[0], 0, 2), 1)
	assert_eq(intent.damage_on(top.targets[1], 0, 2), 3)
	assert_false(intent.kills_on(angel, top.targets[0], 0, 2))
	assert_true(intent.kills_on(bears, top.targets[1], 0, 2))
	assert_eq(intent.damage_from(top, top.targets[0]), 1)


## An undivided spell reads as before: a Bolt's 3 at its one target.
func test_an_undivided_spell_reads_its_damage() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	_their_main()
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R, 1)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bears)]))
	var top: StackItem = g.stack.back()
	var intent := EffectIntent.read(top.effects, "Lightning Bolt")
	assert_false(intent.divided_evenly)
	assert_eq(intent.damage_from(top, top.targets[0]), 3)
	assert_true(intent.kills_on(bears, top.targets[0], 0, 1))
