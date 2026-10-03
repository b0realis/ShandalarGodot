extends GameTest
## Pack 8, batch B2 — the Mirage block's FLANKING cards (cards/sets/mir/_combat.gd,
## cards/sets/vis/_combat.gd): the printed knights, the cards that read
## flanking (Telim'Tor, Knight of Valor) and the one that takes it away
## (Barbed Foliage). The flanking trigger itself is the engine's (Pack 8
## E2, tests/unit/test_pack_8_e2_flanking.gd); here every knight carries
## exactly one instance of it, the trigger is a real stack object that can
## be answered, a flanking blocker is spared, two instances shrink twice,
## and a knight in a band triggers on the band's blocker (CR 702.22h).

## A seat whose answers a test scripts: yes/no (-1 follows the hint), an
## option index (-1 follows the hint) and card names to prefer.
class Seat extends DecisionAgent:
	var yes := -1
	var option := -1
	var prefer: Array = []
	var asked: Array = []

	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return hint if yes < 0 else yes == 1

	func answer_option(_game: MtgGame, _pid: int, prompt: String,
			_options: Array[String], hint: int) -> int:
		asked.append(prompt)
		return hint if option < 0 else option

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		for name in prefer:
			for c in candidates:
				if c.data.card_name == name: return c
		return null if candidates.is_empty() else candidates[0]


const BATCH := ["Alarum", "Dazzling Beauty", "Divine Retribution", "Femeref Knight",
	"Mtenda Herder", "Sidar Jabari", "Sunweb", "Yare", "Zhalfirin Commander",
	"Zhalfirin Knight", "Coral Fighters", "Kukemssa Pirates", "Cadaverous Knight",
	"Catacomb Dragon", "Crypt Cobra", "Dread Specter", "Aleatory", "Barreling Attack",
	"Blind Fury", "Burning Shield Askari", "Crimson Roc", "Ekundu Cyclops",
	"Goblin Elite Infantry", "Searing Spear Askari", "Telim'Tor", "Barbed Foliage",
	"Brushwagg", "Gibbering Hyenas", "Jolrael's Centaur", "Jungle Wurm",
	"Mindbender Spores", "Mtenda Lion", "Sabertooth Cobra", "Delirium",
	"Harbor Guardian", "Rock Basilisk", "Basalt Golem", "Lead Golem", "Knight of Valor",
	"Zhalfirin Crusader", "Cloud Elemental", "Knight of the Mists", "Fallen Askari",
	"Suq'Ata Assassin", "Dwarven Vigilantes", "Goblin Swine-Rider", "Heat Wave",
	"Raging Gorilla", "Rock Slide", "Song of Blood", "Suq'Ata Lancer", "Talruum Champion",
	"Talruum Piper", "Elephant Grass", "Wind Shear", "Pygmy Hippo"]

const KNIGHTS := ["Femeref Knight", "Mtenda Herder", "Sidar Jabari", "Zhalfirin Commander",
	"Zhalfirin Knight", "Cadaverous Knight", "Burning Shield Askari", "Searing Spear Askari",
	"Telim'Tor", "Jolrael's Centaur", "Knight of Valor", "Zhalfirin Crusader",
	"Knight of the Mists", "Fallen Askari", "Suq'Ata Lancer"]

var me: Seat
var foe: Seat


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()
	me = Seat.new()
	foe = Seat.new()
	g.set_agent(0, me)
	g.set_agent(1, foe)
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func _attack(ids: Array, bands: Array = []) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, ids, bands))


## Attack, resolve the attack triggers, declare [param blocks]; stops in the
## declare-blockers step with the block triggers on the stack.
func _attack_and_block(ids: Array, blocks: Dictionary, bands: Array = []) -> void:
	_attack(ids, bands)
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, blocks))


func _flanking_items() -> Array:
	var out: Array = []
	for item in g.stack:
		if item.kind == Mtg.StackKind.TRIGGER and item.trigger != null \
				and item.trigger.text.begins_with("Flanking"):
			out.append(item)
	return out


