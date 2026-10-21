extends GameTest
## THE SOUL WARDEN THROWN UNDER A CRAW WURM AT 20 (bug hunt 2026-10-21, ai;
## the morning review's "It chump-blocked a Craw Wurm with Soul Warden at
## 20 life").
##
## The combat study ([AiCombatStudy], Sorcerer and Wizard) charges a
## throwaway block — every blocker dies, the attacker lives — twice the
## bodies' worth while the defender stays above its panic line ([member
## AiProfile.chump_threshold]): "a last resort, not a way to cash every
## small body in for life while comfortably ahead of lethal". The charge
## alone left a small body cheaper than a big hit: a Soul Warden at three
## times 2.0 against six damage at 20 life (7.8), and both rungs chumped.
## Above the panic line the face damage a throwaway block stops is now
## counted as taken, so the block never wins there; at the panic line the
## chump is still made (the control).


func before_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, id == "pack-9")


func after_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func after_each() -> void:
	g = null


## Our Soul Warden at [param life]; their Craw Wurm attacks; the blocks
## [param profile] declares.
func _blocks(profile: AiProfile, life: int) -> Dictionary:
	before_each()
	profile.mistake_chance = 0.0
	var ai := AiPlayer.new(0, profile)
	g.set_agent(0, ai)
	put_battlefield(0, "Soul Warden")
	var wurm := put_battlefield(1, "Craw Wurm")
	g.players[0].life = life
	var guard := 0
	while not (g.active_player == 1 and g.awaiting_attackers) and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.declare_attackers(1, [wurm.id]))
	guard = 0
	while not g.awaiting_blockers and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	ai.act(g)
	assert_false(g.awaiting_blockers)
	return g.combat.blocks


func test_no_rung_chumps_a_wurm_at_twenty() -> void:
	for profile in [AiProfile.apprentice(), AiProfile.magician(),
			AiProfile.sorcerer(), AiProfile.wizard()]:
		assert_true(_blocks(profile, 20).is_empty(),
			"%s: six at twenty is not worth the Warden" % (profile as AiProfile).profile_name)


## THE CONTROL: at 7 the Wurm's six leaves 1, under the panic line — the
## Warden blocks.
func test_under_the_panic_line_the_warden_still_blocks() -> void:
	for profile in [AiProfile.sorcerer(), AiProfile.wizard()]:
		assert_eq(_blocks(profile, 7).size(), 1,
			"%s: the chump that keeps us off 1" % (profile as AiProfile).profile_name)
