extends GameTest
## Pack 8, batch B3 — Mirage's green, gold and artifact creatures with rules
## text (cards/sets/mir/_creatures.gd), the keyword-only creatures of the
## three sets' `_basic.gd` modules, and the batch's catalogue: every name
## claimed is out of the pending guard and the pool keeps its size.

const CLAIMED := [
	"Civic Guildmage", "Ethereal Champion", "Femeref Healer", "Mtenda Griffin",
	"Pearl Dragon", "Rashida Scalebane", "Spectral Guardian", "Unyaro Griffin",
	"Vigilant Martyr", "Zuberi, Golden Feather", "Azimaet Drake", "Daring Apprentice",
	"Hakim, Loreweaver", "Harmattan Efreet", "Kukemssa Serpent", "Shaper Guildmage",
	"Suq'Ata Firewalker", "Wave Elemental", "Abyssal Hunter", "Barbed-Back Wurm",
	"Blighted Shaman", "Breathstealer", "Dirtwater Wraith", "Fetid Horror", "Mire Shade",
	"Restless Dead", "Sewer Rats", "Shadow Guildmage", "Spirit of the Night",
	"Tainted Specter", "Urborg Panther", "Wall of Corpses", "Armorer Guildmage",
	"Burning Palm Efreet", "Crimson Hellkite", "Dwarven Miner", "Dwarven Nomad",
	"Flame Elemental", "Goblin Soothsayer", "Goblin Tinkerer", "Hivis of the Scale",
	"Pyric Salamander", "Raging Spirit", "Reckless Embermage", "Subterranean Spirit",
	"Wildfire Emissary", "Zirilan of the Claw", "Gravebane Zombie", "Canopy Dragon", "Femeref Archers",
	"Foratog", "Granger Guildmage", "Jungle Patrol", "Locust Swarm", "Maro",
	"Uktabi Faerie", "Uktabi Wildcats", "Unseen Walker", "Village Elder",
	"Haunting Apparition", "Jungle Troll", "Leering Gargoyle", "Radiant Essence",
	"Sawback Manticore", "Shauku's Minion", "Ersatz Gnomes", "Igneous Golem",
	"Patagia Golem",
	# the keyword-only creatures of the three `_basic.gd` modules
	"Ekundu Griffin", "Femeref Scouts", "Iron Tusk Elephant", "Melesse Spirit",
	"Noble Elephant", "Teremko Griffin", "Bay Falcon", "Cerulean Wyvern",
	"Blistering Barrier", "Talruum Minotaur", "Viashino Warrior", "Crash of Rhinos",
	"Giant Mantis", "Karoo Meerkat", "Wild Elephant", "Hazerider Drake",
	"Windreaper Falcon", "Horrible Hordes", "Teeka's Dragon", "Freewind Falcon",
	"Longbow Archer", "Warthog", "Scalebane's Elite", "Tempest Drake",
	"Phyrexian Walker", "Benalish Infantry", "Duskrider Falcon", "Razortooth Rats",
	"Bloodrock Cyclops",
]


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _is_pending(c: CardData) -> bool:
	return c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"


func _grave(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	g.put_into_graveyard(inst)
	return inst


## P0 attacks with [param attackers], P1 blocks with [param blocks]; P0
## holds priority in declare blockers.
func _fight(attackers: Array, blocks: Dictionary) -> void:
	var ids: Array = []
	for inst in attackers: ids.append(inst.id)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, ids))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, blocks))
	resolve_stack()


# ---------------------------------------------------------------- catalogue

func test_the_batch_is_complete_and_the_pool_keeps_its_size() -> void:
	assert_eq(CardRegistry.size(), 897 + 621 + 31)
	assert_eq(CardRegistry.names_in_set("mir").size(), 335)
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c != null: assert_false(_is_pending(c), card_name)
	assert_eq(CLAIMED.size(), 97)


func test_the_basic_keyword_bodies_are_their_printed_keywords() -> void:
	assert_eq(CardRegistry.get_card("Horrible Hordes").rampage, 1)
	assert_eq(CardRegistry.get_card("Teeka's Dragon").rampage, 4)
	assert_true(CardRegistry.get_card("Bloodrock Cyclops").has_keyword(Mtg.Keyword.MUST_ATTACK))
	assert_eq(CardRegistry.get_card("Melesse Spirit").protection_from, Mtg.ManaColor.B)
	assert_true(CardRegistry.get_card("Noble Elephant").has_keyword(Mtg.Keyword.BANDING))
	assert_true(CardRegistry.get_card("Razortooth Rats").has_keyword(Mtg.Keyword.FEAR))
	assert_true(CardRegistry.get_card("Longbow Archer").has_keyword(Mtg.Keyword.REACH))
	assert_true(CardRegistry.get_card("Longbow Archer").has_keyword(Mtg.Keyword.FIRST_STRIKE))


