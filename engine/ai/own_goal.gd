extends RefCounted
## THE OWN GOAL (campaign 2026-11-26, bugs1 1-4, 6, 7): the casts and the
## upkeep answers that lose the pilot its own game or its own board, read
## off the card's printed text and the public board — the pilot's own
## hand, both battlefields, both graveyards' and libraries' SIZES. Nothing
## hidden is read, and no card is named: each reading is a printed shape.
##
##  * THE LIBRARY FOR THE GRAVEYARD ("Exile all cards from your library.
##    Then shuffle your graveyard into your library." — Paradigm Shift):
##    cast only when the graveyard is the bigger pile and a library worth
##    having ([constant SHIFT_FLOOR]), or the library is about to run out.
##  * THE DRAW FROM THE GRAVEYARD, OR THE GAME ("If you would draw a card,
##    return a card from your graveyard to your hand instead. If you can't,
##    you lose the game." — Forbidden Crypt): the graveyard is the clock,
##    so it needs [constant CRYPT_FLOOR] cards or more cards than the
##    library it replaces.
##  * THE UPKEEP THAT EATS THE LIBRARY ("When a player doesn't pay this
##    enchantment's cumulative upkeep, that player exiles all cards from
##    their library." — Thought Lash): never cast; on the table, paid
##    whenever it can be, because the price is always less than the whole
##    library.
##  * THE PEACE THAT STOPS OUR OWN ATTACK ("Creatures can't attack." —
##    Peacekeeper): cast, and its rent paid, only while their attack is the
##    bigger one.
##  * THE RESCUE ("Return target permanent you control to its owner's
##    hand", a helpful bounce): a response's card
##    ([method AiPlayer._save_from_the_stack]), never a main-phase cast.
##  * THE SWEEP THAT ARRIVES WITH THE PERMANENT ("When this creature
##    enters, it deals N damage to each other creature" — Crater Hellion;
##    "At the beginning of your upkeep, … destroy all creatures" — Planar
##    Collapse): the symmetric-sweep pricing of urza_spells.gd, what each
##    side loses.
##
## All of it behind [member AiProfile.forecasts_tactics], which every
## standard rung ships on: the gate off is the pilot as it was.

## The graveyard a library swap wants before it is worth a card.
const SHIFT_FLOOR := 15
## A library this small is about to lose us the game by itself.
const LIBRARY_PANIC := 3
## The draws a graveyard must hold before it may stand in for the library.
const CRYPT_FLOOR := 10
## The symmetric sweep's bar, urza_spells.gd's own.
const SWEEP_BAR := 3.0

const SHIFT_LINE := "Exile all cards from your library. Then shuffle your graveyard into your library"
const CRYPT_LINE := "If you would draw a card, return a card from your graveyard to your hand instead. If you can't, you lose the game"
const LASH_LINE := "cumulative upkeep, that player exiles all cards from their library"
const PEACE_LINE := "Creatures can't attack."

static var _arrival_burn: RegEx = null
static var _upkeep_wrath: RegEx = null


## Why [param inst], a card in the pilot's hand, is not cast in this
## position ("" when nothing here objects) — [method AiPlayer._cast_gate]'s
## last question.
static func cast_refusal(g: MtgGame, pilot, inst: CardInstance) -> String:
	if not pilot.profile.forecasts_tactics:
		return ""
	var data: CardData = inst.data
	var text: String = data.oracle_text
	if text.is_empty():
		return ""
	var me = g.players[pilot.pid]
	if not data.is_permanent_type() and text.contains(SHIFT_LINE):
		var pile: int = me.graveyard.size()
		var deck: int = me.library.size()
		if pile <= deck or (pile < SHIFT_FLOOR and deck > LIBRARY_PANIC):
			return "the graveyard is no library yet"
		return ""
	if not data.is_permanent_type():
		return ""
	if text.contains(CRYPT_LINE):
		var pile: int = me.graveyard.size()
		if pile < CRYPT_FLOOR and pile <= int(me.library.size()):
			return "the graveyard would run dry"
		return ""
	if text.contains(LASH_LINE):
		return "its upkeep ends in the whole library"
	if stops_attacks(data) and not peace_wanted(g, pilot, null):
		return "our attack is the bigger one"
	return _arrival_sweep_refusal(g, pilot, inst)