func _pending(c: CardData) -> bool:
	return c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"


# --------------------------------------------------------------- the batch --

func test_every_b2_card_is_claimed() -> void:
	var pending: Array = []
	for name in BATCH:
		var c := CardRegistry.get_card(name)
		assert_not_null(c, name)
		if c != null and _pending(c): pending.append(name)
	assert_eq(pending, [], "no B2 card may keep the pending rules guard")


func test_every_printed_knight_has_exactly_one_instance() -> void:
	for name in KNIGHTS:
		var knight := put_battlefield(0, name)
		assert_eq(Flanking.instances(knight), 1, name)
		assert_eq(knight.cur_triggered_abilities.filter(func(t: TriggeredAbility) -> bool:
			return t.text.begins_with("Flanking")).size(), 1, "%s: one flanking trigger" % name)


# ------------------------------------------------------- the stack trigger --

func test_femeref_knight_flanks_on_the_stack_and_a_pump_answers_it() -> void:
	var knight := put_battlefield(0, "Femeref Knight")
	var bear := put_battlefield(1, "Grizzly Bears")
	var growth := give_hand(1, "Giant Growth")
	_attack_and_block([knight.id], {bear.id: knight.id})
	var items := _flanking_items()
	assert_eq(items.size(), 1, "one instance, one blocker: one trigger")
	assert_eq(items[0].card, knight)
	assert_eq(items[0].controller, 0, "the attacker's controller controls it")
	assert_eq([bear.cur_power, bear.cur_toughness], [2, 2], "nothing until it resolves")
	assert_eq(g.priority_player, 0)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(1, growth, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq([bear.cur_power, bear.cur_toughness], [4, 4], "2/2 +3/+3 -1/-1")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(knight.zone, Mtg.Zone.GRAVEYARD, "the pumped bear wins")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


func test_unanswered_flanking_kills_a_one_toughness_blocker_first() -> void:
	var herder := put_battlefield(0, "Mtenda Herder")   # 1/1
	var elves := put_battlefield(1, "Llanowar Elves")   # 1/1
	_attack_and_block([herder.id], {elves.id: herder.id})
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD, "0 toughness before damage (CR 704.5f)")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(herder.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(herder.damage, 0)
	assert_eq(g.players[1].life, 20, "still blocked (CR 509.1h)")


func test_a_flanking_blocker_does_not_shrink() -> void:
	var knight := put_battlefield(0, "Femeref Knight")
	var lancer := put_battlefield(1, "Suq'Ata Lancer")
	_attack_and_block([knight.id], {lancer.id: knight.id})
	assert_eq(_flanking_items().size(), 0, "a creature WITH flanking blocks freely")
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(knight.zone, Mtg.Zone.GRAVEYARD, "2/2 against 2/2: a trade")
	assert_eq(lancer.zone, Mtg.Zone.GRAVEYARD)


func test_two_instances_shrink_a_blocker_twice() -> void:
	var knight := put_battlefield(0, "Zhalfirin Knight")
	g.continuous.add_until_eot_keywords(knight.id, [Mtg.Keyword.FLANKING])   # Jabari's Banner's grant
	g.recalculate()
	assert_eq(Flanking.instances(knight), 2)
	var giant := put_battlefield(1, "Hill Giant")
	_attack_and_block([knight.id], {giant.id: knight.id})
	assert_eq(_flanking_items().size(), 2, "each instance triggers (CR 702.25b)")
	resolve_stack()
	assert_eq([giant.cur_power, giant.cur_toughness], [1, 1])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(knight.damage, 1)


func test_a_knight_in_a_band_flanks_the_band_s_blocker() -> void:
	var hero := put_battlefield(0, "Benalish Hero")
	var herder := put_battlefield(0, "Mtenda Herder")
	var giant := put_battlefield(1, "Hill Giant")
	_attack_and_block([hero.id, herder.id], {giant.id: hero.id}, [[hero.id, herder.id]])
	assert_eq(_flanking_items().size(), 1, "blocking the Hero blocks the band (CR 702.22h)")
	resolve_stack()
	assert_eq([giant.cur_power, giant.cur_toughness], [2, 2])


func test_flanking_is_the_same_under_the_fifth_edition_rules() -> void:
	g.rules.set_edition("fifth")
	var lancer := put_battlefield(0, "Suq'Ata Lancer")
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack_and_block([lancer.id], {bear.id: lancer.id})
	assert_eq(_flanking_items().size(), 1)
	resolve_stack()
	assert_eq(bear.cur_toughness, 1)


# --------------------------------------------------------- the white knights --

func test_femeref_knight_buys_vigilance() -> void:
	var knight := put_battlefield(0, "Femeref Knight")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.activate_ability(0, knight, 0))
	resolve_stack()
	assert_true(knight.has_keyword(Mtg.Keyword.VIGILANCE))
	_attack([knight.id])
	assert_false(knight.tapped, "vigilance: attacking doesn't tap it")
	advance_to_next_turn()
	assert_false(knight.has_keyword(Mtg.Keyword.VIGILANCE), "until end of turn")


