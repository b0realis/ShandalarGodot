extends GameTest
## THE BREATH A BODY WEARS (2026-09-30). The owner, examining the AI's
## play of one card: *"Firebreathing card AI play examine — one AI
## follow-up remains: duplicate Firebreathing can escape the new
## text-based detector. Please fix."*
##
## Two faults, one card, and both were the aura's ABILITY. Firebreathing's
## `{R}: Enchanted creature gets +1/+0` lives on the aura and pumps the
## creature it enchants:
##
##  1. THE DUPLICATE. [method EffectIntent.stacks] (2026-09-28) read the
##     "+1/+0" on the printed line as a quantity — two pumps are twice the
##     pump — so [method EffectIntent.aura_repeats] let a second
##     Firebreathing onto a creature already wearing one. But that
##     quantity is bought with MANA, as often as the mana lasts: the
##     wearer already breathes for every open Mountain, and the second
##     copy sells nothing. Now the reader takes every activated line a
##     copy can already repeat (no {T}, no sacrifice, no per-turn cap) out
##     of the text before it asks its phrases, and judges the second copy
##     on what is LEFT: Holy Armor keeps its static `+0/+2` and stacks;
##     Firebreathing and Blessing keep "Enchant creature" and are had
##     once.
##  2. THE BREATH NOBODY TOOK. Every pump path in [AiPlayer] walked the
##     creature's OWN activated abilities, and the reader called the
##     aura's card-local effect `unknown`: a Hill Giant wearing
##     Firebreathing swung unblocked into four open Mountains for exactly
##     three, and blocked by a Giant Spider it traded nothing. The effect
##     now declares its shape ([member EffectIntent.pump_host], by role
##     and never by name), [method AiPlayer._breath_sources] hands every
##     pump path the auras a body wears beside its own abilities, and
##     the ability is activated on the AURA — its controller pays, as
##     printed. Under [member AiProfile.pumps_to_attack] for our bodies,
##     the way the card-local firebreathers are; under [member
##     AiProfile.reads_pumps] for theirs. And the 2ed Regeneration aura —
##     the owner's card of 2026-09-28 — declares `regenerate_host` and
##     [member EffectBase.is_regeneration] the way Thrull Retainer and
##     Carapace do, so the shield it sells is bought too.
##
## Every test acts through AiPlayer.act / the public MtgGame API, or
## asks the reader directly.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.pumps_to_attack = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.pumps_to_attack = false
	return profile


func _lands(seat: int, land_name: String, count: int) -> void:
	for _i in count:
		put_battlefield(seat, land_name)


## Put [param aura_name] from seat [param seat]'s hand onto [param host].
func _wear(seat: int, host: CardInstance, aura_name: String) -> CardInstance:
	var aura := give_hand(seat, aura_name)
	g.attach_aura_from_anywhere(aura, host, seat)
	return aura


func _in_hand(seat: int, card_name: String) -> bool:
	for card in g.players[seat].hand:
		if card.data.card_name == card_name:
			return true
	return false


func _untapped_lands(seat: int) -> int:
	var n := 0
	for inst in g.players[seat].battlefield:
		if inst.is_land() and not inst.tapped:
			n += 1
	return n


## Walk priority from our first main phase to the attack declaration.
func _reach_attackers(ai: AiPlayer) -> void:
	var guard := 0
	while not g.awaiting_attackers and not g.game_over and guard < 40:
		if g.priority_player == 0:
			ai.act(g)
		else:
			assert_ok(g.pass_priority(1))
		guard += 1
	assert_true(g.awaiting_attackers, "reached the declaration")


## Both seats act until the combat damage is behind us, collecting what
## the AI under test said it did.
func _play_out_combat(ai: AiPlayer, foe: AiPlayer) -> Array[String]:
	var said: Array[String] = []
	var guard := 0
	while not g.game_over and g.current_step() <= Mtg.Step.COMBAT_DAMAGE \
			and guard < 120:
		var mine := ai.act(g)
		var theirs := foe.act(g)
		if mine != "":
			said.append(mine)
		if mine == "" and theirs == "":
			break
		guard += 1
	return said


