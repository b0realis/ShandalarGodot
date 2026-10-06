extends RefCounted
## Tempest (_buyback, Pack 9). Buyback (CR 702.27): spells that return to their owner's hand when the buyback cost was paid.
##
## Buyback is a PAYMENT ROW (CardData.with_buyback, engine package E2):
## the printed row, then the same spell "with buyback", picked exactly as a
## mode is. A RESOLVED spell whose buyback was paid goes to its owner's
## hand; a countered or fizzled one, and a copy, do not (CR 702.27a,
## 608.2n, 707.10a). The AI reads the row itself (AiPlayer._paying_mode /
## _buyback_row: payable, mana not starving another card, objects worth
## less than the card) — every card here ships its row and a typed or
## role-tagged effect, so the casting AI knows what it buys back.
## Effects are TYPED wherever the engine has the shape. Tests:
## tests/cards/test_pack_9_B2_buyback.gd (the buyback, card by card),
## test_pack_9_B2_buyback_tmp.gd (the effects), test_pack_9_B2_ai.gd.
const F := preload("res://cards/sets/fem/_rules.gd")
const OC := preload("res://engine/additional_object_costs.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		# ------------------------------------------------------------ white
		"Anoint":
			c.spell(PreventDamageEffect.new(3).target_creature())
			c.with_buyback({"mana": "{3}"})
		"Invulnerability":
			# One shield over its caster, used up by one damage event from
			# the named source (CR 609.7a, 615.8).
			c.spell(SourceShieldEffect.prevent_to_you())
			c.with_buyback({"mana": "{3}"})
		"Worthy Cause":
			c.spell(WorthyCause.new())
			c.with_object_cost(OC.sacrificing("creature", _creature))
			c.with_buyback({"mana": "{2}"})
		# ------------------------------------------------------------- blue
		"Capsize":
			c.spell(ReturnToHandEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target permanent")))
			c.with_buyback({"mana": "{3}"})
		"Whim of Volrath":
			c.spell(Whim.new())
			c.with_buyback({"mana": "{2}"})
		"Whispers of the Muse":
			c.spell(DrawEffect.new(1))
			c.with_buyback({"mana": "{5}"})
		# ------------------------------------------------------------ black
		"Corpse Dance":
			c.spell(F.Action.new(_corpse_dance,
				"return the top creature card of your graveyard to the battlefield; it gains haste until end of turn; exile it at the beginning of the next end step",
				null, true).with_ai_role(&"reanimate_top_hasty", {"exiled_at_end_step": true}))
			c.with_buyback({"mana": "{2}"})
		"Disturbed Burial":
			c.spell(ReturnFromGraveyardEffect.new())
			c.with_buyback({"mana": "{3}"})
		"Evincar's Justice":
			c.spell(DamageAllEffect.new(2).and_each_player())
			c.with_buyback({"mana": "{3}"})
		"Imps' Taunt":
			c.spell(F.Action.new(_attacks_if_able, "target creature attacks this turn if able",
				TargetSpec.creature()).with_ai_role(&"force_attack"))
			c.with_buyback({"mana": "{3}"})
		# -------------------------------------------------------------- red
		"Searing Touch":
			c.spell(DamageEffect.new(1).any_target())
			c.with_buyback({"mana": "{4}"})
		# ------------------------------------------------------------ green
		"Elvish Fury":
			c.spell(PumpEffect.new(2, 2))
			c.with_buyback({"mana": "{4}"})
		_: return false
	return true


static func _creature(i: CardInstance) -> bool: return i.is_creature()


# -------------------------------------------------------------- Worthy Cause

## "You gain life equal to the sacrificed creature's toughness." The
## sacrifice is an additional cost paid as the spell is cast (CR 601.2h),
## so its toughness is the creature's as it last existed on the
## battlefield (CR 608.2h): the cost receipt's `toughness` when the engine
## records one, else the card's last-known toughness — a TOKEN ceases to
## exist (CR 111.7) and can only be read from the receipt.
class WorthyCause extends GainLifeEffect:
	func _init() -> void:
		super(0)
		ai_helpful = true
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var gain := 0
		for row in g.cost_paid("_object_costs", []):
			if String(row.get("operation", "")) != "sacrifice": continue
			if row.has("toughness"):
				gain = int(row["toughness"])
			else:
				var body := g.find_instance(int(row.get("id", -1)))
				if body != null: gain = body.last_toughness
			break
		if gain > 0: g.adjust_life(pid, gain)
	func describe() -> String:
		return "you gain life equal to the sacrificed creature's toughness"


# --------------------------------------------------------------- Corpse Dance

## "Return the top creature card of your graveyard to the battlefield" —
## positional, nobody chooses: the topmost card of the caster's own
## graveyard that is a creature card (the graveyard's top is its back).
## Haste until end of turn, and a delayed trigger exiles THAT object at the
## beginning of the next end step if it is still on the battlefield (the
## Corpse Dance ruling; Mirage's Shallow Grave has the same shape).
static func _corpse_dance(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var grave: Array = g.players[pid].graveyard
	var top: CardInstance = null
	for n in range(grave.size() - 1, -1, -1):
		var card: CardInstance = grave[n]
		if card.data.is_creature():
			top = card
			break
	if top == null:
		g.log_line("Corpse Dance: no creature card in %s's graveyard" % g.players[pid].player_name)
		return
	g.reanimate(top, pid)
	if top.zone != Mtg.Zone.BATTLEFIELD: return
	var haste: Array[int] = [Mtg.Keyword.HASTE]
	g.continuous.add_until_eot_pump(top.id, 0, 0, haste)
	g.recalculate()
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _exile_danced,
		"Exile the creature Corpse Dance returned."), pid, s, false,
		{"id": top.id, "stamp": top.layer_timestamp})

static func _exile_danced(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var memory: Dictionary = g.current_delayed().get("memory", {})
	var i := g.find_instance(int(memory.get("id", -1)))
	if i != null and i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == int(memory.get("stamp", -1)):
		g.exile_permanent(i)


# ---------------------------------------------------------------- Imps' Taunt

static func _attacks_if_able(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var i := g.find_instance(t.instance_id) if t != null else null
	if i == null or i.zone != Mtg.Zone.BATTLEFIELD: return
	g._rec(i, &"must_attack_this_turn")
	i.must_attack_this_turn = true
	g.log_line("%s attacks this turn if able" % i.data.card_name)


# ----------------------------------------------------------- Whim of Volrath

## Mind Bend (Mirage) until end of turn: one colour word or one basic land
## type replaced with another in target permanent's text, the words chosen
## on resolution (the rulings), the change ending at cleanup (Pack 9 E8,
## MtgGame.change_text until_eot). SIMPLIFIED (docs/simplified-cards.md,
## "Text changes"): the words are the ones this engine models — protection
## colours, land subtypes and landwalk — so the target must carry one, as
## Mind Bend's does.
class Whim extends EffectBase:
	const LANDS: Array[String] = ["plains", "island", "swamp", "mountain", "forest"]
	func _init() -> void:
		target_spec = TargetSpec.new(TargetSpec.Kind.PERMANENT,
			"target permanent with a color word or basic land type in its text", Whim.has_word)
		with_ai_role(&"text_change", {"until_eot": true})
	static func has_word(i: CardInstance) -> bool:
		if (i.cur_protection & 31) != 0: return true
		for t in LANDS:
			if i.has_subtype(t) or i.cur_landwalk.has(t): return true
		return false
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var victim := g.find_instance(t.instance_id) if t != null else null
		if victim == null or victim.zone != Mtg.Zone.BATTLEFIELD: return
		var kinds: Array[String] = []
		var values: Array = []
		var labels: Array[String] = []
		for c in Mtg.WUBRG:
			if (victim.cur_protection & c) != 0:
				kinds.append("color_word")
				values.append(c)
				labels.append(String(Mtg.COLOR_NAMES[c]))
		for land in LANDS:
			if victim.has_subtype(land) or victim.cur_landwalk.has(land):
				kinds.append("land_type")
				values.append(land)
				labels.append(land.capitalize())
		if labels.is_empty(): return
		var pick := clampi(g.agents[pid].choose_option(g, pid, labels,
			"Whim of Volrath %s: which word?" % victim.data.card_name, 0), 0, labels.size() - 1)
		var others: Array = []
		var names: Array[String] = []
		if kinds[pick] == "color_word":
			for c in Mtg.WUBRG:
				if c != int(values[pick]):
					others.append(c)
					names.append(String(Mtg.COLOR_NAMES[c]))
		else:
			for land in LANDS:
				if land != String(values[pick]):
					others.append(land)
					names.append(land.capitalize())
		var to := clampi(g.agents[pid].choose_option(g, pid, names,
			"Whim of Volrath: %s becomes which word?" % labels[pick], 0), 0, names.size() - 1)
		g.change_text(victim, kinds[pick], values[pick], others[to], true)
	func describe() -> String:
		return "replace one color word or basic land type with another in target permanent's text until end of turn"
