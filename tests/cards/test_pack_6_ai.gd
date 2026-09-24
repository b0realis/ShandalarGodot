extends GameTest
const T := preload("res://engine/ai/portal_tactics.gd")
func before_each() -> void:
	CardPacks.set_enabled("pack-6", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)
func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-6", false)
func pilot(seat := 0) -> AiPlayer:
	var a := AiPlayer.new(seat, AiProfile.wizard())
	g.set_agent(seat, a)
	return a

func test_last_chance_is_not_an_ordinary_time_walk() -> void:
	var s := give_hand(0, "Last Chance")
	var a := pilot()
	assert_eq(a._size_and_aim(g, s, EffectIntent.read(s.data.spell_effects), 0, 0), {})
	put_battlefield(0, "Phantom Warrior")
	g.players[1].life = 2
	assert_false(T.spell_choice(g, a, s).is_empty())
	g.players[1].life = 6
	var body := g.players[0].creatures()[0]
	g.continuous.add_until_eot_pump(body.id, 4, 0)
	g.recalculate()
	assert_eq(T.spell_choice(g, a, s), {}, "temporary power will expire before the extra turn")
	put_battlefield(0, "Deep-Sea Serpent")
	assert_eq(T.spell_choice(g, a, s), {}, "the Serpent still needs the defending player to control an Island")
	put_battlefield(1, "Island")
	assert_false(T.spell_choice(g, a, s).is_empty(), "a legal Serpent attack can now supply lethal")

func test_dynamic_mountain_damage_chooses_a_kill() -> void:
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Badlands")
	var bear := put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	var s := give_hand(0, "Spitting Earth")
	var choice: Dictionary = T.spell_choice(g, pilot(), s)
	assert_eq(choice.targets[0].instance_id, bear.id)

func test_forked_lightning_divides_four_damage_among_at_most_three() -> void:
	for n in 4: put_battlefield(1, "Merfolk of the Pearl Trident")
	var s := give_hand(0, "Forked Lightning")
	var choice: Dictionary = T.spell_choice(g, pilot(), s)
	assert_eq(choice.targets.size(), 3)
	var amount := 0
	for target in choice.targets: amount += target.amount
	assert_eq(amount, 4)
	add_mana(0, Mtg.ManaColor.R, 4)
	assert_ok(g.cast_spell(0, s, choice.targets))
	resolve_stack()
	assert_eq(g.players[1].creatures().size(), 1)

func test_burning_cloak_can_remove_an_enemy_without_killing_own_small_body() -> void:
	put_battlefield(0, "Merfolk of the Pearl Trident")
	var enemy := put_battlefield(1, "Grizzly Bears")
	var s := give_hand(0, "Burning Cloak")
	var choice: Dictionary = T.spell_choice(g, pilot(), s)
	assert_eq(choice.targets[0].instance_id, enemy.id)

func test_prosperity_does_not_deck_itself_and_can_deck_enemy() -> void:
	var s := give_hand(0, "Prosperity")
	var a := pilot()
	assert_eq(T.spell_choice(g, a, s, 30), {})
	while g.players[1].library.size() > 2: g.exile_top_of_library(1, false)
	var choice: Dictionary = T.spell_choice(g, a, s, 5)
	assert_eq(choice.x, 3)
	while g.players[0].library.size() > 2: g.exile_top_of_library(0, false)
	assert_eq(T.spell_choice(g, a, s, 5), {})

func test_reveal_planning_uses_counts_not_hidden_names_or_library_order() -> void:
	var s := give_hand(0, "Baleful Stare")
	for n in 3: give_hand(1, "Mountain")
	var a := pilot()
	var first: Dictionary = T.spell_choice(g, a, s)
	for card in g.players[1].hand: card.data = CardRegistry.get_card("Forest")
	g.players[0].library.reverse()
	g.players[1].library.reverse()
	var rng := g.rng.state
	var next: Dictionary = T.spell_choice(g, a, s)
	assert_eq(first.value, next.value)
	assert_eq(first.targets[0].player_id, next.targets[0].player_id)
	assert_eq(g.rng.state, rng)
	assert_null(g.undo_log)

func test_restricted_fog_is_used_in_declare_attackers_not_after_blockers() -> void:
	var attacker := put_battlefield(0, "Craw Wurm")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	assert_ok(g.pass_priority(0))
	var s := give_hand(1, "Deep Wood")
	add_mana(1, Mtg.ManaColor.G, 2)
	assert_eq(T.special_spell(g, pilot(1)), "cast Deep Wood")
	assert_eq(s.zone, Mtg.Zone.STACK)
	resolve_stack()
	g.deal_damage(attacker, TargetRef.player(1), 6, true)
	assert_eq(g.players[1].life, 20)
