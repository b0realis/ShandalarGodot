extends GameTest
## Pack 10 (the Urza block), batch B6: the static enchantments of
## cards/sets/usg/_enchantments.gd and cards/sets/ulg/_enchantments.gd —
## Absolute Grace, Absolute Law, Glorious Anthem, Worship, Arcane
## Laboratory, Telepathy, Darkest Hour, Bedlam, Sulfuric Vapors,
## Crosswinds, Exploration, Retaliation, Knighthood, Levitation, Aura Flux
## and Engineered Plague — plus the whole batch's catalogue check.

## Every name the two `_enchantments.gd` modules claim.
const CLAIMED := ["Absolute Grace", "Absolute Law", "Angelic Chorus", "Glorious Anthem",
	"Remembrance", "Serra's Liturgy", "Worship", "Arcane Laboratory", "Attunement", "Douse",
	"Lilting Refrain", "Recantation", "Telepathy", "Bereavement", "Darkest Hour",
	"Diabolic Servitude", "Discordant Dirge", "No Rest for the Wicked", "Oppression",
	"Tainted Aether", "Vile Requiem", "Yawgmoth's Edict", "Antagonism", "Bedlam", "Bulwark",
	"Rumbling Crescendo", "Scald", "Sneak Attack", "Sulfuric Vapors", "Torch Song", "Abundance",
	"Crosswinds", "Exploration", "Fecundity", "Greater Good", "Greener Pastures",
	"Midsummer Revel", "Retaliation", "Sporogenesis", "War Dance",
	"Knighthood", "Martyr's Cause", "Planar Collapse", "Aura Flux", "Delusions of Mediocrity",
	"Levitation", "Second Chance", "Brink of Madness", "Engineered Plague", "No Mercy",
	"Phyrexian Reclamation", "Subversion", "Ghitu War Cry", "Impending Disaster", "Rivalry",
	"Defense of the Heart"]

const TYPES := preload("res://engine/core/creature_types.gd")
const W := Mtg.ManaColor.W
const U := Mtg.ManaColor.U
const B := Mtg.ManaColor.B
const R := Mtg.ManaColor.R
const G := Mtg.ManaColor.G

## A seat whose answers a test scripts: yes/no (-1 follows the hint), an
## option by its text (else the hint) and card names to prefer.
class Seat extends DecisionAgent:
	var yes := -1
	var option := ""
	var prefer: Array = []
	var asked: Array = []
	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return hint if yes < 0 else yes == 1
	func answer_option(_game: MtgGame, _pid: int, prompt: String,
			options: Array[String], hint: int) -> int:
		asked.append(prompt)
		var at := options.find(option)
		return at if at >= 0 else hint
	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		for name in prefer:
			for c in candidates:
				if c.data.card_name == name: return c
		return null if candidates.is_empty() else candidates[0]

var me: Seat
var foe: Seat


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	me = Seat.new()
	foe = Seat.new()
	g.set_agent(0, me)
	g.set_agent(1, foe)
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _pt(i: CardInstance) -> Array: return [i.cur_power, i.cur_toughness]

func _priority(pid: int) -> void:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, pid)

## Cast [param card_name] from [param pid]'s hand with plenty of mana.
func _cast(pid: int, card_name: String, targets: Array = []) -> CardInstance:
	var card := give_hand(pid, card_name)
	for color in [W, U, B, R, G]: add_mana(pid, color, 4)
	assert_ok(g.cast_spell(pid, card, targets))
	resolve_stack()
	return card


func test_every_b6_card_is_claimed() -> void:
	assert_eq(CLAIMED.size(), 56)
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)
		assert_true(c.is_type(Mtg.CardType.ENCHANTMENT), card_name)
		assert_false(c.is_aura(), card_name)


func test_the_enchantments_are_cast_and_stay() -> void:
	for card_name in ["Glorious Anthem", "Telepathy", "Exploration", "Knighthood", "Bedlam"]:
		var card := _cast(0, card_name)
		assert_eq(card.zone, Mtg.Zone.BATTLEFIELD, card_name)


# ------------------------------------------------------- Absolute Grace / Law --

func test_absolute_grace_protects_every_creature_from_black() -> void:
	put_battlefield(1, "Absolute Grace")
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	assert_true((mine.cur_protection & B) != 0, "both players' creatures")
	assert_true((theirs.cur_protection & B) != 0)
	var terror := give_hand(0, "Terror")
	add_mana(0, B, 2)
	assert_refused(g.cast_spell(0, terror, [TargetRef.card(theirs)]))


func test_absolute_grace_sheds_a_black_aura_already_attached() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var aura := _make_instance(0, "Unholy Strength")
	g._put_on_battlefield(aura, 0, bears)
	assert_eq(aura.zone, Mtg.Zone.BATTLEFIELD)
	_cast(0, "Absolute Grace")
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD, "protection drops the black Aura (CR 702.16)")