func test_sidar_jabari_taps_a_creature_of_the_defending_player() -> void:
	var sidar := put_battlefield(0, "Sidar Jabari")
	var mine := put_battlefield(0, "Grizzly Bears")
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack([sidar.id])
	assert_eq(g.stack.size(), 1, "the attack trigger")
	assert_eq(g.stack[0].targets[0].instance_id, bear.id, "only the defending player's creature is legal")
	resolve_stack()
	assert_true(bear.tapped)
	assert_false(mine.tapped)
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {bear.id: sidar.id}), "tapped")


func test_sidar_jabari_with_nothing_to_tap_has_no_trigger() -> void:
	var sidar := put_battlefield(0, "Sidar Jabari")
	put_battlefield(0, "Grizzly Bears")
	_attack([sidar.id])
	assert_eq(g.stack.size(), 0, "no legal target: removed (CR 603.3d)")


func test_zhalfirin_commander_pumps_only_knights() -> void:
	var commander := put_battlefield(0, "Zhalfirin Commander")
	var knight := put_battlefield(0, "Femeref Knight")
	var bear := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(0, commander, 0, [TargetRef.card(bear)]))
	assert_ok(g.activate_ability(0, commander, 0, [TargetRef.card(knight)]))
	resolve_stack()
	assert_eq([knight.cur_power, knight.cur_toughness], [3, 3])


func test_zhalfirin_knight_gains_first_strike_and_survives_a_bigger_blocker() -> void:
	var knight := put_battlefield(0, "Zhalfirin Knight")
	var giant := put_battlefield(1, "Hill Giant")
	_attack_and_block([knight.id], {giant.id: knight.id})
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.activate_ability(0, knight, 0))
	resolve_stack()
	assert_true(knight.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_eq(giant.cur_toughness, 2, "flanked")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(knight.damage, 0, "it struck first")


func test_knight_of_valor_shrinks_each_non_flanking_blocker_once_a_turn() -> void:
	var valor := put_battlefield(0, "Knight of Valor")
	var giant := put_battlefield(1, "Hill Giant")
	var lancer := put_battlefield(1, "Suq'Ata Lancer")
	_attack_and_block([valor.id], {giant.id: valor.id, lancer.id: valor.id})
	assert_eq(_flanking_items().size(), 1, "only the giant lacks flanking")
	resolve_stack()
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, valor, 0))
	resolve_stack()
	assert_eq([giant.cur_power, giant.cur_toughness], [1, 1], "flanking and the ability")
	assert_eq([lancer.cur_power, lancer.cur_toughness], [2, 2], "a flanking blocker is spared")
	assert_refused(g.activate_ability(0, valor, 0), "")


