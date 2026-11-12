#!/usr/bin/env python3
"""Downloads daily OHLC from Yahoo for the roster and writes data/market/history.csv.
Columns: date, then <TICKER>_o,_h,_l,_c per ticker. Only dates present for every ticker are kept.
Usage: python3 tools/fetch_history.py"""
import json, urllib.request, datetime, sys
TICKERS = ["NVDA","AMD","MSFT","AAPL","GOOGL","META","PLTR","RKLB","AMZN","TSLA","NFLX","COST",
           "SBUX","PEP","JPM","V","COIN","LLY","PFE","MRNA","ISRG","XOM","CVX","ENPH"]
START = int(datetime.datetime(2022,1,3).timestamp())
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
        rows[d] = vals
    data[t] = rows
    print(t, len(rows), file=sys.stderr)
dates = sorted(set.intersection(*[set(v) for v in data.values()]))
with open("data/market/history.csv", "w") as f:
    f.write("date," + ",".join(f"{t}_{k}" for t in TICKERS for k in "ohlc") + "\n")
    for d in dates:
        f.write(d + "," + ",".join(f"{x:.2f}" for t in TICKERS for x in data[t][d]) + "\n")
print(len(dates), "days", dates[0], dates[-1], file=sys.stderr)
