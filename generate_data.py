"""Generate a synthetic hotel offer dataset (10,000 rows) for a supply analytics case study.
All data is invented. Patterns are planted so the analysis has something to find.
Run: python generate_data.py  ->  creates offers.csv and offers.db (SQLite)
"""
import random
import sqlite3
import csv

random.seed(42)
N = 10_000

# Vio's own benchmark: the lowest price Vio shows for a room across all partners is the "best price".
# Each offer is one supplier's price for one room night, with that supplier's commission.

suppliers = {
    # name: (type, price_index vs market, commission, reliability (confirm rate), weight)
    "OTA Alpha":        ("OTA",         1.00, 0.15, 0.97, 0.20),
    "OTA Beta":         ("OTA",         1.02, 0.14, 0.96, 0.14),
    "Wholesaler Gamma": ("Wholesaler",  0.95, 0.09, 0.92, 0.14),
    "Wholesaler Delta": ("Wholesaler",  0.97, 0.10, 0.90, 0.10),
    "BedBank Epsilon":  ("Bed bank",    0.93, 0.07, 0.88, 0.12),
    "Chain Direct Zeta":("Hotel chain", 0.99, 0.12, 0.99, 0.10),
    "Connect Eta":      ("Connectivity",0.96, 0.08, 0.94, 0.12),
    "Regional Theta":   ("Wholesaler",  0.94, 0.11, 0.93, 0.08),
}

destinations = {
    # name: (region, base ADR EUR, demand weight, supplier coverage multipliers override)
    "Barcelona":  ("Southern Europe", 160, 1.4),
    "Lisbon":     ("Southern Europe", 135, 1.1),
    "Paris":      ("Western Europe",  210, 1.6),
    "Amsterdam":  ("Western Europe",  200, 1.3),
    "Berlin":     ("Central Europe",  120, 1.0),
    "Prague":     ("Central Europe",  100, 0.9),
    "Athens":     ("Southern Europe", 110, 0.9),
    "Reykjavik":  ("Nordics",         230, 0.6),
    "Split":      ("Balkans",          95, 0.5),
    "Tbilisi":    ("Caucasus",         70, 0.3),
}

segments = {
    # segment: (price multiplier, share)
    "Budget (1-2 star)": (0.55, 0.20),
    "Midscale (3 star)": (1.00, 0.35),
    "Upscale (4 star)":  (1.55, 0.30),
    "Luxury (5 star)":   (2.80, 0.15),
}

rate_types = {
    # rate type: (price multiplier, share)
    "Non refundable": (0.90, 0.35),
    "Free cancellation": (1.00, 0.50),
    "Package/opaque": (0.85, 0.15),
}

# Planted coverage gaps: some supplier x destination combos barely exist.
coverage_penalty = {
    ("Tbilisi", "OTA Beta"): 0.1,
    ("Tbilisi", "Chain Direct Zeta"): 0.05,
    ("Split", "Chain Direct Zeta"): 0.15,
    ("Split", "OTA Beta"): 0.3,
    ("Reykjavik", "BedBank Epsilon"): 0.2,
    ("Reykjavik", "Wholesaler Delta"): 0.2,
}
# Luxury is thin at bed banks and wholesalers.
luxury_penalty = {"BedBank Epsilon": 0.3, "Wholesaler Gamma": 0.4, "Wholesaler Delta": 0.4}

# Planted price issue: Regional Theta is cheap in Balkans/Caucasus; OTA Alpha is expensive in Southern Europe.
def price_adjust(supplier, dest, seg):
    adj = 1.0
    if supplier == "Regional Theta" and destinations[dest][0] in ("Balkans", "Caucasus"):
        adj *= 0.88
    if supplier == "OTA Alpha" and destinations[dest][0] == "Southern Europe":
        adj *= 1.06
    if supplier == "BedBank Epsilon" and seg.startswith("Luxury"):
        adj *= 0.90
    return adj

def pick(weights_dict):
    keys = list(weights_dict)
    return random.choices(keys, weights=[weights_dict[k] for k in keys])[0]

