extends GameTest
## Pack 10 engine package E3 — A SIZE THAT READS A LIFE TOTAL (Serra
## Avatar: "power and toughness are each equal to your life total").
##
## A life total is not the board, and nothing recalculated when one changed:
## an Avatar whose controller dropped from 7 to 4 while it blocked a 5/5
## was judged by the combat damage step's state-based check with its old
## toughness of 7 and survived. A static flagged
## [method StaticAbility.reading_life] now makes every life change —
## [method MtgGame.adjust_life] and a player's damage — recompute the
## characteristics first ([method MtgGame._refresh_after_life_change]), so
## the same check sees a 4/4 with 5 damage (CR 604.3, 704.5f-g).


static func _life_size(game: MtgGame, source: CardInstance) -> void:
	var life: int = game.players[source.controller_id].life
	source.cur_power = life
	source.cur_toughness = life


static func _avatar() -> CardData:
	var c := CardData.new("Test Avatar", "{4}{W}{W}{W}", Mtg.CardType.CREATURE).pt(0, 0) \
		.static_ability(StaticAbility.new(_life_size,
			"Power and toughness are each equal to your life total.") \
			.setting_base_pt().reading_life())
	c.characteristic_definition = _life_size
	return c


static func _body(power: int, toughness: int) -> CardData:
	return CardData.new("Test Body %d/%d" % [power, toughness], "{3}",
		Mtg.CardType.CREATURE).pt(power, toughness)


func _pt(inst: CardInstance) -> Array:
	return [inst.cur_power, inst.cur_toughness]


func test_losing_life_shrinks_it_at_once() -> void:
	var avatar := put_synthetic(1, _avatar())
	assert_eq(_pt(avatar), [20, 20])
	g.adjust_life(1, -15)
	assert_eq(_pt(avatar), [5, 5], "no recalculation asked for: the life change did it")


func test_gaining_life_grows_it() -> void:
	var avatar := put_synthetic(1, _avatar())
	g.adjust_life(1, 3)
	assert_eq(_pt(avatar), [23, 23])


func test_damage_to_its_controller_shrinks_it() -> void:
	var avatar := put_synthetic(1, _avatar())
	var source := put_battlefield(0, "Grizzly Bears")
	g.deal_damage(source, TargetRef.player(1), 4)
	assert_eq(_pt(avatar), [16, 16])


func test_it_dies_in_the_combat_where_its_controller_falls() -> void:
	var avatar := put_synthetic(1, _avatar())
	g.players[1].life = 7
	g.recalculate()
	assert_eq(_pt(avatar), [7, 7], "precondition")
	var brute := put_synthetic(0, _body(5, 5))
	var pup := put_synthetic(0, _body(3, 3))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [brute.id, pup.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {avatar.id: brute.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_eq(g.players[1].life, 4)
	assert_eq(avatar.zone, Mtg.Zone.GRAVEYARD,
		"a 4/4 with 5 damage, judged at the combat check (CR 704.5g)")
	assert_eq(brute.zone, Mtg.Zone.GRAVEYARD, "it dealt 7 as damage was assigned")


func test_off_the_battlefield_it_reads_its_owners_life() -> void:
	var card := give_synthetic(1, _avatar())
	g.adjust_life(1, -8)
	g.recalculate()
	assert_eq(_pt(card), [12, 12], "a characteristic-defining ability works everywhere (CR 604.3)")


func test_undo_restores_the_size() -> void:
	var avatar := put_synthetic(1, _avatar())
	var mark := g.make_mark()
	g.adjust_life(1, -10)
	assert_eq(_pt(avatar), [10, 10])
	g.unmake_to(mark)
	g.end_search()
	g.recalculate()
	assert_eq(_pt(avatar), [20, 20])


func test_the_flag_is_what_asks() -> void:
	var plain := StaticAbility.new(_life_size, "")
	assert_false(plain.reads_life)
	assert_true(plain.reading_life().reads_life)
