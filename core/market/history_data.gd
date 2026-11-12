## Real daily OHLC history (data/market/history.csv), parsed once and shared.
## CSV layout: header `date,<KEY>_o,<KEY>_h,<KEY>_l,<KEY>_c,...`, one row per trading day, all tickers aligned.
## Uses FileAccess on res:// so it works in exported web builds (the .csv is exported via include_filter).
class_name HistoryData
extends RefCounted

const DEFAULT_PATH := "res://data/market/history.csv"

static var _default: HistoryData = null
static var _tried_default: bool = false

var dates: PackedStringArray = PackedStringArray()
## key -> PackedFloat64Array with 4 values per row (o, h, l, c), row-major.
var _bars: Dictionary = {}


## Shared instance of the bundled history; null when the file is missing or unreadable.
static func default() -> HistoryData:
	if not _tried_default:
		_tried_default = true
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> HistoryData:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var h := HistoryData.new()
	h._parse(f)
	return h if h.row_count() > 0 else null


## Parses CSV text (same layout as the file). Used by tests with tiny synthetic data.
static func from_text(text: String) -> HistoryData:
	var path := "user://_history_tmp.csv"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return null
	f.store_string(text)
	f.close()
	var h := from_file(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return h


func row_count() -> int:
	return dates.size()


func has_key(key: String) -> bool:
	return _bars.has(key)


## ISO date (YYYY-MM-DD) of a row; "" when out of range.
func date_at(row: int) -> String:
	if row < 0 or row >= dates.size():
		return ""
	return dates[row]


## [open, high, low, close] of a row. high/low are widened so low <= open,close <= high always holds.
func bar(key: String, row: int) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	if not _bars.has(key) or row < 0 or row >= dates.size():
		return out
	var b: PackedFloat64Array = _bars[key]
	var i := row * 4
	out.append_array([b[i], b[i + 1], b[i + 2], b[i + 3]])
	return out


func close_at(key: String, row: int) -> float:
	if not _bars.has(key) or row < 0 or row >= dates.size():
		return 0.0
	return (_bars[key] as PackedFloat64Array)[row * 4 + 3]


func _parse(f: FileAccess) -> void:
	var header := f.get_csv_line()
	var keys: Array[String] = []
	var col_of: Dictionary = {}   ## key -> first column index of its _o
	for i in range(1, header.size()):
		var name := header[i]
		if name.ends_with("_o"):
			var k := name.trim_suffix("_o")
			keys.append(k)
			col_of[k] = i
	var lines: Array[PackedStringArray] = []
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() < 2 or line[0] == "":
			continue
		dates.append(line[0])
		lines.append(line)
	var n := lines.size()
	for k in keys:
		var c: int = col_of[k]
		var arr := PackedFloat64Array()
		arr.resize(n * 4)
		var ok := true
		for r in n:
			var line := lines[r]
			if c + 3 >= line.size():
				ok = false
				break
			var o := line[c].to_float()
			var cl := line[c + 3].to_float()
			arr[r * 4] = o
			arr[r * 4 + 1] = maxf(line[c + 1].to_float(), maxf(o, cl))
			arr[r * 4 + 2] = minf(line[c + 2].to_float(), minf(o, cl))
			arr[r * 4 + 3] = cl
		if ok:
			_bars[k] = arr
