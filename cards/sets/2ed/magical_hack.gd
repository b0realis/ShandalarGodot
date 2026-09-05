extends CardScript
## Magical Hack — {U} — Instant — (2ed, rare)
## Oracle: Change the text of target spell or permanent by replacing all
##         instances of one basic land type with another. (For example, you
##         may change "swampwalk" to "plainswalk." This effect lasts
##         indefinitely.)
##
## Implementation: an indefinite TEXT CHANGE (CR 613 layer 3) rewriting one
## basic land type into another wherever the object carries it — its
## subtypes (so a Mountain really becomes an Island and taps for {U}) and
## its landwalk (so swampwalk really becomes plainswalk).
##
## The spec is "target SPELL OR PERMANENT" (the Laces' TargetSpec kind), so
## a creature spell still on the stack can be re-tuned before it lands —
## the text change is stamped on the card and rides along into play.
##
## The pair of land types is the CASTER's: two DecisionAgent.choose_option
## questions on resolution — the word to replace, from the basic types the
## target's text actually carries, then the type it becomes, from the four
## others — logged the original's way (`@MAGICAL_HACK`, Program/
## prompts.txt:561: "Hacking %s to %s."). The heuristic hacks the target's
## first type into one its controller's OPPONENT actually has on the
## battlefield, which is the use every 1997 guide describes.
##
## SIMPLIFIED (docs/simplified-cards.md, "Text changes"): a text change
## only reaches what this engine stores — subtypes, landwalk and a basic
## land's mana — not arbitrary rules text.


const BASICS := ["plains", "island", "swamp", "mountain", "forest"]


static func _has_a_basic_word(inst: CardInstance) -> bool:
	for t in BASICS:
		if inst.has_subtype(t) or inst.cur_landwalk.has(t):
			return true
	return false


func build() -> CardData:
	return CardData.new("Magical Hack", "{U}", Mtg.CardType.INSTANT) \
		.spell(MagicalHackEffect.new(TargetSpec.spell_or_permanent(
			"target spell or permanent with a basic land type in its text",
			_has_a_basic_word))) \
		.oracle("Change the text of target spell or permanent by replacing all instances of one basic land type with another. (For example, you may change \"swampwalk\" to \"plainswalk.\" This effect lasts indefinitely.)")


class MagicalHackEffect extends EffectBase:
	## Preference order for the replacement type.
	const ORDER := ["island", "swamp", "mountain", "forest", "plains"]

	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var victim := game.find_instance(target.instance_id)
		# A text change is legal on a SPELL too (CR 613 layer 3 applies to
		# the object wherever it is): the rewrite is stamped on the card
		# while it is still on the stack and rides along into play.
		if victim == null or (victim.zone != Mtg.Zone.BATTLEFIELD
				and victim.zone != Mtg.Zone.STACK):
			return
		# The words the text carries, in printed WUBRG order; the hint is
		# the first of them by the preference order.
		var present: Array[String] = []
		for t in BASICS:
			if victim.has_subtype(t) or victim.cur_landwalk.has(t):
				present.append(t)
		if present.is_empty():
			return
		var from_hint := 0
		for t in MagicalHackEffect.ORDER:
			if present.has(t):
				from_hint = present.find(t)
				break
		var from_type: String = present[game.agents[controller].choose_option(
			game, controller, present,
			"Magical Hack %s: which land type?" % victim.data.card_name, from_hint)]
		var others: Array[String] = []
		for t in BASICS:
			if t != from_type:
				others.append(t)
		var to_hint := others.find(
			MagicalHackEffect._useful_type(game, victim.controller_id, from_type))
		var to_type: String = others[game.agents[controller].choose_option(
			game, controller, others,
			"Magical Hack: %s becomes which land type?" % from_type, maxi(to_hint, 0))]
		game.log_line("Hacking %s to %s." % [from_type, to_type])
		game.change_text(victim, "land_type", from_type, to_type)

	## The type worth switching TO: one the TARGET's controller's opponent
	## actually has in play (so a hacked landwalk connects, and a hacked
	## land retunes into something its controller can't use).
	static func _useful_type(game: MtgGame, victim_controller: int, avoid: String) -> String:
		var enemy := game.opponent_of(victim_controller)
		for t in MagicalHackEffect.ORDER:
			if t == avoid:
				continue
			for land in game.players[enemy].battlefield:
				if land.is_land() and land.has_subtype(t):
					return t
		return "island" if avoid != "island" else "plains"

	func describe() -> String:
		return "replaces one basic land type with another in a spell or permanent's text"
