extends CardScript
## Sleight of Mind — {U} — Instant — (2ed, rare)
## Oracle: Change the text of target spell or permanent by replacing all
##         instances of one color word with another. (For example, you may
##         change "target black spell" to "target blue spell." This effect
##         lasts indefinitely.)
##
## Implementation: an indefinite TEXT CHANGE (CR 613 layer 3) rewriting one
## colour word into another wherever the object carries one — which, in an
## engine that stores rules as behaviour rather than text, means its
## PROTECTION colours. Sleight of Mind's headline use is exactly that:
## re-pointing a Black Knight's protection from white to some colour you
## aren't playing. The spec is "target SPELL OR PERMANENT" (the Laces'
## TargetSpec kind), so the Knight can be re-pointed while it is still on
## the stack — the change is stamped on the card and rides into play.
##
## The pair of colours is the CASTER's: two DecisionAgent.choose_option
## questions on resolution — the colour word to replace, from the ones the
## target's text carries, then the colour it becomes, from the four others
## — logged the original's way (`@SLEIGHT_OF_MIND`, Program/
## prompts.txt:806: "Sleighting %s to %s."). The heuristic moves the
## protection colour the caster actually plays onto one the caster does
## not.
##
## SIMPLIFIED (docs/simplified-cards.md, "Text changes"): a text change
## only reaches what this engine stores — protection colours — not
## arbitrary rules text.


static func _has_a_color_word(inst: CardInstance) -> bool:
	return inst.cur_protection != 0


func build() -> CardData:
	return CardData.new("Sleight of Mind", "{U}", Mtg.CardType.INSTANT) \
		.spell(SleightEffect.new(TargetSpec.spell_or_permanent(
			"target spell or permanent with a color word in its text",
			_has_a_color_word))) \
		.oracle("Change the text of target spell or permanent by replacing all instances of one color word with another. (For example, you may change \"target black spell\" to \"target blue spell.\" This effect lasts indefinitely.)")


class SleightEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var victim := game.find_instance(target.instance_id)
		# A text change is legal on a SPELL too (CR 613 layer 3 applies to
		# the object wherever it is): re-point a Black Knight's protection
		# while it is still on the stack and it enters already re-pointed.
		if victim == null or (victim.zone != Mtg.Zone.BATTLEFIELD
				and victim.zone != Mtg.Zone.STACK):
			return
		# The colour words the text carries, in WUBRG order.
		var present: Array[int] = []
		for c in Mtg.WUBRG:
			if (victim.cur_protection & c) != 0:
				present.append(c)
		if present.is_empty():
			return
		# The hint: the colour worth removing is one the caster actually
		# plays…
		var mine := SleightEffect._colors_of(game, controller)
		var from_hint := 0
		for i in present.size():
			if (mine & present[i]) != 0:
				from_hint = i
				break
		var from_color: int = present[game.agents[controller].choose_option(
			game, controller, SleightEffect._names(present),
			"Sleight of Mind %s: which color word?" % victim.data.card_name, from_hint)]
		# …and it becomes one the caster does NOT play.
		var others: Array[int] = []
		for c in Mtg.WUBRG:
			if c != from_color:
				others.append(c)
		var to_hint := 0
		for i in others.size():
			if (mine & others[i]) == 0:
				to_hint = i
				break
		var to_color: int = others[game.agents[controller].choose_option(
			game, controller, SleightEffect._names(others),
			"Sleight of Mind: %s becomes which color?" % Mtg.COLOR_NAMES[from_color],
			to_hint)]
		game.log_line("Sleighting %s to %s." % [
			Mtg.COLOR_NAMES[from_color], Mtg.COLOR_NAMES[to_color]])
		game.change_text(victim, "color_word", from_color, to_color)

	static func _names(colors: Array[int]) -> Array[String]:
		var out: Array[String] = []
		for c in colors:
			out.append(Mtg.COLOR_NAMES[c])
		return out

	## Every colour the player has on the battlefield or in hand.
	static func _colors_of(game: MtgGame, pid: int) -> int:
		var mask := 0
		for card in game.players[pid].battlefield:
			mask |= card.cur_colors
		for card in game.players[pid].hand:
			mask |= card.data.color_mask()
		return mask

	func describe() -> String:
		return "replaces one color word with another in a spell or permanent's text"
