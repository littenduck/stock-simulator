#!/usr/bin/env python3
"""Downloads daily OHLC from Yahoo for the roster and writes data/market/history.csv.
Columns: date, then <TICKER>_o,_h,_l,_c per ticker. Rows are the trading days of the first ticker (AAPL).
Late-listed tickers (SNDK, SPCX, LUNR...) have empty cells before their first row; HistoryData reads that as
"no data yet". Gaps after a ticker's first row are forward-filled with the previous close (flat bar).
Prices are scaled by SCALE (0.1), see below. Usage: python3 tools/fetch_history.py"""
import json, urllib.request, datetime, sys
# MODIFIED DATA: every price is multiplied by SCALE before it is written, so the CSV is a processed derivative of the
# Yahoo Finance prices, not the original values. Daily % moves are unchanged; absolute levels are 1/10 of the real ones.
SCALE = 0.1
TICKERS = ["NVDA","AMD","AVGO","MU","SNDK","MRVL","MSFT","AAPL","GOOGL","META","PLTR",
           "SPCX","RKLB","ASTS","LUNR",
           "AMZN","TSLA","RIVN","LCID","NFLX","RBLX","GME","AMC","COST","SBUX","KO","PEP",
           "COIN","HOOD","SOFI"]
# Yahoo shows the SPAC shell's prices before the merger; start the series at the real listing.
FIRST_DATE = {"LUNR": "2023-02-14"}
START = int(datetime.datetime(2022,1,3).timestamp())
TODAY = datetime.date.today().isoformat()
END = int(datetime.datetime.now().timestamp())
data = {}
for t in TICKERS:
    url = f"https://query1.finance.yahoo.com/v8/finance/chart/{t}?period1={START}&period2={END}&interval=1d"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    r = json.load(urllib.request.urlopen(req, timeout=30))["chart"]["result"][0]
    q = r["indicators"]["quote"][0]
    rows = {}
    for i, ts in enumerate(r["timestamp"]):
        vals = [q["open"][i], q["high"][i], q["low"][i], q["close"][i]]
        if None in vals: continue
        d = datetime.datetime.utcfromtimestamp(ts + r["meta"].get("gmtoffset", 0)).strftime("%Y-%m-%d")
        if d < FIRST_DATE.get(t, "0000") or d >= TODAY: continue   # skip today: the bar may be incomplete
        rows[d] = vals
    data[t] = rows
    print(t, len(rows), min(rows), file=sys.stderr)
dates = sorted(data["AAPL"])
with open("data/market/history.csv", "w") as f:
    f.write("date," + ",".join(f"{t}_{k}" for t in TICKERS for k in "ohlc") + "\n")
    last = {}
    for d in dates:
        cells = []
        for t in TICKERS:
            if d in data[t]:
                last[t] = data[t][d]; cells += [f"{x*SCALE:.3f}" for x in last[t]]
            elif t in last:   # gap after listing: flat bar at the previous close
                c = last[t][3]; cells += [f"{c*SCALE:.3f}"] * 4
            else:
                cells += [""] * 4
        f.write(d + "," + ",".join(cells) + "\n")
print(len(dates), "days", dates[0], dates[-1], file=sys.stderr)