func test_bloodrock_cyclops_attacks_each_combat_if_able() -> void:
	var cyclops := put_battlefield(0, "Bloodrock Cyclops")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, []))
	assert_ok(g.declare_attackers(0, [cyclops.id]))


func test_horrible_hordes_rampage_grows_per_extra_blocker() -> void:
	var hordes := put_battlefield(0, "Horrible Hordes")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	_fight([hordes], {a.id: hordes.id, b.id: hordes.id})
	assert_eq([hordes.cur_power, hordes.cur_toughness], [3, 3], "+1/+1 for the second blocker")


# -------------------------------------------------------------------- green

func test_canopy_dragon_trades_trample_for_flying() -> void:
	var dragon := put_battlefield(0, "Canopy Dragon")
	assert_true(dragon.has_keyword(Mtg.Keyword.TRAMPLE))
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, dragon, 0))
	resolve_stack()
	assert_true(dragon.has_keyword(Mtg.Keyword.FLYING))
	assert_false(dragon.has_keyword(Mtg.Keyword.TRAMPLE))
	advance_to_next_turn()
	assert_true(dragon.has_keyword(Mtg.Keyword.TRAMPLE))
	assert_false(dragon.has_keyword(Mtg.Keyword.FLYING))


func test_femeref_archers_shoot_only_an_attacking_flyer() -> void:
	var archers := put_battlefield(1, "Femeref Archers")
	var angel := put_battlefield(0, "Serra Angel")
	var bear := put_battlefield(0, "Grizzly Bears")
	var home := put_battlefield(0, "Mahamoti Djinn")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [angel.id, bear.id]))
	resolve_stack()
	assert_ok(g.pass_priority(0))
	assert_refused(g.activate_ability(1, archers, 0, [TargetRef.card(bear)]))
	assert_refused(g.activate_ability(1, archers, 0, [TargetRef.card(home)]))
	assert_ok(g.activate_ability(1, archers, 0, [TargetRef.card(angel)]))
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD)


func test_foratog_eats_forests() -> void:
	var atog := put_battlefield(0, "Foratog")
	var forest := put_battlefield(0, "Forest")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.activate_ability(0, atog, 0))
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	assert_refused(g.activate_ability(0, atog, 0), "Forest")
	resolve_stack()
	assert_eq([atog.cur_power, atog.cur_toughness], [3, 4])


func test_granger_guildmage_pings_with_recoil_and_lends_first_strike() -> void:
	var mage := put_battlefield(0, "Granger Guildmage")
	var bear := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, mage, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.damage, 1)
	assert_eq(g.players[0].life, 19, "and 1 damage to you")
	g.untap_permanent(mage)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.activate_ability(0, mage, 1, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.FIRST_STRIKE))


func test_jungle_patrol_grows_wood_and_burns_it_for_red() -> void:
	var patrol := put_battlefield(0, "Jungle Patrol")
	assert_refused(g.tap_for_mana(0, patrol, 0), "")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.activate_ability(0, patrol, 0))
	resolve_stack()
	var wood: CardInstance = null
	for i in g.players[0].battlefield:
		if i.is_token: wood = i
	assert_not_null(wood)
	if wood == null: return
	assert_eq(wood.data.card_name, "Wood")
	assert_eq([wood.cur_power, wood.cur_toughness], [0, 1])
	assert_true(wood.has_keyword(Mtg.Keyword.DEFENDER))
	assert_true(wood.has_subtype("wall"))
	assert_eq(wood.cur_colors, Mtg.ManaColor.G)
	g.untap_permanent(patrol)
	assert_ok(g.tap_for_mana(0, patrol, 0))
	assert_false(g.players[0].battlefield.has(wood), "the Wood was sacrificed")
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.R), 1)
	assert_false(patrol.tapped, "the mana ability does not tap the Patrol")


