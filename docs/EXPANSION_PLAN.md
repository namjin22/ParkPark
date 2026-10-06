# ParkPark expansion plan (2026-10-06)

Working plan for the next content batch: a sixth zone, two new events, and a cosmetics shop. It follows the project rules in `AGENTS.md`: the server owns coins and purchases, cosmetics come before gameplay power, nothing is published or bought, and Robux items stay switched off until the user creates their products.

## 1. Goals

- Keep players coming back after the 37-attraction chain: something new to do every few minutes (events) and something to spend coins on besides the chain (cosmetics).
- Give the park a next destination beyond the space zone (pirate cove) so the progression has a visible end goal.
- Add optional purchases that never make the park faster for payers.

## 2. Proposed features and checks

### 2.1 Pirate cove zone (해적섬), the sixth zone

| Piece | Kind (reuses) | Notes |
|---|---|---|
| 해적 회전선 | `Spinner` (hub + 6 barrel pods) | thrill ride, fare 2300 |
| 보물섬 점프 | `Bounce` (sand mound, chest, flag) | fare 2500 |
| 유령선 투어 | `Hidden` tour (ghost galleon) | fare 2700 |
| 해적 주점 | `Shop` | fare 2400 |
| Decor | cannon, barrel stack, treasure chest, ship wheel | scenery only |
| Ambience | drifting sea-mist particles, dark-teal sand ground | like `SpaceService` |

- **Chain and gate:** Star cafe -> Galleon -> Booty -> Ghost -> Tavern. The gate opens once the star cafe is repaired.
- **Layout check:** the space zone's proven offsets are reused one zone further north (zone 263 studs long, branch rows 18 and 133 studs inside the boundary, ride rows 73 and 188 studs inside, same x offsets -60/150/-60/110 and radii 26/26/34/16). Those offsets passed the collision-checked layout search when the zone was built, so the same arithmetic holds; Play will confirm.
- **Economy check:** with the model (0.5 boardings per guest per minute, 36 guests, mean fare 560 over the 37 attractions, target wait 6 + 0.9 x n minutes) the four new steps come to about 405k / 414k / 423k / 432k coins of unlock plus repair, and the gate is 1.5 x the first step, about 600k. The measured income ran 1.4x to 3x above that model, so these steps will feel quicker than the 40-minute target, as the earlier zones did. Unlock : repair is kept at about 68 : 32 and income/staff arrays scale like the space zone's.
- **Risk:** needs seven new OBJ imports by the user (hub, pod, mound, ghost ship, tavern, cannon, chest) and the map grows to about 1,700 studs. Streaming is the existing behaviour; a phone performance check stays with the user.

### 2.2 New events (no models needed)

- **Coin rain (동전 비):** for 30 s gold coins fall around every player; touching one pays a small amount (1% of the summed fares of repaired attractions, at least 5). Social and quick; payout is bounded by a cap of 60 coins in the world at once.
- **Treasure chest (보물상자):** a chest with a highlight appears on the road of a random opened zone for 90 s; holding E on it pays 50% of the summed fares of repaired attractions to the first player who opens it. A notice names the zone. It gives a reason to use the travel menu.
- Both are picked by the existing event timer, so they never overlap with another event and follow the same readiness rule (park open, at least 5 rides running).
- **Check:** payouts scale with the fares of what the player has repaired, so they stay a small share of income at every stage (the sum of fares at nine rides is about 270, giving a 135-coin chest and 5-coin coins; at all 37 about 20,000, giving 10,000 and 200).

### 2.3 Cosmetics shop (the "꾸미기" closet)

- **What:** walk trails (4 colours; the last is a rainbow) and name titles (3). Coins buy them, which also gives a use for late-game coins.
- **Prices (coins):** trails 5,000 / 20,000 / 60,000 / 150,000; titles 3,000 / 15,000 / 50,000.
- **Where:** a round "꾸미기" button on the right edge under the travel button opens a list panel with buy / equip / unequip buttons. The server validates everything; ownership and the equipped items are saved per player in the profile.
- **Robux (optional, off by default):** `GameConfig.Monetization.PassId = 0` and each product id are placeholders. A game pass "후원자 패스" would unlock one exclusive title and the rainbow trail. While an id is 0 the item shows no Robux button and nothing can be bought, so no external setup is needed to ship this.
- **Not included on purpose:** coin packs, boosts, faster staff or any paid gameplay power. If the user wants a coin pack later it should be a separate decision.
- **Check:** pure cosmetics, no effect on fares or guests; saving reuses the profile fields the speed shop already uses.