func test_absolute_law_stops_red_burn_at_creatures_not_players() -> void:
	put_battlefield(0, "Absolute Law")
	var giant := put_battlefield(1, "Hill Giant")
	var bolt := give_hand(1, "Lightning Bolt")
	_priority(1)
	add_mana(1, R)
	assert_refused(g.cast_spell(1, bolt, [TargetRef.card(giant)]))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 17)


# --------------------------------------------------------- Glorious Anthem --

func test_glorious_anthem_pumps_only_its_controllers_creatures() -> void:
	put_battlefield(0, "Glorious Anthem")
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	assert_eq(_pt(mine), [3, 3])
	assert_eq(_pt(theirs), [2, 2])


# ------------------------------------------------------------------ Worship --

func test_worship_stops_damage_at_one_life_while_you_control_a_creature() -> void:
	put_battlefield(0, "Worship")
	var bears := put_battlefield(0, "Grizzly Bears")
	g.players[0].life = 3
	var bolt := give_hand(1, "Lightning Bolt")
	_priority(1)
	add_mana(1, R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 1)
	assert_false(g.game_over)
	g.destroy(bears)
	var second := give_hand(1, "Lightning Bolt")
	_priority(1)
	add_mana(1, R)
	assert_ok(g.cast_spell(1, second, [TargetRef.player(0)]))
	resolve_stack()
	assert_true(g.game_over, "no creature, no floor")


func test_worship_does_not_stop_life_loss() -> void:
	put_battlefield(0, "Worship")
	put_battlefield(0, "Grizzly Bears")
	g.players[0].life = 2
	g.adjust_life(0, -5)
	assert_true(g.players[0].life <= 0, "loss of life is not damage")


# -------------------------------------------------------- Arcane Laboratory --

func test_arcane_laboratory_allows_one_spell_per_player_each_turn() -> void:
	put_battlefield(1, "Arcane Laboratory")
	var first := give_hand(0, "Grizzly Bears")
	var second := give_hand(0, "Giant Growth")
	add_mana(0, G, 3)
	assert_ok(g.cast_spell(0, first))
	resolve_stack()
	assert_refused(g.cast_spell(0, second, [TargetRef.card(first)]))
	var land := give_hand(0, "Forest")
	assert_ok(g.play_land(0, land))   # a land is not a spell
	var bolt := give_hand(1, "Lightning Bolt")
	_priority(1)
	add_mana(1, R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))   # each player has their own one
	resolve_stack()
	advance_to_next_turn()
	advance_to_next_turn()
	add_mana(0, G)
	assert_ok(g.cast_spell(0, second, [TargetRef.card(first)]))   # a new turn, a new spell


func test_arcane_laboratory_counts_a_spell_cast_before_it_arrived() -> void:
	var bears := give_hand(0, "Grizzly Bears")
	add_mana(0, G, 2)
	assert_ok(g.cast_spell(0, bears))
	resolve_stack()
	put_battlefield(0, "Arcane Laboratory")
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, G)
	assert_refused(g.cast_spell(0, growth, [TargetRef.card(bears)]))


# --------------------------------------------------------------- Telepathy --

func test_telepathy_reveals_only_the_opponents_hand_while_it_is_out() -> void:
	var telepathy := put_battlefield(0, "Telepathy")
	g.recalculate()
	assert_true(g.players[1].hand_revealed)
	assert_false(g.players[0].hand_revealed)
	g.destroy(telepathy)
	g.recalculate()
	assert_false(g.players[1].hand_revealed)


# ------------------------------------------------------------ Darkest Hour --

func test_darkest_hour_makes_every_creature_black() -> void:
	put_battlefield(0, "Darkest Hour")
	var knight := put_battlefield(1, "White Knight")
	var bears := put_battlefield(0, "Grizzly Bears")
	assert_eq(knight.cur_colors, B)
	assert_eq(bears.cur_colors, B)
	var terror := give_hand(0, "Terror")
	add_mana(0, B, 2)
	assert_refused(g.cast_spell(0, terror, [TargetRef.card(knight)]))   # now a black creature


# ------------------------------------------------------------------- Bedlam --

func test_bedlam_stops_every_block() -> void:
	put_battlefield(1, "Bedlam")
	var attacker := put_battlefield(0, "Grizzly Bears")
	var blocker := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {blocker.id: attacker.id}))
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 18)


# ---------------------------------------------------------- Sulfuric Vapors --

func test_sulfuric_vapors_adds_one_to_a_red_spells_damage() -> void:
	put_battlefield(1, "Sulfuric Vapors")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 16, "3 + 1, whoever controls the Vapors")


