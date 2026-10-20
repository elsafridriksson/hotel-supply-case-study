# Supply partner case study: what the data says and what I would do

Synthetic data. 10,000 hotel offers, 8 partners, 10 destinations, 4 hotel segments. All figures come from `analysis.sql` (outputs in `results/`). The patterns were built into the data, so this shows the method, not facts about any real marketplace.

## 1. Price competitiveness

The two OTAs pay the highest commission but rarely win on price.

| Partner | Commission | Cheapest on | Avg gap to best price |
|---|---|---|---|
| Bed bank Epsilon | 7% | 42.3% of rooms | 3.7% |
| Regional Theta | 11% | 35.3% | 4.5% |
| Wholesaler Gamma | 9% | 24.9% | 6.1% |
| OTA Alpha | 15% | 3.4% | 13.9% |
| OTA Beta | 14% | 2.7% | 13.6% |

The widest gap is OTA Alpha in Southern Europe, 18.1% above the best price.

## 2. Why the gap matters

Conversion falls fast as a partner moves away from the best price: 12.7 confirmed bookings per 100 clicks within 2% of the best price, 10.0 at 5% to 10%, 5.5 at 10% to 20%, and none above 20%.

The OTAs also earn the most per booking (about 93 to 98 euros against 38 to 46 for Epsilon, Gamma, Delta and Connect Eta), so their pricing is worth fixing rather than replacing.

## 3. Scenario for a negotiation

If OTA Alpha halved its price gap in Southern Europe, modelled commission rises from 1,252 to 1,926 euros in the sample (+673, about 54%). The model nets out the lower price per booking and holds clicks constant. The base case matches actual commission (1,252 modelled against 1,250 actual).

## 4. Coverage gaps

- Tbilisi: Chain Direct Zeta covers 2.3% of rooms, OTA Beta 3.5%.
- Split: Chain Direct Zeta covers 9.0%.
- Reykjavik: Wholesaler Delta covers 11.8%, Bed bank Epsilon 15.3%.
- Luxury: 3.4 partners per room on average, and 55% of luxury rooms have three or fewer, against 17% for midscale.

## 5. Where to grow first

Ranked by missing room groups times the partner's commission per group. Only partners within 7% of the best price on average, and only where they cover under half of rooms. Euro figures rank the options, they are not a forecast.

| Partner | Destination | Coverage now | Indicative opportunity |
|---|---|---|---|
| Regional Theta | Split | 34.8% | 4,291 |
| Regional Theta | Reykjavik | 38.4% | 4,094 |
| Regional Theta | Tbilisi | 27.7% | 4,094 |
| Bed bank Epsilon | Reykjavik | 15.3% | 3,761 |

## Recommendations

1. Take the OTA price gap to the partnerships managers as a negotiation item, with the conversion curve as the evidence.
2. Ask Regional Theta and Bed bank Epsilon to extend coverage into Split, Reykjavik and Tbilisi.
3. Look for new sources of luxury rates, since depth there is thinnest.
4. Watch Bed bank Epsilon's confirmation rate (86.1%, the lowest of the eight). Its price advantage is worth less if bookings fail.

## Limits

- Synthetic data with planted patterns, three stay weeks, one price per partner per room.
- Conversion by price gap is observational. A real version would check it with an experiment.
- No cancellation, promotion or seasonality effects.
