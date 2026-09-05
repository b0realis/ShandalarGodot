class_name PreventDamageShieldEffect
extends EffectBase
## The Circle of Protection payload: "The next time a [color] source would
## deal damage to you this turn, prevent that damage."
##
## Resolving adds one one-shot shield (an Mtg.ManaColor mask) to the
## CONTROLLER's MtgPlayer.prevention_shields; MtgGame.deal_damage consumes
## a matching shield instead of dealing the damage; cleanup clears leftover
## shields. Multiple activations stack — the classic CoP lock against a
## mono-colored deck is fully reproduced.
##
## TWO SHAPES, one per ruleset (docs/duel-todo.md §6.8). Under the 1997
## DAMAGE-PREVENTION WINDOW the Circle does what its own ruling says —
## *"May only be used during damage prevention, as it targets PACKETS of
## the appropriate damage"* — and this effect takes an OPTIONAL
## [constant TargetSpec.Kind.DAMAGE] target: the player clicks the damage
## marker and exactly that packet is prevented. `@CIRCLE_OF_PROTECTION`
## (`prompts.txt:185`) is the original's own prompt for the click:
## `Select damage card.`
##
## With the window off (the modern default) there are never any packets to
## click, no target is taken, and the Circle does what its modern text
## says: "a [colour] source OF YOUR CHOICE" — the controller names ONE
## source as the ability resolves (DecisionAgent.choose_card over
## MtgGame.damage_sources of the colour, ranked so the first entry is
## the one about to deal damage: a spell on the stack aimed at them, an
## unblocked attacker...), and the shield is a one-shot
## MtgPlayer.prevention_shield_filters entry bound to that source's id.
## A Circle activated with no source of the colour in sight — before the
## Bolt is cast — shields nothing (CR 608.2: a choice with nothing to
## choose does nothing), which is the printed card and the reason the
## Circle is activated in RESPONSE.

## Which source colors the shield stops (Mtg.ManaColor mask). 0 when the
## shield is keyed on a PREDICATE instead (Circle of Protection:
## Artifacts) — see [member source_filter].
var color_mask: int

## Optional source predicate func(source: CardInstance) -> bool, used
## instead of the colour mask when set.
var source_filter: Callable = Callable()

## Card-English name of what the predicate matches ("an artifact source"),
## for the log line and [method describe]. Empty = colour-keyed shield.
var source_desc: String = ""


func _init(p_color_mask: int) -> void:
	color_mask = p_color_mask
	is_damage_prevention = true   # legal in the 1997 window (§6.8)
	# "Select damage card." — the 1997 click, which only ever has anything
	# to click while a damage-prevention window is open.
	target_spec = TargetSpec.damage("target damage from a %s source"
		% Mtg.COLOR_NAMES.get(p_color_mask, "colored"), _packet_matches)
	optional_target()


## Fluent: key the shield on an arbitrary source predicate instead of a
## colour (Circle of Protection: Artifacts).
func from_sources(desc: String, cb: Callable) -> PreventDamageShieldEffect:
	source_filter = cb
	source_desc = desc
	target_spec = TargetSpec.damage("target damage from %s" % desc,
		_packet_matches)
	return self


## Does this waiting packet match what this Circle stops? Two halves, and
## the second one was missing until 2026-09-01:
##
##  * its SOURCE — the same question [method resolve] would ask when the
##    shield is consumed, asked of the packet instead, which is the whole
##    difference between the two rulesets;
##  * its VICTIM. Every Circle in the pool reads *"would deal damage TO
##    YOU"*, so a packet aimed at a creature — even one you control, even
##    one of the right colour — is not a legal target for it. The shield
##    form has always been right about this (it is consumed on the player
##    branch of `_land_damage` and nowhere else); the 1997 targeted form
##    was not, and an AI looking for the cheapest effect that covers a
##    packet found the hole immediately.
##
## [param who] is the Circle itself, so "you" is its controller.
func _packet_matches(_game: MtgGame, packet: DamagePacket,
		who: CardInstance) -> bool:
	if packet.source == null or packet.target == null:
		return false
	if not packet.target.is_player:
		return false
	if who != null and packet.target.player_id != who.controller_id:
		return false
	if source_filter.is_valid():
		return bool(source_filter.call(packet.source))
	return (color_mask & packet.source.cur_colors) != 0


## Pushes one shield onto the CONTROLLER's MtgPlayer.prevention_shields (or
## prevention_shield_filters for the predicate flavour). Shields are consumed
## whole by MtgGame.deal_damage and cleared at cleanup. Note it always shields
## the ACTIVATOR, never a target — every Circle in the pool reads "to you",
## and the ability is the activating player's, so no target is needed.
func resolve(game: MtgGame, source: CardInstance, controller: int, target: TargetRef,
		_x_value: int = 0) -> void:
	# THE 1997 FORM: one named packet, prevented outright. "However, you
	# may use the Circle on the same damage more than once" — so a packet
	# already fully prevented is still a legal target, and a second use
	# simply has nothing left to take.
	if target != null and target.is_damage:
		var packet := game.find_packet(target.packet_id)
		if packet == null:
			return
		var stopped := packet.prevent(packet.remaining())
		game.log_line("%s prevents %d damage from %s (circle of protection)" % [
			source.data.card_name, stopped,
			"?" if packet.source == null else packet.source.data.card_name])
		return
	# THE MODERN FORM: one source of the colour, the controller's choice.
	var kind: String = source_desc if source_desc != "" \
		else "a %s source" % _colour_words()
	var choices := game.damage_sources(_source_qualifies, TargetRef.player(controller))
	if choices.is_empty():
		game.log_line("%s: nothing to name as %s, nothing is shielded" % [
			source.data.card_name, kind])
		return
	var named := game.agents[controller].choose_card(game, controller, choices,
		"%s: Select %s." % [source.data.card_name, kind], false, false, true)
	if named == null or not choices.has(named):
		named = choices[0]
	game.players[controller].prevention_shield_filters.append({
		"desc": "%s (%s)" % [source.data.card_name, named.data.card_name],
		"filter": PreventDamageShieldEffect._is_source.bind(named.id),
	})
	game.log_line("%s shields %s against %s this turn" % [
		source.data.card_name, game.players[controller].player_name,
		named.data.card_name])


## Is [param inst] a source this Circle may name — of the colour, or of
## the predicate's kind?
func _source_qualifies(inst: CardInstance) -> bool:
	if source_filter.is_valid():
		return bool(source_filter.call(inst))
	return (color_mask & inst.cur_colors) != 0


## "red", "black or red" — the mask in card English, for the prompt.
func _colour_words() -> String:
	var words: Array[String] = []
	for color in Mtg.WUBRG:
		if (color_mask & color) != 0:
			words.append(String(Mtg.COLOR_NAMES.get(color, "?")).to_lower())
	if words.is_empty():
		return "colored"
	return " or ".join(words)


static func _is_source(inst: CardInstance, id: int) -> bool:
	return inst != null and inst.id == id


## One-line log/UI text.
func describe() -> String:
	if source_desc != "":
		return "prevents the next damage from %s to you this turn" % source_desc
	return "prevents the next damage from a %s source to you this turn" \
		% Mtg.COLOR_NAMES.get(color_mask, "?")
