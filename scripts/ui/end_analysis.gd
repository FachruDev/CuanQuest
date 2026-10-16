class_name EndAnalysis
extends RefCounted
## Analisis sederhana berbasis aturan untuk layar akhir (GDD 5.11: "kenapa kamu rugi").
## Setiap aturan membaca statistik yang dikumpulkan GameState selama permainan.


## `state`: GameState (dioper sebagai parameter agar mudah dites).
static func insights(state: Node) -> Array[String]:
	var s: Dictionary = state.stats
	var months: int = maxi(state.month, 1)
	var out: Array[String] = []

	match state.end_result.get("reason", ""):
		"bankrupt":
			out.append(_t("INSIGHT_BANKRUPT"))
		"health":
			out.append(_t("INSIGHT_HEALTH"))
		"happiness":
			out.append(_t("INSIGHT_HAPPINESS"))

	if s["scam_loss"] > 0:
		out.append(_t("INSIGHT_SCAM") % Fmt.rupiah(s["scam_loss"]))
	if s["panic_sell"]:
		out.append(_t("INSIGHT_PANIC"))
	if s["unaffordable_choices"] >= 2 or s["forced_sales"] > 0:
		out.append(_t("INSIGHT_EMERGENCY") % int(s["unaffordable_choices"] + s["forced_sales"]))
	if months > 12 and s["cash_heavy_months"] > months * 0.5:
		out.append(_t("INSIGHT_CASH_IDLE"))
	if months > 12 and s["luxury_months"] > months * 0.5:
		out.append(_t("INSIGHT_LIFESTYLE"))
	if s["total_fees"] > 1_000_000 and s["total_fees"] > s["total_interest"]:
		out.append(_t("INSIGHT_FEES") % Fmt.rupiah(s["total_fees"]))
	var concentration := largest_holding_share(state)
	if concentration > 0.7 and state.portfolio.investments_value() > 10_000_000:
		out.append(_t("INSIGHT_CONCENTRATION") % Fmt.percent_plain(concentration))

	if float(s.get("insurance_claims", 0)) > 0.0:
		out.append(_t("INSIGHT_INSURANCE") % [Fmt.rupiah(s["insurance_claims"]), Fmt.rupiah(s["insurance_premiums"])])
	elif float(s.get("uninsured_medical", 0)) >= 5_000_000:
		out.append(_t("INSIGHT_UNINSURED") % Fmt.rupiah(s["uninsured_medical"]))

	# Karier & pendidikan (v1.5b)
	if int(s.get("layoffs", 0)) > 0:
		out.append(_t("INSIGHT_LAYOFF") % [int(s["layoffs"]), Fmt.rupiah(s["severance"])])
	if int(s.get("months_unemployed", 0)) >= 6:
		out.append(_t("INSIGHT_UNEMPLOYED") % int(s["months_unemployed"]))
	if int(s.get("promotions", 0)) >= 2:
		out.append(_t("INSIGHT_CAREER_GROWTH") % [int(s["promotions"]), int(s["top_level"])])
	elif months >= 60 and int(s.get("top_level", 0)) <= 1:
		out.append(_t("INSIGHT_CAREER_STUCK") % floori(months / 12.0))
	if int(s.get("graduations", 0)) > 0:
		out.append(_t("INSIGHT_EDUCATION") % [int(s["graduations"]), Fmt.rupiah(s["tuition"])])

	# Leverage (v2a): likuidasi, kerugian di atas margin, biaya inap, atau untung yang disiplin.
	var lev: Dictionary = state.leverage.record
	if int(lev["liquidated"]) > 0:
		out.append(_t("INSIGHT_LEV_LIQUIDATED") % [int(lev["liquidated"]), Fmt.signed_rupiah(lev["pnl"])])
		if float(lev["shortfall"]) > 0.0:
			out.append(_t("INSIGHT_LEV_SHORTFALL") % Fmt.rupiah(lev["shortfall"]))
	elif int(lev["opened"]) >= 3 and float(lev["pnl"]) > 0.0:
		out.append(_t("INSIGHT_LEV_PROFIT") % [int(lev["opened"]), Fmt.rupiah(lev["pnl"])])
	if float(lev["financing"]) >= 1_000_000.0:
		out.append(_t("INSIGHT_LEV_FINANCING") % Fmt.rupiah(lev["financing"]))

	# Utang, kendaraan & properti (v1.5c)
	if int(s.get("loan_defaults", 0)) > 0:
		out.append(_t("INSIGHT_LOAN_DEFAULT") % int(s["loan_defaults"]))
	elif int(s.get("missed_payments", 0)) > 0:
		out.append(_t("INSIGHT_LOAN_LATE") % [int(s["missed_payments"]), Fmt.rupiah(s["debt_fees"])])
	if int(s.get("restructures", 0)) > 0:
		out.append(_t("INSIGHT_RESTRUCTURE") % int(s["restructures"]))
	if int(s.get("offer_loans", 0)) > 0:
		out.append(_t("INSIGHT_OFFER_LOANS") % int(s["offer_loans"]))
	if int(s.get("refinances", 0)) > 0:
		out.append(_t("INSIGHT_REFINANCE") % int(s["refinances"]))
	if int(s.get("vehicles_seized", 0)) > 0:
		out.append(_t("INSIGHT_VEHICLE_SEIZED") % int(s["vehicles_seized"]))
	elif int(s.get("vehicle_costs", 0)) >= 20_000_000:
		out.append(_t("INSIGHT_VEHICLE_COST") % Fmt.rupiah(s["vehicle_costs"]))
	if int(s.get("properties_seized", 0)) > 0:
		out.append(_t("INSIGHT_PROPERTY_SEIZED") % int(s["properties_seized"]))
	if int(s.get("rent_income", 0)) >= 10_000_000:
		out.append(_t("INSIGHT_RENT") % Fmt.rupiah(s["rent_income"]))
	if not state.properties.home().is_empty():
		out.append(_t("INSIGHT_OWN_HOME") % _t(state.properties.def(state.properties.home()["id"])["name"]))
	if float(s.get("debt_interest", 0.0)) >= 1_000_000:
		out.append(_t("INSIGHT_DEBT_INTEREST") % [Fmt.rupiah(s["debt_interest"]), Fmt.rupiah(s["borrowed_total"])])

	if state.is_financially_free():
		out.append(_t("INSIGHT_GOOD_FREEDOM"))
	if s["total_interest"] > 1_000_000:
		out.append(_t("INSIGHT_GOOD_INTEREST") % Fmt.rupiah(s["total_interest"]))
	if out.is_empty():
		out.append(_t("INSIGHT_DEFAULT"))
	return out


## Porsi aset terbesar dari total investasi (0..1).
static func largest_holding_share(state: Node) -> float:
	var total: float = state.portfolio.investments_value()
	if total <= 0:
		return 0.0
	var largest := 0.0
	for asset_id: String in state.portfolio.holdings:
		largest = maxf(largest, state.portfolio.holding_value(asset_id))
	return largest / total


static func _t(key: String) -> String:
	return TranslationServer.translate(key)
