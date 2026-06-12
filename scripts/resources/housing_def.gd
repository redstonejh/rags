class_name HousingDef
extends Resource
## A rung on the wealth curve, T0 shelter cot to T5 mansion. The deliberate
## poverty trap lives here: the motel costs MORE per week than the
## apartment — but the apartment wants a deposit and ID. Being poor is
## expensive; that's the tutorial lesson of the whole economy.

@export var id: String = ""
@export var display_name: String = ""
@export_range(0, 5) var tier: int = 0
@export var weekly_rent_cents: int = 0
@export var deposit_cents: int = 0
## 0 = not for sale. Buying pays the down payment; the weekly number
## becomes a mortgage (the bank is just a landlord with better stationery).
@export var buy_price_cents: int = 0
@export var down_payment_cents: int = 0
@export var min_credit_to_buy: int = 0
@export var requires_id: bool = false
## Landlords judge at the door: minimum outfit status tier to sign.
@export var min_outfit_tier: int = 0
## Weeks of steady employment OR weeks of clean rent history required.
@export var min_weeks_employed: int = 0
@export var min_clean_rent_weeks: int = 0
## Sleep quality multiplier (the bed inherits it) and daily Mood comfort.
@export var quality: float = 1.0
@export var comfort: float = 0.0
@export_multiline var blurb: String = ""
