extends GameTest
## The shared `_ability` helper (cards/sets/fem/_rules.gd) writes the text a
## player reads in the ability menu and the game log. It used to print
## "{R}, : this creature gets +1/+0 …" for a cost without {T}, and ": …"
## when the whole cost was a sacrifice or life paid by a later builder —
## found by the Pack 8 duel audit on 2026-10-03 (Spitting Drake, Kyscu
## Drake, Mischievous Poltergeist).

const F := preload("res://cards/sets/fem/_rules.gd")


func _text(cost: String, taps: bool) -> String:
	return F._ability(cost, taps, PumpEffect.new(1, 0).self_buff()).text


func test_a_mana_cost_without_tap() -> void:
	assert_eq(_text("{R}", false), "{R}: this creature gets +1/+0 until end of turn")


func test_tap_alone() -> void:
	assert_eq(_text("", true), "{T}: this creature gets +1/+0 until end of turn")


func test_mana_and_tap() -> void:
	assert_eq(_text("{1}", true), "{1}, {T}: this creature gets +1/+0 until end of turn")


func test_no_printed_cost_has_no_stray_colon() -> void:
	assert_eq(_text("", false), "this creature gets +1/+0 until end of turn")


func test_mischievous_poltergeist_reads_its_life_cost() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	var data := CardRegistry.get_card("Mischievous Poltergeist")
	CardPacks.set_enabled("pack-8", false)
	assert_not_null(data)
	var ability: ActivatedAbility = data.activated_abilities[0]
	assert_eq(ability.text, "Pay 1 life: Regenerate this creature.")
	assert_eq(ability.life_cost, 1)
