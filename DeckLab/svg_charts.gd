class_name SvgCharts
extends RefCounted
## Dependency-free SVG chart generation for the Deck Lab. Pure string
## building — the output opens in any browser or image viewer, embeds in
## forum posts, and needs no plotting library anywhere in the pipeline.
##
## Two chart kinds, matching the tool's two questions:
## - [method winrate_chart]: horizontal bars, one per opponent — deck A's
##   winrate with its Wilson 95% CI drawn as a whisker, a 50% reference
##   line, and play/draw split ticks.
## - [method turns_chart]: game-length histograms, one row per matchup,
##   sharing an x-axis so speeds compare across opponents.

const FONT := "font-family='Georgia, serif'"
const BAR_COLOR := "#7a5b2e"
const CI_COLOR := "#2b2118"
const GRID_COLOR := "#c9bfa8"
const BG := "#efe8d6"
const INK := "#2b2118"


## [param rows]: [{label: String, stats: Dictionary (SimStats.summarize)}].
static func winrate_chart(deck_a_name: String, rows: Array) -> String:
	var width := 860
	var row_height := 44
	var top := 70
	var chart_left := 230
	var chart_width := 560
	var height := top + rows.size() * row_height + 50
	var parts := PackedStringArray()
	parts.append('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % [width, height, width, height])
	parts.append('<rect width="%d" height="%d" fill="%s"/>' % [width, height, BG])
	parts.append('<text x="20" y="34" %s font-size="20" fill="%s">%s — win rate by opponent (Wilson 95%% CI)</text>' % [FONT, INK, deck_a_name.xml_escape()])
	# Grid: 0/25/50/75/100%.
	for i in 5:
		var x := chart_left + chart_width * i / 4.0
		var strong := i == 2   # the 50% line
		parts.append('<line x1="%.0f" y1="%d" x2="%.0f" y2="%d" stroke="%s" stroke-width="%d"/>' % [
			x, top - 14, x, height - 40, INK if strong else GRID_COLOR, 2 if strong else 1])
		parts.append('<text x="%.0f" y="%d" %s font-size="12" fill="%s" text-anchor="middle">%d%%</text>' % [
			x, height - 22, FONT, INK, i * 25])
	var y := top
	for row in rows:
		var stats: Dictionary = row.stats
		var wr: Dictionary = stats.winrate
		parts.append('<text x="%d" y="%d" %s font-size="14" fill="%s" text-anchor="end">%s</text>' % [
			chart_left - 12, y + 19, FONT, INK, String(row.label).xml_escape()])
		var bar_width: float = chart_width * wr.mid
		parts.append('<rect x="%d" y="%d" width="%.1f" height="22" fill="%s" rx="3"/>' % [
			chart_left, y + 4, bar_width, BAR_COLOR])
		# CI whisker.
		var x_low: float = chart_left + chart_width * wr.low
		var x_high: float = chart_left + chart_width * wr.high
		var whisker_y := y + 15
		parts.append('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="%s" stroke-width="2"/>' % [
			x_low, whisker_y, x_high, whisker_y, CI_COLOR])
		for x_cap in [x_low, x_high]:
			parts.append('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="%s" stroke-width="2"/>' % [
				x_cap, whisker_y - 5, x_cap, whisker_y + 5, CI_COLOR])
		parts.append('<text x="%.1f" y="%d" %s font-size="13" fill="%s">%s  (%d-%d)</text>' % [
			maxf(chart_left + bar_width + 8, x_high + 8), y + 19, FONT, INK,
			SimStats.percent(wr.mid).strip_edges(), stats.a_wins, stats.b_wins])
		y += row_height
	parts.append('</svg>')
	return "\n".join(parts)


## Round-robin heatmap: cell (row, col) = row deck's winrate vs col deck.
## [param names]: deck names; [param grid]: Dictionary {"r,c": winrate
## fraction} for r != c (missing cells render as diagonal blanks).
static func matrix_chart(names: Array, grid: Dictionary) -> String:
	var n := names.size()
	var cell := 92
	var left := 220
	var top := 120
	var width := left + n * cell + 40
	var height := top + n * cell + 40
	var parts := PackedStringArray()
	parts.append('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % [width, height, width, height])
	parts.append('<rect width="%d" height="%d" fill="%s"/>' % [width, height, BG])
	parts.append('<text x="20" y="34" %s font-size="20" fill="%s">Matchup matrix — row deck\'s win rate vs column deck</text>' % [FONT, INK])
	for i in n:
		var label := String(names[i]).xml_escape()
		# Column headers, angled to fit.
		parts.append('<text x="%d" y="%d" %s font-size="12" fill="%s" transform="rotate(-35 %d %d)">%s</text>' % [
			left + i * cell + 8, top - 12, FONT, INK,
			left + i * cell + 8, top - 12, label])
		# Row labels.
		parts.append('<text x="%d" y="%d" %s font-size="13" fill="%s" text-anchor="end">%s</text>' % [
			left - 10, top + i * cell + cell / 2 + 4, FONT, INK, label])
	for r in n:
		for c in n:
			var x := left + c * cell
			var y := top + r * cell
			var key := "%d,%d" % [r, c]
			if not grid.has(key):
				parts.append('<rect x="%d" y="%d" width="%d" height="%d" fill="#ddd3bc" stroke="%s"/>' % [
					x, y, cell - 2, cell - 2, GRID_COLOR])
				continue
			var winrate: float = grid[key]
			parts.append('<rect x="%d" y="%d" width="%d" height="%d" fill="%s" stroke="%s"/>' % [
				x, y, cell - 2, cell - 2, _matrix_color(winrate), GRID_COLOR])
			parts.append('<text x="%d" y="%d" %s font-size="15" fill="%s" text-anchor="middle">%d%%</text>' % [
				x + cell / 2, y + cell / 2 + 5, FONT, INK, roundi(winrate * 100)])
	parts.append('</svg>')
	return "\n".join(parts)


## Red (losing) through parchment (even) to green (winning).
static func _matrix_color(winrate: float) -> String:
	var t := clampf(winrate, 0.0, 1.0)
	var low := Color("#b65a41")
	var mid := Color("#efe8d6")
	var high := Color("#6f9a5d")
	var color := low.lerp(mid, t * 2.0) if t < 0.5 else mid.lerp(high, (t - 0.5) * 2.0)
	return "#" + color.to_html(false)


## [param rows]: [{label: String, histogram: Dictionary turn->count}].
static func turns_chart(deck_a_name: String, rows: Array) -> String:
	var max_turn := 1
	var max_count := 1
	for row in rows:
		for t in row.histogram:
			max_turn = maxi(max_turn, t)
			max_count = maxi(max_count, row.histogram[t])
	max_turn = mini(max_turn, 40)   # tail-clip for readability
	var width := 860
	var band := 84
	var top := 60
	var chart_left := 230
	var chart_width := 560
	var height := top + rows.size() * band + 40
	var parts := PackedStringArray()
	parts.append('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % [width, height, width, height])
	parts.append('<rect width="%d" height="%d" fill="%s"/>' % [width, height, BG])
	parts.append('<text x="20" y="34" %s font-size="20" fill="%s">%s — game length by opponent (turns)</text>' % [FONT, INK, deck_a_name.xml_escape()])
	var y := top
	for row in rows:
		parts.append('<text x="%d" y="%d" %s font-size="14" fill="%s" text-anchor="end">%s</text>' % [
			chart_left - 12, y + band / 2, FONT, INK, String(row.label).xml_escape()])
		parts.append('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="%s"/>' % [
			chart_left, y + band - 18, chart_left + chart_width, y + band - 18, GRID_COLOR])
		var slot: float = float(chart_width) / max_turn
		for t in row.histogram:
			var turn: int = mini(t, max_turn)
			var bar_height: float = (band - 26) * float(row.histogram[t]) / max_count
			parts.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s"/>' % [
				chart_left + (turn - 1) * slot, y + band - 18 - bar_height,
				maxf(slot - 1.0, 1.0), bar_height, BAR_COLOR])
		y += band
	for t in [1, 10, 20, 30, 40]:
		if t > max_turn:
			break
		var x: float = chart_left + (t - 1) * (float(chart_width) / max_turn)
		parts.append('<text x="%.0f" y="%d" %s font-size="12" fill="%s">%d</text>' % [
			x, height - 16, FONT, INK, t])
	parts.append('</svg>')
	return "\n".join(parts)