## Does a static of [param data] stop every attack — "Creatures can't
## attack." and nothing more (a Moat's "without flying" is another card)?
static func stops_attacks(data: CardData) -> bool:
	for ability in data.static_abilities:
		if String(ability.text).strip_edges() == PEACE_LINE:
			return true
	return false


## Is "creatures can't attack" worth having right now? Yes while their
## creatures carry more power than ours ([param keeper], the permanent
## that makes the peace, left out of our count), and with no attack of
## ours to lose at all.
static func peace_wanted(g: MtgGame, pilot, keeper: CardInstance) -> bool:
	var ours := _attack_power(g, pilot.pid, keeper)
	return ours <= 0 or _attack_power(g, g.opponent_of(pilot.pid), null) > ours


static func _attack_power(g: MtgGame, who: int, skip: CardInstance) -> int:
	var total := 0
	for body in g.players[who].creatures():
		if body == skip or not g.is_present(body) or body.has_keyword(Mtg.Keyword.DEFENDER):
			continue
		total += maxi(body.cur_power, 0)
	return total


## An upkeep question this module answers: 1 yes, 0 no, -1 not ours
## ([method AiPlayer.answer_yes_no]). [param subject] is the permanent of
## ours the question names, [param hint] the asker's own answer.
static func upkeep_answer(g: MtgGame, pilot, prompt: String, subject: CardInstance,
		hint: bool) -> int:
	if not pilot.profile.forecasts_tactics or subject == null:
		return -1
	# The library is the price either way; paying takes the smaller part.
	if prompt.begins_with("Exile ") and prompt.contains("cumulative upkeep") \
			and subject.data.oracle_text.contains(LASH_LINE):
		return 1
	# The rent of a peace we no longer want is not paid.
	if hint and prompt.begins_with("Pay ") and stops_attacks(subject.data) \
			and not subject.cur_abilities_silenced \
			and not peace_wanted(g, pilot, subject):
		return 0
	return -1


## Is [param inst] a rescue — an instant whose one effect returns a
## permanent WE control to hand, marked helpful by its card? Its moment is
## a response to losing the permanent, not our main phase.
static func is_rescue(pilot, inst: CardInstance) -> bool:
	if not pilot.profile.forecasts_tactics or not inst.is_type(Mtg.CardType.INSTANT) \
			or inst.data.is_modal() or inst.data.spell_effects.size() != 1:
		return false
	var e: EffectBase = inst.data.spell_effects[0]
	return e is ReturnToHandEffect and e.ai_helpful and e.target_spec != null


## The sweep [param inst] brings with it, priced as the symmetric sweeps
## are: "" when it may be cast.
static func _arrival_sweep_refusal(g: MtgGame, pilot, inst: CardInstance) -> String:
	var text: String = inst.data.oracle_text
	if not text.contains("creature"):
		return ""
	if _arrival_burn == null:
		_arrival_burn = RegEx.create_from_string(
			"When this creature enters, it deals (\\d+) damage to each (other )?creature")
		_upkeep_wrath = RegEx.create_from_string(
			"At the beginning of your upkeep, [^\\n]*destroy all creatures")
	var damage := -1
	var found := _arrival_burn.search(text)
	if found != null:
		damage = int(found.get_string(1))
	elif _upkeep_wrath.search(text) == null:
		return ""
	var ours := _swept_worth(g, pilot, pilot.pid, damage)
	var theirs := _swept_worth(g, pilot, g.opponent_of(pilot.pid), damage)
	if damage < 0:
		# No body comes with it: a sweep and nothing else.
		return "" if theirs - ours >= SWEEP_BAR else "the sweep takes more of ours"
	# A body comes with it: refused when the sweep costs us more than the
	# body and their losses together are worth.
	if ours - theirs > Evaluator.card_value(inst.data):
		return "the sweep takes more of ours"
	return ""


## What [param who] loses to a sweep of [param damage] to each creature
## (every creature when negative), at [method Evaluator.permanent_value].
static func _swept_worth(g: MtgGame, pilot, who: int, damage: int) -> float:
	var total := 0.0
	for body in g.players[who].creatures():
		if not g.is_present(body):
			continue
		if damage >= 0 and body.cur_toughness - body.damage > damage:
			continue
		total += Evaluator.permanent_value(body, pilot.profile)
	return total