func test_locust_swarm_regenerates_and_untaps_once_a_turn() -> void:
	var swarm := put_battlefield(0, "Locust Swarm")
	add_mana(0, Mtg.ManaColor.G, 3)
	g.tap_permanent(swarm)
	assert_ok(g.activate_ability(0, swarm, 1))
	assert_refused(g.activate_ability(0, swarm, 1), "once")
	resolve_stack()
	assert_false(swarm.tapped)
	assert_ok(g.activate_ability(0, swarm, 0))
	resolve_stack()
	g.destroy(swarm)
	assert_eq(swarm.zone, Mtg.Zone.BATTLEFIELD)


func test_maro_is_as_big_as_its_controllers_hand_in_every_zone() -> void:
	var maro := give_hand(0, "Maro")
	give_hand(0, "Forest")
	give_hand(0, "Forest")
	g.recalculate()
	assert_eq([maro.cur_power, maro.cur_toughness], [3, 3], "in hand it counts itself (CR 604.3)")
	g.put_from_hand_into_play(maro, 0)
	g.recalculate()
	assert_eq([maro.cur_power, maro.cur_toughness], [2, 2])
	give_hand(1, "Forest")
	assert_eq(maro.cur_power, 2, "only its controller's hand")
	g.discard_hand(0)
	g.recalculate()
	g.check_state_based_actions()
	assert_eq(maro.zone, Mtg.Zone.GRAVEYARD, "an empty hand is a 0/0")


func test_uktabi_faerie_dies_to_destroy_an_artifact() -> void:
	var faerie := put_battlefield(0, "Uktabi Faerie")
	var ring := put_battlefield(1, "Sol Ring")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(0, faerie, 0, [TargetRef.card(bear)]))
	assert_ok(g.activate_ability(0, faerie, 0, [TargetRef.card(ring)]))
	assert_eq(faerie.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)


func test_uktabi_wildcats_count_forests_and_eat_one_to_regenerate() -> void:
	var cats := put_battlefield(0, "Uktabi Wildcats")
	g.recalculate()
	g.check_state_based_actions()
	assert_eq(cats.zone, Mtg.Zone.GRAVEYARD, "no Forests: a 0/0")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(1, "Forest")
	var wildcats := put_battlefield(0, "Uktabi Wildcats")
	g.recalculate()
	assert_eq([wildcats.cur_power, wildcats.cur_toughness], [3, 3], "only Forests you control")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, wildcats, 0))
	resolve_stack()
	assert_eq(wildcats.cur_power, 2, "a Forest went as the cost")
	g.destroy(wildcats)
	assert_eq(wildcats.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(wildcats.tapped)


func test_unseen_walker_forestwalks_and_lends_it() -> void:
	var walker := put_battlefield(0, "Unseen Walker")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_true(walker.cur_landwalk.has("forest"))
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, walker, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.cur_landwalk.has("forest"))
	advance_to_next_turn()
	assert_false(bear.cur_landwalk.has("forest"))


func test_village_elder_regenerates_any_creature_for_a_forest() -> void:
	var elder := put_battlefield(0, "Village Elder")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.activate_ability(0, elder, 0, [TargetRef.card(bear)]), "Forest")
	var forest := put_battlefield(0, "Forest")
	assert_ok(g.activate_ability(0, elder, 0, [TargetRef.card(bear)]))
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	g.destroy(bear)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


# --------------------------------------------------------------------- gold

func test_haunting_apparition_counts_the_chosen_players_green_creatures() -> void:
	_grave(1, "Grizzly Bears")
	_grave(1, "Grizzly Bears")
	_grave(1, "Hill Giant")
	_grave(1, "Giant Growth")
	_grave(0, "Grizzly Bears")
	var ghost := give_hand(0, "Haunting Apparition")
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, ghost))
	resolve_stack()
	assert_eq(int(ghost.memory.get("chosen_player", -1)), 1, "an opponent was chosen as it entered")
	assert_eq([ghost.cur_power, ghost.cur_toughness], [3, 2], "1 plus two green creature cards")
	assert_true(ghost.has_keyword(Mtg.Keyword.FLYING))
	var asked := false
	for choice in g.choice_log:
		if choice.pid == 0 and choice.prompt.contains("Choose an opponent"): asked = true
	assert_true(asked, "the choice is put to its controller")


func test_jungle_troll_regenerates_for_red_or_green() -> void:
	var troll := put_battlefield(0, "Jungle Troll")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, troll, 0))
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, troll, 1))
	resolve_stack()
	assert_eq(troll.regeneration_shields, 2)