## 3. Order of work and verification

1. Events: code, then Play with `ForceEvent` and forced attributes (coins awarded once per touch, chest pays only the first opener, world cap holds, cleaned up after the event).
2. Cosmetics: server service and saved fields, client panel, then Play (buy with too few coins is refused, buy, equip, trail and title appear, saved and restored through the memory-save backend).
3. Pirate cove: config, layout, generator OBJs, graybox Play (gate, queues, ambience), then the user imports the OBJs and the templates are built and checked.
4. Update `AGENTS.md`, commit and push after each step.

## 4. What stays with the user

- Importing the pirate OBJs through the 3D Importer.
- Creating a game pass and pasting its id, if they want Robux items.
- Phone and touch checks of the new panel and the chest prompt.

## 5. Batch 2 (2026-10-06): active income and the candy zone

Request: besides the rides, players should be able to earn coins by their own actions, and development of attractions continues.

### 5.1 Active income (no models needed)

Every payout is a number of seconds of the park's current income (`ActiveIncome`: the summed `IncomePerMinute` of repaired attractions, at least 5 coins), so it scales with progress and cannot outgrow the passive flow.

| System | How it works | Payout | Limits |
|---|---|---|---|
| Gathering (줍기) | 8 small pickups per open area (clover, shells, blocks, pine cones, snow crystals, star pieces, gold coins, candies) beside the paths; hold E 0.5 s | 6 s of income | respawn 90 s elsewhere; areas open with their zone |
| Fishing (낚시) | hold E 3 s at any beach pond in the water zone | weighted catch: 6 s (60%), 12 s (28%), 40 s (5%), old boot 0 (7%) | needs the zone open; 3 s cast |
| Delivery (배달) | take a parcel at the plaza desk, hold F at the target ride's console | 30 s of income x (1 + distance/600, max 4) | one parcel at a time, 20 s cooldown, 240 s timeout |

Check: an engaged player gathering about two items a minute, fishing now and then and running deliveries adds roughly 30-60% on top of the passive flow; an idle player loses nothing. All three constants live in `GameConfig.Active` for tuning.

### 5.2 Candy zone (사탕 구역), the seventh zone

Same offsets as the earlier zones one zone further north (boundary z = -1716, length 263), four attractions (a lollipop spinner, a gummy bounce, a candy-factory tour, a sweet shop), candy decor, sugar-dust ambience. Gate about 700k coins, steps about 460k to 490k by the balance rule. Needs seven OBJ imports from the user.

## 6. Batch 3 (2026-10-06): two more events and the jungle zone

### 6.1 Events (code only)

- **행운의 시간 (lucky hour):** for 60 s every active payout (gathering, fishing, delivery) is multiplied by 3 (`ActiveMultiplier` on the park folder, read by `ActiveIncome`). Check: only active play is boosted, passive income is untouched, so it rewards being present without inflating idle progress.
- **VIP 단체 방문:** for 60 s, 40% of arrivals are VIPs (`VipChance` attribute, read by `GuestService`); each leaves a tip of one minute of that ride's income. Check: tips scale with the ride's income and only arrive while VIPs board, so the most it adds is a few minutes of income per event.

### 6.2 Jungle zone (정글 구역), the eighth zone

Same offsets as the earlier zones, one zone further north (boundary z = -1979, length 263). Chain after the sweet shop: Coconut (`Spinner`, fare 3200, thrill) -> Mushroom (`Bounce`, 3400) -> Temple (`Hidden` tour, 3600, thrill) -> Juice bar (`Shop`, 3300). Steps about 500k to 530k to unlock and repair (the balance rule 6 + 0.9 x n minutes continued), gate 760k (1.5 x the first step). Jungle pollen, ferns, totems and bananas to gather. Needs seven OBJ imports from the user.