func test_sulfuric_vapors_ignores_other_damage() -> void:
	put_battlefield(0, "Sulfuric Vapors")
	var blast := give_hand(0, "Psionic Blast")
	add_mana(0, U, 3)
	assert_ok(g.cast_spell(0, blast, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 16, "a blue spell: 4")
	var giant := put_battlefield(0, "Hill Giant")
	run_combat([giant.id])
	assert_eq(g.players[1].life, 13, "a red creature's combat damage is not a spell's")


# -------------------------------------------------------------- Crosswinds --

func test_crosswinds_shrinks_flyers_only() -> void:
	put_battlefield(1, "Crosswinds")
	var angel := put_battlefield(0, "Serra Angel")
	var bears := put_battlefield(0, "Grizzly Bears")
	assert_eq(_pt(angel), [2, 4])
	assert_eq(_pt(bears), [2, 2])
	put_battlefield(0, "Levitation")
	assert_eq(_pt(bears), [0, 2], "flying granted by Levitation counts (layer 6 before 7c)")


# ------------------------------------------------------------- Exploration --

func test_exploration_gives_one_more_land_each_of_your_turns() -> void:
	put_battlefield(0, "Exploration")
	assert_ok(g.play_land(0, give_hand(0, "Forest")))
	assert_ok(g.play_land(0, give_hand(0, "Island")))
	assert_refused(g.play_land(0, give_hand(0, "Mountain")))
	advance_to_next_turn()
	assert_ok(g.play_land(1, give_hand(1, "Forest")))
	assert_refused(g.play_land(1, give_hand(1, "Island")))   # the opponent has no extra drop


# -------------------------------------------------- Knighthood / Levitation --

func test_knighthood_and_levitation_grant_to_your_creatures_only() -> void:
	put_battlefield(0, "Knighthood")
	put_battlefield(0, "Levitation")
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	assert_true(mine.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_true(mine.has_keyword(Mtg.Keyword.FLYING))
	assert_false(theirs.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_false(theirs.has_keyword(Mtg.Keyword.FLYING))


# -------------------------------------------------------------- Retaliation --

func test_retaliation_pumps_once_per_blocking_creature() -> void:
	put_battlefield(0, "Retaliation")
	var wurm := put_battlefield(0, "Craw Wurm")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Llanowar Elves")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {a.id: wurm.id, b.id: wurm.id}))
	resolve_stack()
	assert_eq(_pt(wurm), [8, 6], "two blockers, two triggers")
	advance_to_next_turn()
	assert_eq(_pt(wurm), [6, 4], "until end of turn")


func test_retaliation_is_not_granted_to_the_opponents_creatures() -> void:
	put_battlefield(1, "Retaliation")
	var bears := put_battlefield(0, "Grizzly Bears")
	var blocker := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {blocker.id: bears.id}))
	assert_eq(g.stack.size(), 0)
	assert_eq(_pt(bears), [2, 2])


# ---------------------------------------------------------------- Aura Flux --

func test_aura_flux_taxes_other_enchantments_in_their_controllers_upkeep() -> void:
	var flux := put_battlefield(0, "Aura Flux")
	var anthem := put_battlefield(1, "Glorious Anthem")
	var own := put_battlefield(0, "Knighthood")
	foe.yes = 0
	advance_to_next_turn()                 # the opponent's upkeep: declined
	assert_eq(anthem.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(own.zone, Mtg.Zone.BATTLEFIELD, "only the upkeep player's enchantments")
	for n in 2: put_battlefield(0, "Forest")
	me.yes = 1
	advance_to_next_turn()                 # ours: Knighthood paid, the Flux untaxed
	assert_eq(own.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(flux.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(me.asked.size(), 1, "one tax, on the other enchantment only")


# -------------------------------------------------------- Engineered Plague --

func test_engineered_plague_shrinks_the_chosen_type_on_both_sides() -> void:
	me.option = "Bear"
	var plague := _cast(0, "Engineered Plague")
	assert_eq(plague.zone, Mtg.Zone.BATTLEFIELD)
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	assert_eq(_pt(mine), [1, 1])
	assert_eq(_pt(theirs), [1, 1])
	assert_eq(_pt(giant), [3, 3])


func test_engineered_plague_hint_is_the_opponents_commonest_type() -> void:
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(0, "Craw Wurm")
	var plague := _cast(0, "Engineered Plague")
	assert_eq(String(plague.memory.get("plague_type", "")), "bear")


func test_engineered_plague_holds_a_human_seat_on_the_type() -> void:
	var plague := give_hand(0, "Engineered Plague")
	add_mana(0, B, 3)
	g.agents[0] = HumanAgent.new()
	g.interactive_choices = true
	assert_ok(g.cast_spell(0, plague))
	var guard := 0
	while g.awaiting_choice == null and not g.stack.is_empty() and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_not_null(g.awaiting_choice, "the type is the player's to choose")
	if g.awaiting_choice == null: return
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.OPTION)
	assert_ok(g.answer_choice(TYPES.ALL.find("Wurm")))
	g.interactive_choices = false
	g.agents[0] = me
	resolve_stack()
	assert_eq(String(plague.memory.get("plague_type", "")), "wurm")
	assert_eq(g.unanswered_choices.size(), 0)