func test_leering_gargoyle_grounds_itself_for_toughness() -> void:
	var gargoyle := put_battlefield(0, "Leering Gargoyle")
	assert_ok(g.activate_ability(0, gargoyle, 0))
	resolve_stack()
	assert_eq([gargoyle.cur_power, gargoyle.cur_toughness], [0, 4])
	assert_false(gargoyle.has_keyword(Mtg.Keyword.FLYING))
	advance_to_next_turn()
	assert_true(gargoyle.has_keyword(Mtg.Keyword.FLYING))


func test_radiant_essence_grows_against_a_black_permanent() -> void:
	var essence := put_battlefield(0, "Radiant Essence")
	put_battlefield(0, "Scathe Zombies")
	assert_eq([essence.cur_power, essence.cur_toughness], [2, 3], "its own black permanent does not count")
	var knight := put_battlefield(1, "Black Knight")
	assert_eq([essence.cur_power, essence.cur_toughness], [3, 5])
	g.destroy(knight)
	assert_eq(essence.cur_power, 2)


func test_sawback_manticore_flies_and_bites_only_in_combat_once_a_turn() -> void:
	var manticore := put_battlefield(0, "Sawback Manticore")
	var bear := put_battlefield(1, "Grizzly Bears")
	var other := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, manticore, 0))
	resolve_stack()
	assert_true(manticore.has_keyword(Mtg.Keyword.FLYING))
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, manticore, 1, [TargetRef.card(manticore)]), "attacking or blocking")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {manticore.id: bear.id}))
	resolve_stack()
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, manticore, 1, [TargetRef.card(other)]))
	assert_ok(g.activate_ability(0, manticore, 1, [TargetRef.card(bear)]))
	assert_refused(g.activate_ability(0, manticore, 1, [TargetRef.card(bear)]), "once")
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


func test_shaukus_minion_burns_only_white_creatures() -> void:
	var minion := put_battlefield(0, "Shauku's Minion")
	var angel := put_battlefield(1, "Serra Angel")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.activate_ability(0, minion, 0, [TargetRef.card(bear)]))
	assert_ok(g.activate_ability(0, minion, 0, [TargetRef.card(angel)]))
	resolve_stack()
	assert_eq(angel.damage, 2)


# ---------------------------------------------------------------- artifacts

func test_ersatz_gnomes_bleach_a_spell_for_good() -> void:
	var gnomes := put_battlefield(1, "Ersatz Gnomes")
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bear))
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, gnomes, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.cur_colors, 0, "the spell's colour change rides into the permanent (CR 400.7a)")
	advance_to_next_turn()
	assert_eq(bear.cur_colors, 0)


func test_ersatz_gnomes_bleach_a_permanent_until_end_of_turn() -> void:
	var gnomes := put_battlefield(0, "Ersatz Gnomes")
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_ok(g.activate_ability(0, gnomes, 1, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_colors, 0)
	advance_to_next_turn()
	assert_eq(bear.cur_colors, Mtg.ManaColor.G)


func test_golems_buy_their_keywords() -> void:
	var igneous := put_battlefield(0, "Igneous Golem")
	var patagia := put_battlefield(0, "Patagia Golem")
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.activate_ability(0, igneous, 0))
	assert_ok(g.activate_ability(0, patagia, 0))
	resolve_stack()
	assert_true(igneous.has_keyword(Mtg.Keyword.TRAMPLE))
	assert_true(patagia.has_keyword(Mtg.Keyword.FLYING))
	advance_to_next_turn()
	assert_false(igneous.has_keyword(Mtg.Keyword.TRAMPLE))
	assert_false(patagia.has_keyword(Mtg.Keyword.FLYING))


## A seat that asks for the 1997 damage windows (RulesOptions fork,
## docs/duel-todo.md §6.8).
class Duelist extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true


func test_village_elder_regenerates_in_the_1997_regeneration_window() -> void:
	g.rules.damage_prevention_window = true
	g.set_agent(1, Duelist.new())
	var elder := put_battlefield(1, "Village Elder")
	put_battlefield(1, "Forest")
	var bear := put_battlefield(1, "Grizzly Bears")
	var wurm := put_battlefield(0, "Craw Wurm")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bear.id: wurm.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_regeneration, "lethal damage is on the Bears")
	assert_ok(g.end_damage_prevention(0))
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(1, elder, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_ok(g.end_damage_prevention(g.priority_player))
	if g.awaiting_damage_prevention or g.awaiting_regeneration: assert_ok(g.end_damage_prevention(g.priority_player))
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "regenerated in the window")
	assert_true(bear.tapped)