# ============================================= 1. the duplicate, refused --

func test_a_second_firebreathing_goes_on_the_creature_without_one() -> void:
	var ai := _ai(AiProfile.wizard())
	_lands(0, "Mountain", 4)
	var giant := put_battlefield(0, "Hill Giant")      # the better body
	var bears := put_battlefield(0, "Grizzly Bears")
	_wear(0, giant, "Firebreathing")
	give_hand(0, "Firebreathing")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Firebreathing")
	resolve_stack()
	assert_eq(bears.attachments.size(), 1, "the Bears, who had none")
	assert_eq(giant.attachments.size(), 1, "never a second on the Giant")


func test_a_second_firebreathing_stays_in_hand_with_one_host_already_wearing_it() -> void:
	var ai := _ai(AiProfile.wizard())
	_lands(0, "Mountain", 4)
	var giant := put_battlefield(0, "Hill Giant")
	_wear(0, giant, "Firebreathing")
	give_hand(0, "Firebreathing")
	advance_to_step(Mtg.Step.MAIN1)
	var did := ai.act(g)
	assert_false(did.contains("Firebreathing"), "not cast for nothing: %s" % did)
	assert_true(_in_hand(0, "Firebreathing"), "kept for a creature that has none")
	assert_eq(giant.attachments.size(), 1)


func test_with_holds_repeats_off_the_giant_wears_two_as_before() -> void:
	# The Deck Lab's null for the 2026-09-28 knob: the picker of old.
	var profile := AiProfile.wizard()
	profile.holds_repeats = false
	var ai := _ai(profile)
	_lands(0, "Mountain", 4)
	var giant := put_battlefield(0, "Hill Giant")
	put_battlefield(0, "Grizzly Bears")
	_wear(0, giant, "Firebreathing")
	give_hand(0, "Firebreathing")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Firebreathing")
	resolve_stack()
	assert_eq(giant.attachments.size(), 2, "the nonsense, on request")


func test_an_uncapped_activated_line_is_not_a_quantity() -> void:
	# The reader itself: the line a copy can already repeat is taken out
	# before the phrases are asked.
	for name in ["Firebreathing", "Blessing"]:
		assert_false(EffectIntent.stacks(CardRegistry.get_card(name)),
			"%s sells nothing twice" % name)
	var armor := CardRegistry.get_card("Holy Armor")
	assert_true(EffectIntent.stacks(armor), "the static +0/+2 is a second +0/+2")
	var left := EffectIntent._repeatable_text(armor)
	assert_true(left.contains("+0/+2"), "the static line stays")
	assert_false(left.contains("+0/+1"), "the {W} line is gone")
	assert_false(EffectIntent._repeatable_text(CardRegistry.get_card("Firebreathing"))
		.contains("+1/+0"))
	# What the 2026-09-28 lists said, they still say.
	for name in ["Giant Strength", "Icy Manipulator", "Wild Growth", "Howling Mine",
			"Wanderlust", "Psychic Venom"]:
		assert_true(EffectIntent.stacks(CardRegistry.get_card(name)), "%s is a quantity" % name)
	for name in ["Regeneration", "Flight", "Kismet", "Winter Orb"]:
		assert_false(EffectIntent.stacks(CardRegistry.get_card(name)), "%s is had once" % name)


