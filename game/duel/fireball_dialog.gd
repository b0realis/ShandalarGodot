class_name FireballDialog
extends RefCounted
## THE X DIALOG — `@DIALOG_FIREBALL`
## (`shandalar-src/Program/UIStrings.txt:657`), seven strings:
##
##     Generic &mana to put into the spell:
##     (max: %d)
##     X cost:
##     Cost for additional targets:
##     # &Targets:
##     (max %d)
##     Amount of damage to be done each target:
##
## The original named the dialog after the card that needs all seven. Two
## of them — the question and its bound — are the whole of the dialog for
## an ordinary {X} spell (Braingeyser, Disintegrate, Howl from Beyond);
## the other five appear only when the spell also buys TARGETS with the
## same mana, which in this pool is Fireball alone
## ([member CardData.extra_cost_per_target]).
##
## WHAT THE SEVEN STRINGS ADD UP TO, and why `X cost:` is a read-out and
## not a second field: the player spends ONE pot of generic mana, and the
## dialog shows how it is divided.
##
##     Generic mana to put into the spell:  [ 7 ]  (max: 7)
##     X cost:                                5
##     Cost for additional targets:           2
##     # Targets:                           [ 3 ]  (max 4)
##     Amount of damage to be done each target:  1
##
## Seven mana in; two of them bought the second and third targets at the
## card's own *"costs {1} more to cast for each target beyond the first"*;
## the remaining five are X; and Fireball divides X **evenly, rounded
## down** among the targets, so each takes one. That is why the last line
## says *each* target rather than offering a per-target field: dividing
## evenly is Fireball's printed rule, not a choice.
##
## THIS IS NOT THE DIVIDED-DAMAGE DIAL. `docs/duel-todo.md` §6.14 called it
## one and it is not: the original's dial for *"N damage divided as you
## choose"* is a CLICK LOOP, not a dialog — `@PYROTECHNICS`
## (`Program/prompts.txt:698`) is four prompts, `Select (1st of 4) target
## creature or player.` through `(4th of 4)`, one click per point of
## damage, exactly like `@PROMPT_RESOLVECOMBAT`'s `%d points left`
## (§1.4/§6.9). The section carries the full finding; the loop itself is
## in `DuelScreen._advance_pending`.
##
## THE BUG THIS FIXES. X used to be asked BEFORE targets and priced
## without them, so Fireball offered the whole pool as X and then refused
## the cast the moment a second target was picked — the surcharge had
## nowhere to come from. Asking both in one dialog is what makes the
## budget add up, which is the reason the original's dialog has two
## fields in it.

## Entry 1 — the question. Windows' `&` accelerator markers are dropped,
## as they are everywhere else in the duel (§6.1, §6.4).
const ASK_MANA := "Generic mana to put into the spell:"
## Entry 2 — the bound, printed beside the field. Note the colon: entry 6
## has none, and both are reproduced exactly as the table has them.
const MAX_MANA := "(max: %d)"
## Entry 3.
const X_COST := "X cost:"
## Entry 4.
const EXTRA_COST := "Cost for additional targets:"
## Entry 5.
const ASK_TARGETS := "# Targets:"
## Entry 6.
const MAX_TARGETS := "(max %d)"
## Entry 7.
const EACH_TARGET := "Amount of damage to be done each target:"


## THE ARITHMETIC, pure so it can be tested without a screen.
##
## [param budget] is the most generic mana this pool can put into the
## spell at all (the caller counts it against [method ManaPool.can_pay],
## so it already has the printed cost and any Mana-Matrix-style surcharge
## taken out of it). [param mana] is what the player dialled in,
## [param targets] how many they want, [param per_target] the card's
## *"{1} more for each target beyond the first"*, [param x_count] the
## number of `{X}` symbols in the cost (Part Water's `{X}{X}{U}` charges
## the chosen X twice).
##
## Returns the four numbers the dialog prints, plus the two live bounds:
## `x_cost`, `extra`, `x`, `each`, `max_mana`, `max_targets`.
static func plan(budget: int, mana: int, targets: int, per_target: int,
		x_count := 1) -> Dictionary:
	var per := maxi(per_target, 0)
	var count := maxi(targets, 1)
	var spent: int = clampi(mana, 0, maxi(budget, 0))
	var extra: int = per * (count - 1)
	# The surcharge is paid out of the same pot, so it can eat the whole
	# of X — never past it, which is what clamping at 0 says.
	var x_cost: int = maxi(spent - extra, 0)
	var x: int = x_cost / maxi(x_count, 1)
	return {
		"x_cost": x_cost,
		"extra": extra,
		"x": x,
		"each": x / count,
		"max_mana": maxi(budget, 0),
		# Every target past the first costs `per` more out of the SAME
		# pot, so the bound moves with what has been put in — dial the
		# mana up and more targets become affordable, dial the targets up
		# and X falls. That trade is the whole reason the original put
		# both fields in one window.
		"max_targets": 1 + (spent / per if per > 0 else 0),
	}


