#!/usr/bin/env bash
set -euo pipefail

days=${AGENDA_DAYS:-14}
[[ "$days" =~ ^[0-9]+$ ]] || days=14

hypr_dir=${XDG_CONFIG_HOME:-$HOME/.config}/hypr
dcal_cmd="$hypr_dir/scripts/dcal.sh"
from=$(date -d 'today 00:00:00' --iso-8601=seconds)
to=$(date -d "today +${days} days 23:59:59" --iso-8601=seconds)

if [[ -x "$dcal_cmd" ]] \
    && dank_json=$("$dcal_cmd" ipc events.list \
        "from=$from" "to=$to" limit=5 2>/dev/null) \
    && jq -e '.events | type == "array"' >/dev/null 2>&1 <<<"$dank_json"; then
    python3 -c '
import datetime as dt
import json
import re
import sys

weekdays = ("seg", "ter", "qua", "qui", "sex", "sáb", "dom")
today = dt.date.today()
payload = json.load(sys.stdin)
items = []

def clean(value, limit):
    value = re.sub(r"\s+", " ", value or "").strip()
    return value if len(value) <= limit else value[: limit - 1] + "…"

def parse_time(value, all_day=False):
    parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    # All-day dates are calendar dates, not instants.  A
    # timezone conversion could incorrectly move midnight to the previous day.
    return parsed if all_day else parsed.astimezone()

for event in sorted(payload.get("events", []), key=lambda item: item.get("start", "")):
    if event.get("status") == "cancelled":
        continue
    try:
        start = parse_time(event["start"], event.get("allDay", False))
        event_date = start.date()
        if event_date == today:
            day_label = "Hoje"
        elif event_date == today + dt.timedelta(days=1):
            day_label = "Amanhã"
        else:
            day_label = f"{weekdays[event_date.weekday()]} {event_date:%d/%m}"
        time_label = "dia todo" if event.get("allDay") else start.strftime("%H:%M")
    except (KeyError, TypeError, ValueError):
        day_label, time_label = "Em breve", ""

    items.append({
        "uid": event.get("uid", ""),
        "when": f"{day_label} · {time_label}".rstrip(" ·"),
        "summary": clean(event.get("summary"), 54) or "Compromisso sem título",
        "location": clean(event.get("location"), 48),
        "class": "event",
    })
    if len(items) == 5:
        break

if not items:
    items.append({
        "uid": "",
        "when": "Próximos 14 dias",
        "summary": "Nenhum compromisso sincronizado",
        "location": "Adicione Google ou Microsoft no DankCalendar",
        "class": "empty",
    })

json.dump(items, sys.stdout, ensure_ascii=False, separators=(",", ":"))
' <<<"$dank_json"
    exit 0
fi

calendar_csv=""
if command -v konsolekalendar >/dev/null 2>&1; then
    calendar_csv=$(LC_ALL=C konsolekalendar --show-next "$days" --export-type CSV 2>/dev/null || true)
fi

python3 -c '
import csv
import datetime as dt
import json
import re
import sys

weekdays = ("seg", "ter", "qua", "qui", "sex", "sáb", "dom")
today = dt.date.today()
items = []

def clean(value, limit):
    value = re.sub(r"\s+", " ", value or "").strip()
    return value if len(value) <= limit else value[: limit - 1] + "…"

for row in csv.reader(sys.stdin):
    if len(row) < 8:
        continue
    start_date, start_time, _end_date, _end_time, summary, location, _description, uid = row[:8]
    try:
        event_date = dt.datetime.strptime(start_date, "%A, %B %d, %Y").date()
        if event_date == today:
            day_label = "Hoje"
        elif event_date == today + dt.timedelta(days=1):
            day_label = "Amanhã"
        else:
            day_label = f"{weekdays[event_date.weekday()]} {event_date:%d/%m}"
    except ValueError:
        day_label = clean(start_date, 20)

    time_label = clean(start_time, 5) or "dia todo"
    items.append({
        "uid": uid,
        "when": f"{day_label} · {time_label}",
        "summary": clean(summary, 54) or "Compromisso sem título",
        "location": clean(location, 48),
        "class": "event",
    })
    if len(items) == 5:
        break

if not items:
    items.append({
        "uid": "",
        "when": "Próximos 14 dias",
        "summary": "Nenhum compromisso sincronizado",
        "location": "Abra a agenda para adicionar suas contas",
        "class": "empty",
    })

json.dump(items, sys.stdout, ensure_ascii=False, separators=(",", ":"))
' <<<"$calendar_csv"