func test_a_tapped_or_capped_line_keeps_its_quantity() -> void:
	# A {T} is one activation per copy and a printed cap is per copy: the
	# lines stay, and so does one the oracle text does not carry.
	var data := CardData.new("Probe Aura", "{R}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.activated(ActivatedAbility.new("{R}", true, [PumpEffect.new(1, 0)],
			"{R}, {T}: Enchanted creature gets +1/+0 until end of turn.")) \
		.oracle("Enchant creature.\n{R}, {T}: Enchanted creature gets +1/+0 until end of turn.")
	assert_true(EffectIntent._repeatable_text(data).contains("+1/+0"), "a {T} line stays")
	var capped := CardData.new("Probe Capped", "{R}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.activated(ActivatedAbility.new("{R}", false, [PumpEffect.new(1, 0)],
			"{R}: Enchanted creature gets +1/+0 until end of turn.").per_turn(1)) \
		.oracle("Enchant creature.\n{R}: Enchanted creature gets +1/+0 until end of turn. Activate only once each turn.")
	assert_true(EffectIntent._repeatable_text(capped).contains("+1/+0"), "a capped line stays")
	var unprinted := CardData.new("Probe Unprinted", "{R}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.activated(ActivatedAbility.new("{R}", false, [PumpEffect.new(1, 0)],
			"{R}: +1/+0.")) \
		.oracle("Enchant creature.\n{R}: Enchanted creature gets +1/+0 until end of turn.")
	assert_true(EffectIntent._repeatable_text(unprinted).contains("+1/+0"),
		"a line the text does not carry is left alone")


# ======================================== 2. the breath the wearer takes --

func test_an_unblocked_wearer_breathes_for_every_open_mountain() -> void:
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	var giant := put_battlefield(0, "Hill Giant")
	_lands(0, "Mountain", 4)
	_wear(0, giant, "Firebreathing")
	advance_to_step(Mtg.Step.MAIN1)
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 1 attacker")
	var said := _play_out_combat(ai, foe)
	assert_eq(said.count("firebreathing on Hill Giant"), 4, "four breaths: %s" % [said])
	assert_eq(g.players[1].life, 13, "three printed and four bought")
	assert_eq(_untapped_lands(0), 0, "every Mountain went into it")


func test_a_blocked_wearer_buys_the_one_breath_that_wins_the_trade() -> void:
	# A 3/3 into a Giant Spider's 2/4 is nothing either way; one {R} makes
	# it a 4/3 that kills the Spider and lives. One, not four: the second
	# breath is asked with the first already on the stack and refused.
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	var giant := put_battlefield(0, "Hill Giant")
	_lands(0, "Mountain", 4)
	var spider := put_battlefield(1, "Giant Spider")
	_wear(0, giant, "Firebreathing")
	advance_to_step(Mtg.Step.MAIN1)
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 1 attacker",
		"sent at the size the Mountains reach")
	var said := _play_out_combat(ai, foe)
	assert_true(g.combat.blocks.has(spider.id) or spider.zone == Mtg.Zone.GRAVEYARD,
		"the Spider blocked")
	assert_eq(said.count("pumps Hill Giant"), 1, "one breath: %s" % [said])
	assert_eq(spider.zone, Mtg.Zone.GRAVEYARD, "the blocker died")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "and the Giant lived")
	assert_eq(_untapped_lands(0), 3, "three Mountains kept")


func test_off_the_wearer_swings_for_the_printed_three() -> void:
	# The null: [member AiProfile.pumps_to_attack] off is the pilot as it
	# was, Firebreathing worn and never breathed.
	var ai := _ai(_off())
	var foe := _ai(AiProfile.wizard(), 1)
	var giant := put_battlefield(0, "Hill Giant")
	_lands(0, "Mountain", 4)
	_wear(0, giant, "Firebreathing")
	advance_to_step(Mtg.Step.MAIN1)
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 1 attacker")
	var said := _play_out_combat(ai, foe)
	assert_eq(said.count("firebreathing on Hill Giant"), 0, "no breath: %s" % [said])
	assert_eq(g.players[1].life, 17)
	assert_eq(_untapped_lands(0), 4)


func test_an_enemy_aura_on_our_body_is_not_ours_to_breathe_with() -> void:
	# Their Firebreathing on our Giant: their controller pays, so the
	# reader offers our pilot nothing off it.
	var ai := _ai(_on())
	var giant := put_battlefield(0, "Hill Giant")
	_lands(0, "Mountain", 4)
	_wear(1, giant, "Firebreathing")
	assert_eq(ai._worn_breaths(g, giant), [], "not ours")
	assert_eq(ai._self_pump_of(g, giant), {}, "no breath of its own either")


