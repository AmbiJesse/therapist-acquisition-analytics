import csv
import random
import math
from datetime import date, timedelta

random.seed(42)

START_DATE = date(2024, 1, 1)
END_DATE   = date(2024, 12, 31)
N_THERAPISTS = 1000

CHANNELS = ["paid_search", "organic", "referral", "partner", "social"]

# Weights: how each channel distributes signups
CHANNEL_WEIGHTS = {
    "paid_search": 0.35,
    "organic":     0.28,
    "referral":    0.18,
    "partner":     0.12,
    "social":      0.07,
}

# Insurance acceptance rate varies meaningfully by channel (key insight)
INSURANCE_ACCEPTANCE_RATE = {
    "paid_search": 0.52,
    "organic":     0.64,
    "referral":    0.81,
    "partner":     0.73,
    "social":      0.44,
}

# 6-month retention rate by channel (the differentiated insight)
RETENTION_RATE_6M = {
    "paid_search": 0.51,
    "organic":     0.63,
    "referral":    0.79,
    "partner":     0.70,
    "social":      0.40,
}

STATES = [
    "CA","NY","TX","FL","IL","PA","OH","GA","NC","MI",
    "WA","MA","AZ","CO","TN","MN","OR","WI","MO","MD"
]

def rand_date(start, end):
    delta = (end - start).days
    return start + timedelta(days=random.randint(0, delta))

def weighted_channel():
    r = random.random()
    cum = 0
    for ch, w in CHANNEL_WEIGHTS.items():
        cum += w
        if r <= cum:
            return ch
    return "organic"

# ------------------------------------------------------------------
# 1. therapist_signups
# ------------------------------------------------------------------
therapists = []
for i in range(1, N_THERAPISTS + 1):
    channel = weighted_channel()
    signup_date = rand_date(START_DATE, END_DATE)
    accepts = random.random() < INSURANCE_ACCEPTANCE_RATE[channel]
    still_active = random.random() < RETENTION_RATE_6M[channel]
    therapists.append({
        "therapist_id": f"t_{i:04d}",
        "signup_date": signup_date.isoformat(),
        "referral_source": channel,
        "state": random.choice(STATES),
        "insurance_accepted": str(accepts).lower(),
        "active_6m": str(still_active).lower(),
    })

with open("/home/claude/therapist_signups.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=therapists[0].keys())
    w.writeheader(); w.writerows(therapists)

# ------------------------------------------------------------------
# 2. directory_sessions  (~20k rows)
# ------------------------------------------------------------------
sessions = []
sid = 1
for t in therapists:
    # Therapists get 10–35 directory sessions in the 60 days post-signup
    signup_dt = date.fromisoformat(t["signup_date"])
    n_sessions = random.randint(10, 35)
    for _ in range(n_sessions):
        session_date = signup_dt + timedelta(days=random.randint(0, 60))
        if session_date > END_DATE:
            session_date = END_DATE
        # Organic/referral therapists get more page views (higher intent visitors)
        base_pv = 3 if t["referral_source"] in ("organic","referral","partner") else 2
        sessions.append({
            "session_id":    f"s_{sid:06d}",
            "therapist_id":  t["therapist_id"],
            "session_date":  session_date.isoformat(),
            "channel":       t["referral_source"],
            "page_views":    random.randint(base_pv, base_pv + 4),
        })
        sid += 1

with open("/home/claude/directory_sessions.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=sessions[0].keys())
    w.writeheader(); w.writerows(sessions)

# ------------------------------------------------------------------
# 3. contact_requests  (~12–18% conversion on sessions)
# ------------------------------------------------------------------
CONTACT_RATE = {
    "paid_search": 0.12,
    "organic":     0.17,
    "referral":    0.21,
    "partner":     0.16,
    "social":      0.10,
}

contacts = []
rid = 1
for s in sessions:
    rate = CONTACT_RATE[s["channel"]]
    if random.random() < rate:
        req_date = date.fromisoformat(s["session_date"]) + timedelta(days=random.randint(0, 3))
        if req_date > END_DATE:
            req_date = END_DATE
        # ~65% of contact requests convert to booked session
        converted = random.random() < 0.65
        contacts.append({
            "request_id":   f"r_{rid:06d}",
            "therapist_id": s["therapist_id"],
            "session_id":   s["session_id"],
            "request_date": req_date.isoformat(),
            "converted":    str(converted).lower(),
        })
        rid += 1

with open("/home/claude/contact_requests.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=contacts[0].keys())
    w.writeheader(); w.writerows(contacts)

# ------------------------------------------------------------------
# 4. marketing_spend  (weekly, per channel)
# ------------------------------------------------------------------
spend_rows = []
sp_id = 1
WEEKLY_BUDGET = {
    "paid_search": 18000,
    "organic":      2500,   # SEO / content costs
    "referral":     4000,   # referral program
    "partner":      6000,
    "social":       5500,
}
CAMPAIGNS = {
    "paid_search": ["branded_kw","non_branded_kw","competitor_kw"],
    "organic":     ["seo_content","blog"],
    "referral":    ["therapist_referral","client_referral"],
    "partner":     ["insurance_partner","ehr_partner"],
    "social":      ["linkedin_awareness","instagram_retarget"],
}
current = START_DATE
while current <= END_DATE:
    for channel, base in WEEKLY_BUDGET.items():
        for campaign in CAMPAIGNS[channel]:
            # Add mild seasonality bump Q4
            seasonal = 1.15 if current.month >= 10 else 1.0
            noise = random.uniform(0.88, 1.12)
            spend = round(base / len(CAMPAIGNS[channel]) * seasonal * noise, 2)
            spend_rows.append({
                "spend_id":   f"sp_{sp_id:05d}",
                "channel":    channel,
                "spend_date": current.isoformat(),
                "spend_usd":  spend,
                "campaign":   campaign,
            })
            sp_id += 1
    current += timedelta(weeks=1)

with open("/home/claude/marketing_spend.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=spend_rows[0].keys())
    w.writeheader(); w.writerows(spend_rows)

# Quick sanity check
print(f"therapist_signups:  {len(therapists):,} rows")
print(f"directory_sessions: {len(sessions):,} rows")
print(f"contact_requests:   {len(contacts):,} rows")
print(f"marketing_spend:    {len(spend_rows):,} rows")

channel_counts = {}
for t in therapists:
    channel_counts[t["referral_source"]] = channel_counts.get(t["referral_source"], 0) + 1
print("\nSignups by channel:")
for ch, n in sorted(channel_counts.items(), key=lambda x: -x[1]):
    print(f"  {ch:<15} {n}")