## Build the window. [param label] titles it (the card's name, as every
## other duel dialog is titled), [param budget] is the mana bound, and
## [param per_target] > 0 turns on the five strings that only Fireball
## needs. [param legal_targets] caps the target field at what is actually
## on the table — *"any number of targets"* is bounded by what exists
## (CR 601.2c), and the original's `(max %d)` is where the player reads it.
##
## The returned dialog carries its two SpinBoxes as metadata (`mana` and
## `targets`) so the caller can read the answer back without holding a
## reference to every control; a plain {X} spell has no `targets` box.
static func window(label: String, budget: int, per_target: int,
		legal_targets: int, x_count := 1) -> OriginalDialog:
	var full := per_target > 0
	var dialog := OriginalDialog.create(label,
		Vector2(392, 320 if full else 208), "panel_dark_stone")
	var box := dialog.body()

	var ask := OriginalDialog.label(ASK_MANA, 15)
	ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(ask)
	var mana_row := HBoxContainer.new()
	mana_row.add_theme_constant_override("separation", 10)
	var mana_spin := OriginalDialog.field(96.0)
	mana_spin.min_value = 0
	mana_spin.max_value = budget
	# `{X}{X}` (Part Water, Voodoo Doll) charges the chosen X once per
	# printed `{X}`, so only multiples of [param x_count] buy a whole
	# point of X and anything between them is mana thrown away. Stepping
	# the field by that count is what makes entry 1 literally true — the
	# player really is putting GENERIC MANA in, not X.
	mana_spin.step = 1 if full else maxi(x_count, 1)
	mana_spin.value = budget
	mana_row.add_child(mana_spin)
	mana_row.add_child(OriginalDialog.label(MAX_MANA % budget, 15))
	box.add_child(mana_row)
	dialog.set_meta("mana", mana_spin)
	if not full:
		return dialog

	var x_line := OriginalDialog.label("%s 0" % X_COST, 15)
	box.add_child(x_line)
	var extra_line := OriginalDialog.label("%s 0" % EXTRA_COST, 15)
	box.add_child(extra_line)

	var target_row := HBoxContainer.new()
	target_row.add_theme_constant_override("separation", 10)
	target_row.add_child(OriginalDialog.label(ASK_TARGETS, 15))
	var target_spin := OriginalDialog.field(72.0)
	target_spin.min_value = 1
	target_spin.max_value = maxi(legal_targets, 1)
	target_spin.value = 1
	target_row.add_child(target_spin)
	var target_max := OriginalDialog.label(
		MAX_TARGETS % maxi(legal_targets, 1), 15)
	target_row.add_child(target_max)
	box.add_child(target_row)
	dialog.set_meta("targets", target_spin)

	var each_line := OriginalDialog.label("%s 0" % EACH_TARGET, 15)
	each_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(each_line)

	# The three read-outs and the two bounds are recomputed on every
	# keystroke — *"showing the additional-target cost as it went"* is the
	# whole reason the original put them in the same window.
	var repaint := func() -> void:
		var seen := plan(budget, int(mana_spin.value), int(target_spin.value),
			per_target, x_count)
		x_line.text = "%s %d" % [X_COST, int(seen["x_cost"])]
		extra_line.text = "%s %d" % [EXTRA_COST, int(seen["extra"])]
		each_line.text = "%s %d" % [EACH_TARGET, int(seen["each"])]
		var cap: int = mini(int(seen["max_targets"]), maxi(legal_targets, 1))
		target_spin.max_value = cap
		target_max.text = MAX_TARGETS % cap
	mana_spin.value_changed.connect(func(_v: float) -> void: repaint.call())
	target_spin.value_changed.connect(func(_v: float) -> void: repaint.call())
	repaint.call()
	return dialog
