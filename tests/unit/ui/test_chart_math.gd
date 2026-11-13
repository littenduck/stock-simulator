extends TestCase


func _candles() -> Dictionary:
	return {
		"open": PackedFloat32Array([10, 11, 12]),
		"high": PackedFloat32Array([12, 14, 13]),
		"low": PackedFloat32Array([9, 10, 8]),
		"close": PackedFloat32Array([11, 12, 9]),
	}


func test_range_of_uses_wicks() -> void:
	var r: Vector2 = ChartMath.range_of(_candles(), 0, 2)
	assert_eq(r, Vector2(8, 14))
	assert_eq(ChartMath.range_of(_candles(), 0, 1), Vector2(9, 14))
	assert_eq(ChartMath.range_of({}, 0, 3), Vector2(0, 1), "empty falls back to 0..1")


func test_range_of_falls_back_to_closes() -> void:
	var r: Vector2 = ChartMath.range_of({"close": PackedFloat32Array([5, 7, 6])}, 0, 2)
	assert_eq(r, Vector2(5, 7))


func test_padded_widens_and_never_collapses() -> void:
	var p: Vector2 = ChartMath.padded(100, 110)
	assert_true(p.x < 100 and p.y > 110)
	var flat: Vector2 = ChartMath.padded(50, 50)
	assert_true(flat.y > flat.x, "flat range still has height")


func test_y_and_x_mapping() -> void:
	assert_almost(ChartMath.y_of(10, 0, 10, 100, 200), 100.0, 0.001, "top")
	assert_almost(ChartMath.y_of(0, 0, 10, 100, 200), 300.0, 0.001, "bottom")
	assert_almost(ChartMath.x_of(0, 4, 0, 100), 12.5, 0.001)
	assert_almost(ChartMath.x_of(3, 4, 0, 100), 87.5, 0.001)


func test_index_at_roundtrip_and_clamp() -> void:
	for i in 10:
		assert_eq(ChartMath.index_at(ChartMath.x_of(i, 10, 20, 300), 10, 20, 300), i)
	assert_eq(ChartMath.index_at(-50, 10, 20, 300), 0)
	assert_eq(ChartMath.index_at(9999, 10, 20, 300), 9)
	assert_eq(ChartMath.index_at(10, 0, 20, 300), -1)


func test_body_width_is_bounded() -> void:
	assert_true(ChartMath.body_width(500, 400) >= 1.0)
	assert_true(ChartMath.body_width(2, 600) <= 18.0)


func test_nice_ticks_cover_range_with_round_steps() -> void:
	var t: PackedFloat64Array = ChartMath.nice_ticks(30.05, 54.74, 5)
	assert_true(t.size() >= 3 and t.size() <= 8, "tick count %d" % t.size())
	for v in t:
		assert_true(v >= 30.05 and v <= 54.74 + 0.01, "inside range")
	var big: PackedFloat64Array = ChartMath.nice_ticks(850.0, 1163.0, 5)
	assert_true(big.size() >= 3)
	assert_almost(fmod(big[0], 50.0), 0.0, 0.001, "round to 50 for four-digit prices")


func test_dates() -> void:
	assert_eq(ChartMath.short_date("2024-03-04"), "Mar 4")
	assert_eq(ChartMath.long_date("2024-03-04"), "Mar 4, 2024")
	assert_eq(ChartMath.short_date(""), "")
	assert_eq(ChartMath.short_date("2024-13-01"), "")


func test_label_indices() -> void:
	var idx: PackedInt32Array = ChartMath.label_indices(91, 5)
	assert_eq(idx.size(), 5)
	assert_eq(idx[0], 0)
	assert_eq(idx[4], 90)
	assert_eq(ChartMath.label_indices(3, 5).size(), 3, "never more labels than bars")
	assert_eq(ChartMath.label_indices(0, 5).size(), 0)


func test_grown_candle_interpolates() -> void:
	var start: PackedFloat32Array = ChartMath.grown(10, 14, 8, 12, 0.0)
	assert_eq(start, PackedFloat32Array([10, 10, 10, 10]))
	var end: PackedFloat32Array = ChartMath.grown(10, 14, 8, 12, 1.0)
	assert_eq(end, PackedFloat32Array([10, 14, 8, 12]))
	var mid: PackedFloat32Array = ChartMath.grown(10, 14, 8, 12, 0.5)
	assert_true(mid[2] <= mid[0] and mid[2] <= mid[3] and mid[1] >= mid[0] and mid[1] >= mid[3], "low <= open,close <= high")
