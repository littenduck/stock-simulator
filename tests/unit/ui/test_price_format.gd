extends TestCase


func test_price_groups_thousands() -> void:
	assert_eq(GameFmt.price(51.7), "51.70")
	assert_eq(GameFmt.price(999.995), "1,000.00")
	assert_eq(GameFmt.price(1453.0), "1,453.00")
	assert_eq(GameFmt.price(12345.678), "12,345.68")
	assert_eq(GameFmt.price(0.0), "0.00")
