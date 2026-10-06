extends GameTest
## Pack 9 engine follow-up F — the COPIABLE VALUES of a licid that is an
## Aura (CR 707.2). "This creature ... becomes an Aura enchantment" is a
## type-changing and ability-changing EFFECT (CR 613.1d, 613.1f), not part
## of the card's copiable values: a copy of a licid Aura is a copy of the
## licid CREATURE — with the licid ability the Aura lost — and is not an
## Aura attached to anything. [method MtgGame.copiable_data] returns the
## definition the licid reverts to ([member CardData.licid_base]).
##
## No card in the pool copies an enchantment (every copier asks for a
## creature or an artifact), so the copy effect here is the engine's own
## doors: [method MtgGame.become_copy] and [method MtgGame.create_token].


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


## A red 2/2 licid whose Aura half grants haste (Enraging Licid's shape).
static func _licid(card_name := "Synthetic Licid") -> CardData:
	return CardData.new(card_name, "{1}{R}", Mtg.CardType.CREATURE).pt(2, 2) \
		.with_subtypes(["licid"]).as_licid("{R}", "{R}") \
		.static_ability(StaticAbility.new(_host_haste,
			"Enchanted creature has haste.").changing_abilities())


static func _host_haste(game: MtgGame, s: CardInstance) -> void:
	if s.attached_to == -1:
		return
	var h := game.find_instance(s.attached_to)
	if game.is_present(h) and not h.cur_keywords.has(Mtg.Keyword.HASTE):
		h.cur_keywords.append(Mtg.Keyword.HASTE)


func _licid_on(host: CardInstance) -> CardInstance:
	var licid := put_synthetic(0, _licid())
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, licid, 0, [TargetRef.card(host)]))
	resolve_stack()
	assert_true(g.is_licid_aura(licid), "precondition: an Aura")
	assert_eq(licid.attached_to, host.id)
	return licid


func test_the_copiable_values_of_a_licid_aura_are_the_licid_creature() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var licid := _licid_on(bear)
	var values := g.copiable_data(licid)
	assert_eq(values, licid.data.licid_base, "the definition it reverts to")
	assert_eq(values, licid.printed_data, "its printed card here")
	assert_ne(values.types & Mtg.CardType.CREATURE, 0, "a creature")
	assert_false(values.is_aura(), "not an Aura")
	assert_eq(values.activated_abilities.size(), 1, "with the licid ability")


func test_a_permanent_that_copies_a_licid_aura_becomes_the_licid_creature() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var licid := _licid_on(bear)
	var copier := put_battlefield(0, "Hill Giant")
	g.become_copy(copier, g.copiable_data(licid))
	assert_true(copier.is_creature())
	assert_false(copier.is_aura())
	assert_eq(copier.attached_to, -1, "attached to nothing")
	assert_eq(copier.data.card_name, "Synthetic Licid")
	assert_eq([copier.cur_power, copier.cur_toughness], [2, 2])
	assert_eq(copier.cur_activated_abilities.size(), 1, "the licid ability the Aura lost")
	assert_eq(copier.zone, Mtg.Zone.BATTLEFIELD, "no Aura state-based action")
	# And the copy is a licid that can do it itself.
	var giant := put_battlefield(0, "Hill Giant")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, copier, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_true(g.is_licid_aura(copier))
	assert_eq(copier.attached_to, giant.id)
	assert_true(giant.has_keyword(Mtg.Keyword.HASTE))
	assert_eq(licid.attached_to, bear.id, "the original is untouched")


func test_a_token_copy_of_a_licid_aura_is_a_creature() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var licid := _licid_on(bear)
	var made := g.create_token(0, g.copiable_data(licid))
	assert_eq(made.size(), 1)
	var token: CardInstance = made[0]
	assert_true(token.is_creature())
	assert_false(token.is_aura())
	assert_eq(token.attached_to, -1)
	assert_eq(token.zone, Mtg.Zone.BATTLEFIELD)


func test_a_licid_creature_and_a_face_down_body_are_unchanged() -> void:
	var licid := put_synthetic(0, _licid())
	assert_eq(g.copiable_data(licid), licid.data, "a licid creature copies as itself")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.turn_face_down(bear)
	assert_eq(g.copiable_data(bear).card_name, "", "face down: a nameless 2/2 (CR 708.2)")
