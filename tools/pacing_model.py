"""Rough pacing model of the unlock chain.

Prints, for every attraction in `GameConfig.RideChain`, how many minutes of baseline income (all earlier rides
repaired, staff 0, income level 0, no park-wide multipliers) its unlock + repair costs, and the same for the zone
gate paid before a zone's first attraction. Run it after changing ride costs or fares in GameConfig.luau.
"""
import re
from pathlib import Path

CONFIG = Path(__file__).resolve().parent.parent / "src" / "shared" / "Config" / "GameConfig.luau"


def load():
    s = CONFIG.read_text(encoding="utf-8")
    i = s.index("\tRideChain = {")
    j = s.index("}", i)
    chain = re.findall(r'"([A-Za-z]+)"', s[i:j])
    rides = {}
    for m in re.finditer(r"\n\t\t(\w+) = \{\n\t\t\tDisplayName = [^\n]*\n(.*?)\n\t\t\},", s, re.S):
        key, body = m.group(1), m.group(2)
        if "UnlockCost" not in body:
            continue

        def number(name):
            found = re.search(name + r" = (\d+),", body)
            return int(found.group(1)) if found else None

        zone = re.search(r'Zone = "(\w+)"', body)
        rides[key] = dict(
            unlock=number("UnlockCost"),
            repair=number("RepairCost"),
            fare=number("BaseFare"),
            zone=zone.group(1) if zone else None,
        )
    zones = re.findall(r'"(\w+)"', re.search(r"ZoneOrder = \{([^}]*)\}", s).group(1))
    start = s.index("ZoneCosts = {")
    end = s.index("}", start)
    gates = {k: int(v) for k, v in re.findall(r"(\w+) = (\d+),", s[start:end])}
    return chain, rides, zones, gates


def flow(rides, n, key):
    guests = min(10 + 2 * n, 36)
    return rides[key]["fare"] * 1.5 * 0.5 * guests / n


def main():
    chain, rides, zones, gates = load()
    first = {}
    for zone in zones:
        for key in chain:
            if rides[key]["zone"] == zone:
                first[key] = zone
                break
    total = 0.0
    income = 0.0
    for n, key in enumerate(chain, 1):
        cost = rides[key]["unlock"] + rides[key]["repair"]
        gate = gates.get(first.get(key, ""), 0)
        if income > 0:
            step = cost / income
            gate_minutes = gate / income if gate else 0.0
            total += step + gate_minutes
            print(f"{n:2d} {key:12s} cost={cost:9d} gate={gate:9d} flow={income:9.0f}/min step={step:5.1f}m gate={gate_minutes:5.1f}m")
        else:
            print(f"{n:2d} {key:12s} cost={cost:9d} (first)")
        income += flow(rides, n, key)
    print(f"total {total:.0f} minutes = {total / 60:.1f} hours at baseline income")


if __name__ == "__main__":
    main()
