#!/usr/bin/env python3
"""Rebuilds assets/oui.csv ("AABBCC,Vendor") trying several mirrors in turn.
A prebuilt assets/oui.csv is already included, so this is only for refreshing."""
import csv, io, sys, urllib.request

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    return urllib.request.urlopen(req, timeout=60).read().decode("utf-8", "replace")

def from_ieee(t):
    rows = csv.reader(io.StringIO(t)); next(rows, None)
    return [(r[1].upper(), r[2]) for r in rows if len(r) >= 3 and len(r[1]) == 6]

def from_nmap(t):
    return [(l[:6].upper(), l[7:]) for l in t.splitlines()
            if len(l) > 7 and l[6] == " " and not l.startswith("#")]

SOURCES = [
    ("https://raw.githubusercontent.com/nmap/nmap/master/nmap-mac-prefixes", from_nmap),
    ("https://standards-oui.ieee.org/oui/oui.csv", from_ieee),
    ("http://standards-oui.ieee.org/oui/oui.csv", from_ieee),
]

for url, parse in SOURCES:
    try:
        rows = parse(get(url))
        if len(rows) > 10000:
            with open("assets/oui.csv", "w", encoding="utf-8") as f:
                f.write("# Source: " + url + "\n")
                for p, v in rows:
                    f.write(f"{p},{v.replace(',', ' ').strip()}\n")
            print(f"wrote {len(rows)} entries from {url}")
            sys.exit(0)
    except Exception as e:
        print(f"failed {url}: {e}")
sys.exit("all sources failed - check VPN/proxy/firewall")