func test_the_reader_names_the_aura_as_the_source() -> void:
	var ai := _ai(_on())
	var bears := put_battlefield(0, "Grizzly Bears")
	var blessing := _wear(0, bears, "Blessing")
	_lands(0, "Plains", 2)
	var pump := ai._self_pump_of(g, bears)
	assert_eq(pump.get("source"), blessing, "the ability lives on the aura")
	assert_eq(pump.get("bonus"), Vector2i(1, 1))
	var armor_host := put_battlefield(0, "Hill Giant")
	var armor := _wear(0, armor_host, "Holy Armor")
	assert_eq(ai._self_pump_of(g, armor_host), {}, "+0/+1 buys no attack")
	var for_toughness := ai._self_pump_of(g, armor_host, true)
	assert_eq(for_toughness.get("source"), armor, "but answers a burn")
	assert_eq(for_toughness.get("bonus"), Vector2i(0, 1))
	# Off, the body's own abilities are all the reader walks.
	var off := _ai(_off())
	assert_eq(off._self_pump_of(g, bears), {}, "the null reads nothing worn")


# ================================================ 3. their wearer, read --

func test_their_wearer_is_read_at_the_size_their_mountains_reach() -> void:
	var ai := _ai(AiProfile.wizard())
	put_battlefield(0, "Hill Giant")
	var bears := put_battlefield(1, "Grizzly Bears")
	_wear(1, bears, "Firebreathing")
	assert_eq(ai._pump_reach(g, bears), Vector2i.ZERO, "no Mountain, no breath")
	_lands(1, "Mountain", 2)
	assert_eq(ai._pump_reach(g, bears), Vector2i(1, 0),
		"one breath is where the Giant starts dying to it")
	for land in g.players[1].battlefield:
		if land.is_land():
			land.tapped = true
	assert_eq(ai._pump_reach(g, bears), Vector2i.ZERO, "tapped Mountains buy nothing")


func test_off_their_wearer_is_the_printed_2_2() -> void:
	var profile := AiProfile.wizard()
	profile.reads_pumps = false
	var ai := _ai(profile)
	put_battlefield(0, "Hill Giant")
	var bears := put_battlefield(1, "Grizzly Bears")
	_wear(1, bears, "Firebreathing")
	_lands(1, "Mountain", 2)
	assert_eq(ai._pump_reach(g, bears), Vector2i.ZERO)


# ============================================ 4. the shield the aura sells --

func test_a_blocked_wearer_of_regeneration_is_shielded() -> void:
	var ai := _ai(AiProfile.wizard())
	var foe := _ai(AiProfile.wizard(), 1)
	var giant := put_battlefield(0, "Hill Giant")
	_lands(0, "Forest", 2)
	var theirs := put_battlefield(1, "Hill Giant")
	_wear(0, giant, "Regeneration")
	advance_to_step(Mtg.Step.MAIN1)
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 1 attacker")
	var said := _play_out_combat(ai, foe)
	assert_true(said.has("shields Hill Giant"), "the {G} was paid: %s" % [said])
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD, "their Giant died")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "ours regenerated")


func test_the_regeneration_aura_reads_as_a_shield_for_its_host() -> void:
	var ai := _ai(AiProfile.wizard())
	var giant := put_battlefield(0, "Hill Giant")
	var bears := put_battlefield(0, "Grizzly Bears")
	var aura := _wear(0, giant, "Regeneration")
	var effects: Array = aura.cur_activated_abilities[0].effects
	assert_true(effects[0].is_regeneration)
	assert_true(ai._effects_regenerate(g, effects, giant, aura), "for the wearer")
	assert_false(ai._effects_regenerate(g, effects, bears, aura), "not for the Bears")
