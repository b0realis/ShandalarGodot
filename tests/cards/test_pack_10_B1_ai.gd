extends GameTest
## Pack 10 (the Urza block), batch B1: what the spells of
## cards/sets/usg/_spells.gd and cards/sets/ulg/_spells.gd tell the fair AI.
## Every effect is a typed one the readers already price
## (engine/ai/effect_intent.gd) or declares its shape
## ([member EffectBase.ai_role]) for the Stage 4 policy, so no B1 card
## reads as an unknown blob; a typed card is cast by the pilot as it is;
## and the resolution hints the cards compute (which creature Curfew
## returns, what Reprocess and Ill-Gotten Gains choose) read public state
## and the chooser's own cards only: they do not move when the opponent's
## hidden hand or either library changes (docs/fair-play.md).

const B1 := ["Congregate", "Humble", "Planar Birth", "Redeem", "Waylay", "Annul", "Catalog",
	"Curfew", "Hibernation", "Stroke of Genius", "Sunder", "Tolarian Winds", "Windfall",
	"Befoul", "Breach", "Corrupt", "Duress", "Ill-Gotten Gains", "Rain of Filth", "Reprocess",
	"Unnerve", "Acidic Soil", "Arc Lightning", "Disorder", "Falter", "Fault Line", "Gamble",
	"Goblin Offensive", "Headlong Rush", "Heat Ray", "Meltdown", "Raze", "Shower of Sparks",
	"Steam Blast", "Gaea's Bounty", "Symbiosis", "Titania's Boon", "Whirlwind",
	"Erase", "Peace and Quiet", "Purify", "Intervene", "Opportunity", "Tinker", "Ostracize",
	"Sick and Tired", "About Face", "Last-Ditch Effort", "Rack and Ruin", "Crop Rotation",
	"Harmonic Convergence", "Might of Oaks", "Silk Net", "Wing Snare"]


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(seat := 0) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai

func _pay(pid: int, card_name: String, x := 0) -> void:
	var cost := CardRegistry.get_card(card_name).cost
	for color in cost.colored:
		add_mana(pid, int(color), int(cost.colored[color]))
	var generic := cost.generic + x * cost.x_count
	if generic > 0:
		add_mana(pid, Mtg.ManaColor.C, generic)

func _cast_resolve(pid: int, card_name: String, targets: Array = [], x := 0) -> void:
	var card := give_hand(pid, card_name)
	_pay(pid, card_name, x)
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.cast_spell(pid, card, targets, x))
	resolve_stack()

static func _typed(e: EffectBase) -> bool:
	return e is DamageEffect or e is DamageAllEffect or e is DestroyEffect \
		or e is DestroyAllEffect or e is PumpEffect or e is MassPumpEffect \
		or e is CounterEffect or e is DrawEffect or e is GainLifeEffect \
		or e is SearchLibraryEffect or e is ExileEffect or e is SwitchPowerToughnessEffect \
		or e is ChosenDiscardEffect or e is CreateTokenEffect


func test_every_b1_effect_is_typed_or_declares_its_shape() -> void:
	for card_name in B1:
		var data := CardRegistry.get_card(card_name)
		assert_not_null(data, card_name)
		if data == null: continue
		assert_false(data.spell_effects.is_empty(), card_name)
		for e in data.spell_effects:
			assert_true(_typed(e) or e.ai_role != &"",
				"%s: %s is neither typed nor shaped" % [card_name, e.describe()])

func test_a_typed_removal_spell_is_aimed_by_the_pilot() -> void:
	var ai := _ai()
	var angel := put_battlefield(1, "Serra Angel")
	put_battlefield(1, "Grizzly Bears")
	for _i in 3:
		put_battlefield(0, "Forest")
	give_hand(0, "Wing Snare")
	assert_eq(ai.act(g), "cast Wing Snare")
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD)


# -------------------------------------------------------------- fair hints --

## Two hidden states over one public board: the opponent's hand and the
## order of both libraries differ (nothing a fair choice may read).
func _hide(variant: int) -> void:
	var tops := ["Lightning Bolt", "Island", "Serra Angel"]
	if variant == 1:
		tops.reverse()
		for card_name in ["Wrath of God", "Lightning Bolt", "Shivan Dragon"]:
			give_hand(1, card_name)
	for pid in [0, 1]:
		for card_name in tops:
			var card := give_hand(pid, card_name)
			g.put_from_hand_on_top_of_library(card)

func _curfew_once(variant: int) -> Array:
	before_each()
	_ai(0)
	_ai(1)
	var mine := [put_battlefield(0, "Grizzly Bears"), put_battlefield(0, "Serra Angel")]
	var theirs := [put_battlefield(1, "Gray Ogre"), put_battlefield(1, "Hill Giant")]
	_hide(variant)
	_cast_resolve(0, "Curfew")
	var out: Array = []
	for i in mine + theirs: out.append(i.zone)
	return out

func _reprocess_once(variant: int) -> Array:
	before_each()
	_ai(0)
	var bodies: Array = [put_battlefield(0, "Grizzly Bears"), put_battlefield(0, "Sol Ring")]
	for _i in 8:
		bodies.append(put_battlefield(0, "Swamp"))
	put_battlefield(1, "Hill Giant")
	_hide(variant)
	_cast_resolve(0, "Reprocess")
	var out: Array = []
	for i in bodies: out.append(i.zone)
	return out

func _gains_once(variant: int) -> Array:
	before_each()
	_ai(0)
	var cards: Array = []
	for card_name in ["Lightning Bolt", "Grizzly Bears", "Giant Growth", "Hill Giant"]:
		var inst := _make_instance(0, card_name)
		g.put_into_graveyard(inst)
		cards.append(inst)
	cards.append(give_hand(0, "Shivan Dragon"))
	_hide(variant)
	_cast_resolve(0, "Ill-Gotten Gains")
	var out: Array = []
	for i in cards: out.append(i.zone)
	return out

func test_curfews_choices_do_not_read_hidden_zones() -> void:
	assert_eq(_curfew_once(0), _curfew_once(1))

func test_reprocess_choices_do_not_read_hidden_zones() -> void:
	assert_eq(_reprocess_once(0), _reprocess_once(1))

func test_ill_gotten_gains_choices_do_not_read_hidden_zones() -> void:
	assert_eq(_gains_once(0), _gains_once(1))