rows = []
used = set()
offer_id = 0
sup_names = list(suppliers)
while len(rows) < N:
    dest = pick({d: v[2] for d, v in destinations.items()})
    seg = pick({s: v[1] for s, v in segments.items()})
    sup = pick({s: v[4] for s, v in suppliers.items()})
    keep = coverage_penalty.get((dest, sup), 1.0)
    if seg.startswith("Luxury"):
        keep *= luxury_penalty.get(sup, 1.0)
    if random.random() > keep:
        continue
    rate = pick({r: v[1] for r, v in rate_types.items()})
    stype, pidx, comm, rel, _ = suppliers[sup]
    region, adr, _ = destinations[dest]
    # Each (dest, seg) has a set of ~40 hotels; offers cluster per hotel and stay date
    hotel_idx = random.randint(1, 6)
    hotel_id = f"{dest[:3].upper()}-{seg[:3].upper()}-{hotel_idx:02d}"
    stay_week = random.randint(1, 3)
    key = (hotel_id, stay_week, rate, sup)
    if key in used:
        continue
    used.add(key)
    market_price = adr * segments[seg][0] * rate_types[rate][0] * random.uniform(0.92, 1.08)
    price = market_price * pidx * price_adjust(sup, dest, seg) * random.uniform(0.97, 1.03)
    price = round(price, 2)
    # Conversion rate depends on price rank (computed later) and a base by segment/destination
    offer_id += 1
    rows.append({
        "offer_id": offer_id, "supplier": sup, "supplier_type": stype,
        "destination": dest, "region": region, "segment": seg, "rate_type": rate,
        "hotel_id": hotel_id, "stay_week": stay_week,
        "price_eur": price, "commission_rate": comm,
        "confirm_rate": rel,
    })

# Compute price rank within comparable room group (hotel, stay week, rate type) to simulate Vio's shown price.
from collections import defaultdict
groups = defaultdict(list)
for r in rows:
    groups[(r["hotel_id"], r["stay_week"], r["rate_type"])].append(r)

for g in groups.values():
    g.sort(key=lambda r: r["price_eur"])
    best = g[0]["price_eur"]
    for i, r in enumerate(g):
        r["price_rank"] = i + 1
        r["group_size"] = len(g)
        r["group_best_price"] = best

# Impressions and clicks / bookings: winners in the group get most traffic.
for r in rows:
    rank = r["price_rank"]
    share = {1: 0.55, 2: 0.25, 3: 0.12}.get(rank, 0.08 / max(1, r["group_size"] - 3))
    base_imp = 60 * destinations[r["destination"]][2]
    imp = max(1, int(random.gauss(base_imp * share * 4, 6)))
    ctr = random.uniform(0.05, 0.09)
    clicks = max(0, int(imp * ctr))
    # booking conversion falls if price gap to best is large; reliability matters via confirm_rate
    gap = r["price_eur"] / r["group_best_price"] - 1
    cvr = max(0.0, 0.14 - 0.6 * gap) * random.uniform(0.85, 1.15)
    bookings = sum(1 for _ in range(clicks) if random.random() < cvr)
    confirmed = sum(1 for _ in range(bookings) if random.random() < r["confirm_rate"])
    r["impressions"] = imp
    r["clicks"] = clicks
    r["bookings"] = bookings
    r["confirmed_bookings"] = confirmed
    r["nights"] = random.choice([1, 2, 2, 3, 3, 4, 5])
    r["gross_booking_value_eur"] = round(confirmed * r["price_eur"] * r["nights"], 2)
    r["commission_eur"] = round(r["gross_booking_value_eur"] * r["commission_rate"], 2)

fields = list(rows[0].keys())
with open("offers.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=fields)
    w.writeheader()
    w.writerows(rows)

con = sqlite3.connect("offers.db")
con.execute("DROP TABLE IF EXISTS offers")
types = {"offer_id": "INTEGER", "price_eur": "REAL", "commission_rate": "REAL", "confirm_rate": "REAL",
         "stay_week": "INTEGER", "price_rank": "INTEGER", "group_size": "INTEGER", "group_best_price": "REAL",
         "impressions": "INTEGER", "clicks": "INTEGER", "bookings": "INTEGER", "confirmed_bookings": "INTEGER",
         "nights": "INTEGER", "gross_booking_value_eur": "REAL", "commission_eur": "REAL"}
con.execute("CREATE TABLE offers (" + ", ".join(f"{c} {types.get(c, 'TEXT')}" for c in fields) + ")")
con.executemany(f"INSERT INTO offers VALUES ({','.join('?'*len(fields))})",
                [tuple(r[c] for c in fields) for r in rows])
con.commit()
print(f"{len(rows)} offers written")