func test_knight_of_valor_in_a_band_reaches_the_band_s_blocker() -> void:
	var valor := put_battlefield(0, "Knight of Valor")
	var hero := put_battlefield(0, "Benalish Hero")
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack_and_block([valor.id, hero.id], {bear.id: hero.id}, [[valor.id, hero.id]])
	assert_eq(_flanking_items().size(), 1, "the bear blocks Valor too (CR 702.22h)")
	resolve_stack()
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, valor, 0))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "2/2 -1/-1 -1/-1")


func test_zhalfirin_crusader_sends_the_next_point_elsewhere() -> void:
	var crusader := put_battlefield(0, "Zhalfirin Crusader")
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, crusader, 0, [TargetRef.player(1)]))
	resolve_stack()
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(crusader)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19, "one point went to the target")
	assert_eq(crusader.zone, Mtg.Zone.GRAVEYARD, "the other two still kill a 2/2")


func test_zhalfirin_crusader_redirects_a_ping_to_a_creature() -> void:
	var crusader := put_battlefield(0, "Zhalfirin Crusader")
	var elves := put_battlefield(1, "Llanowar Elves")
	var sorcerer := put_battlefield(1, "Prodigal Sorcerer")
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, crusader, 0, [TargetRef.card(elves)]))
	resolve_stack()
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, sorcerer, 0, [TargetRef.card(crusader)]))
	resolve_stack()
	assert_eq(crusader.damage, 0)
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)


# --------------------------------------------------------- the blue knight --

func test_knight_of_the_mists_destroys_an_enemy_knight_without_regeneration() -> void:
	var cadaver := put_battlefield(1, "Cadaverous Knight")
	cadaver.regeneration_shields = 1   # setup: a shield already up
	var mists := give_hand(0, "Knight of the Mists")
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 2)
	me.yes = 0
	assert_ok(g.cast_spell(0, mists, []))
	resolve_stack()
	assert_eq(cadaver.zone, Mtg.Zone.GRAVEYARD, "can't be regenerated")
	assert_eq(mists.zone, Mtg.Zone.BATTLEFIELD)


func test_knight_of_the_mists_paying_u_spares_the_knight() -> void:
	var own := put_battlefield(0, "Femeref Knight")
	var mists := give_hand(0, "Knight of the Mists")
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, mists, []))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))   # the spell resolves; the trigger targets a Knight
	assert_eq(g.stack.size(), 1)
	var target := g.find_instance(g.stack[0].targets[0].instance_id)
	assert_true(target == own or target == mists, "only our own Knights to choose from")
	add_mana(0, Mtg.ManaColor.U)
	resolve_stack()   # hint: pay to spare our own Knight
	assert_eq(g.players[0].mana_pool.total(), 0, "{U} was paid")
	assert_eq(own.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(mists.zone, Mtg.Zone.BATTLEFIELD)


# -------------------------------------------------------- the black knights --

func test_cadaverous_knight_regenerates() -> void:
	var knight := put_battlefield(0, "Cadaverous Knight")
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, knight, 0))
	resolve_stack()
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(knight)]))
	resolve_stack()
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(knight.tapped, "regeneration taps it")


func test_fallen_askari_can_t_block() -> void:
	var askari := put_battlefield(1, "Fallen Askari")
	var bear := put_battlefield(0, "Grizzly Bears")
	_attack([bear.id])
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {askari.id: bear.id}))
	assert_ok(g.declare_blockers(1, {}))


# ---------------------------------------------------------- the red knights --

func test_burning_shield_askari_gains_first_strike() -> void:
	var askari := put_battlefield(0, "Burning Shield Askari")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.activate_ability(0, askari, 0))
	resolve_stack()
	assert_true(askari.has_keyword(Mtg.Keyword.FIRST_STRIKE))


func test_searing_spear_askari_menace_needs_two_blockers_and_flanks_both() -> void:
	var askari := put_battlefield(0, "Searing Spear Askari")
	var bear := put_battlefield(1, "Grizzly Bears")
	var elves := put_battlefield(1, "Llanowar Elves")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, askari, 0))
	resolve_stack()
	_attack([askari.id])
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {bear.id: askari.id}))
	assert_ok(g.declare_blockers(1, {bear.id: askari.id, elves.id: askari.id}))
	assert_eq(_flanking_items().size(), 2)
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.cur_toughness, 1)


func test_searing_spear_askari_menace_ends_with_the_turn() -> void:
	var askari := put_battlefield(0, "Searing Spear Askari")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, askari, 0))
	resolve_stack()
	assert_eq(askari.cur_min_blockers, 2)
	advance_to_next_turn()
	assert_eq(askari.cur_min_blockers, 1)


func test_telim_tor_pumps_every_attacker_with_flanking() -> void:
	var telim := put_battlefield(0, "Telim'Tor")
	var knight := put_battlefield(0, "Femeref Knight")
	var bear := put_battlefield(0, "Grizzly Bears")
	var granted := put_battlefield(0, "Llanowar Elves")
	g.continuous.add_until_eot_keywords(granted.id, [Mtg.Keyword.FLANKING])
	g.recalculate()
	_attack([telim.id, knight.id, bear.id, granted.id])
	resolve_stack()
	assert_eq([telim.cur_power, telim.cur_toughness], [3, 3])
	assert_eq([knight.cur_power, knight.cur_toughness], [3, 3])
	assert_eq([granted.cur_power, granted.cur_toughness], [2, 2], "a granted flanking counts")
	assert_eq([bear.cur_power, bear.cur_toughness], [2, 2], "no flanking, no pump")


func test_suq_ata_lancer_attacks_the_turn_it_arrives() -> void:
	var lancer := put_battlefield(0, "Suq'Ata Lancer", true)
	_attack([lancer.id])
	assert_true(g.combat.attackers.has(lancer.id))


# ------------------------------------------------------- the green flanker --

func test_jolrael_s_centaur_has_shroud() -> void:
	var centaur := put_battlefield(0, "Jolrael's Centaur")
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.cast_spell(0, growth, [TargetRef.card(centaur)]))
	assert_eq(Flanking.instances(centaur), 1)


func test_barbed_foliage_takes_flanking_away_and_stings_the_attacker() -> void:
	put_battlefield(1, "Barbed Foliage")
	var knight := put_battlefield(0, "Femeref Knight")
	var giant := put_battlefield(1, "Hill Giant")
	_attack([knight.id])
	assert_eq(g.stack.size(), 2, "one loss and one sting, each its own trigger")
	for item in g.stack:
		assert_eq(item.controller, 1, "Barbed Foliage's controller's")
	resolve_stack()
	assert_false(knight.has_keyword(Mtg.Keyword.FLANKING))
	assert_eq(knight.damage, 1)
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {giant.id: knight.id}))
	assert_eq(_flanking_items().size(), 0, "it lost flanking before the block")
	resolve_stack()
	assert_eq(giant.cur_toughness, 3, "not flanked")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(knight.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "a full-size 3/3 survives the knight's 2")


func test_barbed_foliage_triggers_once_per_attacker_and_spares_flyers() -> void:
	put_battlefield(1, "Barbed Foliage")
	var herder := put_battlefield(0, "Mtenda Herder")
	var angel := put_battlefield(0, "Serra Angel")
	_attack([herder.id, angel.id])
	assert_eq(g.stack.size(), 3, "two losses, one sting (the angel flies)")
	resolve_stack()
	assert_eq(herder.zone, Mtg.Zone.GRAVEYARD, "1 damage to a 1/1")
	assert_eq(angel.damage, 0)


func test_barbed_foliage_ignores_its_controller_s_own_attack() -> void:
	put_battlefield(0, "Barbed Foliage")
	var knight := put_battlefield(0, "Femeref Knight")
	_attack([knight.id])
	assert_eq(g.stack.size(), 0, "only creatures attacking YOU")
	assert_true(knight.has_keyword(Mtg.Keyword.FLANKING))
