import json
import os
import sqlite3
import uuid
from datetime import datetime, timedelta
from pathlib import Path

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, Header, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

load_dotenv(Path(__file__).parent / ".env")

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

DB_PATH = Path(__file__).parent / "reminders.db"
TZ_FORMAT = "%m/%d/%Y %H:%M"
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

VALID_CATEGORIES = {"homework", "applications", "gym", "personal", "work"}
VALID_PRIORITIES = {"high", "medium", "low"}


def get_db():
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def init_db():
    conn = get_db()
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS reminders (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT DEFAULT '',
            category TEXT DEFAULT 'personal',
            priority TEXT DEFAULT 'medium',
            event_time TEXT NOT NULL,
            sent INTEGER DEFAULT 0,
            created_at TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_reminders_user ON reminders(user_id);

        CREATE TABLE IF NOT EXISTS reminder_times (
            id TEXT PRIMARY KEY,
            reminder_id TEXT NOT NULL,
            reminder_time TEXT NOT NULL,
            offset_minutes INTEGER NOT NULL,
            sent INTEGER DEFAULT 0,
            FOREIGN KEY (reminder_id) REFERENCES reminders(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_rt_reminder ON reminder_times(reminder_id);
        CREATE INDEX IF NOT EXISTS idx_rt_time ON reminder_times(reminder_time);
    """)
    conn.close()


init_db()


def get_reminder_times(conn, reminder_id):
    rows = conn.execute(
        "SELECT * FROM reminder_times WHERE reminder_id = ? ORDER BY offset_minutes DESC",
        (reminder_id,),
    ).fetchall()
    return [
        {
            "id": r["id"],
            "reminderId": r["reminder_id"],
            "reminderTime": r["reminder_time"],
            "offsetMinutes": r["offset_minutes"],
        }
        for r in rows
    ]


def row_to_dict(row, conn=None):
    rt = None
    if conn:
        rt = get_reminder_times(conn, row["id"]) or None
    return {
        "id": row["id"],
        "calendarEventId": None,
        "title": row["title"],
        "description": row["description"],
        "category": row["category"],
        "priority": row["priority"],
        "eventTime": row["event_time"],
        "sent": bool(row["sent"]),
        "createdAt": row["created_at"],
        "reminderTimes": rt,
    }


def insert_reminder_times(conn, reminder_id, event_time_str, reminder_times_list):
    """Insert reminder_times rows. Each item has offsetMinutes."""
    try:
        event_dt = datetime.strptime(event_time_str, TZ_FORMAT)
    except ValueError:
        return

    now = datetime.now()
    for rt in reminder_times_list:
        offset = rt.get("offsetMinutes", 0)
        alert_dt = event_dt - timedelta(minutes=offset)
        if alert_dt <= now:
            continue
        conn.execute(
            "INSERT INTO reminder_times (id, reminder_id, reminder_time, offset_minutes, sent) VALUES (?, ?, ?, ?, 0)",
            (str(uuid.uuid4()), reminder_id, alert_dt.strftime(TZ_FORMAT), offset),
        )


# --- LIST ---
@app.get("/webhook/api/reminders")
def list_reminders(
    x_user_id: str = Header(...),
    category: str | None = Query(None),
    priority: str | None = Query(None),
    date: str | None = Query(None),
    upcoming: str | None = Query(None),
    completed: str | None = Query(None),
):
    conn = get_db()
    sql = "SELECT * FROM reminders WHERE user_id = ?"
    params: list = [x_user_id]

    if category:
        sql += " AND category = ?"
        params.append(category)
    if priority:
        sql += " AND priority = ?"
        params.append(priority)
    if completed == "true":
        sql += " AND sent = 1"
    elif completed == "false":
        sql += " AND sent = 0"

    sql += " ORDER BY event_time ASC"
    rows = conn.execute(sql, params).fetchall()
    reminders = [row_to_dict(r, conn) for r in rows]
    conn.close()

    return {"success": True, "count": len(reminders), "reminders": reminders, "error": None}


# --- DUE ALERTS (separate path to avoid {reminder_id} conflict) ---
@app.get("/webhook/api/due-alerts")
def get_due_alerts(x_user_id: str = Header(...)):
    now = datetime.now().strftime(TZ_FORMAT)
    conn = get_db()
    rows = conn.execute(
        """
        SELECT rt.id as alert_id, rt.reminder_time, rt.offset_minutes,
               r.id as reminder_id, r.title, r.description, r.category, r.priority
        FROM reminder_times rt
        JOIN reminders r ON rt.reminder_id = r.id
        WHERE r.user_id = ? AND rt.sent = 0 AND r.sent = 0 AND rt.reminder_time <= ?
        ORDER BY rt.reminder_time ASC
        """,
        (x_user_id, now),
    ).fetchall()
    conn.close()

    alerts = [
        {
            "id": r["alert_id"],
            "reminderId": r["reminder_id"],
            "title": r["title"],
            "description": r["description"],
            "category": r["category"],
            "priority": r["priority"],
            "reminderTime": r["reminder_time"],
            "offsetMinutes": r["offset_minutes"],
        }
        for r in rows
    ]
    return {"success": True, "alerts": alerts, "error": None}


# --- GET ONE ---
@app.get("/webhook/api/reminders/{reminder_id}")
def get_reminder(reminder_id: str, x_user_id: str = Header(...)):
    conn = get_db()
    row = conn.execute(
        "SELECT * FROM reminders WHERE id = ? AND user_id = ?",
        (reminder_id, x_user_id),
    ).fetchone()

    if not row:
        conn.close()
        return JSONResponse({"success": False, "reminder": None, "error": "Reminder not found"}, status_code=404)

    result = row_to_dict(row, conn)
    conn.close()
    return {"success": True, "reminder": result, "error": None}


# --- CREATE ---
@app.post("/webhook/api/reminders")
async def create_reminder(request: Request, x_user_id: str = Header(...)):
    body = await request.json()

    reminder_id = str(uuid.uuid4())
    now = datetime.now().strftime(TZ_FORMAT)

    title = body.get("title", "")
    description = body.get("description", "")
    category = body.get("category", "personal")
    priority = body.get("priority", "medium")
    event_time = body.get("eventTime", now)
    reminder_times = body.get("reminderTimes", [])

    if category not in VALID_CATEGORIES:
        category = "personal"
    if priority not in VALID_PRIORITIES:
        priority = "medium"

    conn = get_db()
    conn.execute(
        "INSERT INTO reminders (id, user_id, title, description, category, priority, event_time, sent, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?)",
        (reminder_id, x_user_id, title, description, category, priority, event_time, now),
    )

    if reminder_times:
        insert_reminder_times(conn, reminder_id, event_time, reminder_times)

    conn.commit()
    conn.close()

    return {"success": True, "message": "Reminder created", "id": reminder_id, "error": None}


# --- UPDATE ---
@app.put("/webhook/api/reminders/{reminder_id}")
async def update_reminder(reminder_id: str, request: Request, x_user_id: str = Header(...)):
    body = await request.json()

    fields = []
    params = []
    for key, col in [("title", "title"), ("description", "description"), ("category", "category"), ("priority", "priority"), ("eventTime", "event_time")]:
        if key in body:
            fields.append(f"{col} = ?")
            params.append(body[key])

    if "sent" in body:
        fields.append("sent = ?")
        params.append(1 if body["sent"] else 0)

    reminder_times = body.get("reminderTimes", None)

    conn = get_db()

    if fields:
        params.extend([reminder_id, x_user_id])
        conn.execute(f"UPDATE reminders SET {', '.join(fields)} WHERE id = ? AND user_id = ?", params)

    # Replace reminder times if provided
    if reminder_times is not None:
        conn.execute("DELETE FROM reminder_times WHERE reminder_id = ?", (reminder_id,))
        event_time = body.get("eventTime")
        if not event_time:
            row = conn.execute("SELECT event_time FROM reminders WHERE id = ?", (reminder_id,)).fetchone()
            event_time = row["event_time"] if row else None
        if event_time:
            for rt in reminder_times:
                # Use provided reminderTime or compute from offset
                if "reminderTime" in rt and rt["reminderTime"]:
                    alert_time_str = rt["reminderTime"]
                else:
                    try:
                        event_dt = datetime.strptime(event_time, TZ_FORMAT)
                        alert_dt = event_dt - timedelta(minutes=rt.get("offsetMinutes", 60))
                        alert_time_str = alert_dt.strftime(TZ_FORMAT)
                    except ValueError:
                        continue
                conn.execute(
                    "INSERT INTO reminder_times (id, reminder_id, reminder_time, offset_minutes, sent) VALUES (?, ?, ?, ?, 0)",
                    (str(uuid.uuid4()), reminder_id, alert_time_str, rt.get("offsetMinutes", 0)),
                )

    conn.commit()
    conn.close()

    return {"success": True, "message": "Reminder updated", "error": None}


# --- DELETE ---
@app.delete("/webhook/api/reminders/{reminder_id}")
def delete_reminder(reminder_id: str, x_user_id: str = Header(...)):
    conn = get_db()
    conn.execute("DELETE FROM reminders WHERE id = ? AND user_id = ?", (reminder_id, x_user_id))
    conn.commit()
    conn.close()
    return {"success": True, "message": "Reminder deleted", "error": None}


# --- MARK COMPLETE ---
@app.post("/webhook/api/reminders/{reminder_id}/complete")
def mark_complete(reminder_id: str, x_user_id: str = Header(...)):
    conn = get_db()
    conn.execute("UPDATE reminders SET sent = 1 WHERE id = ? AND user_id = ?", (reminder_id, x_user_id))
    conn.commit()
    conn.close()
    return {"success": True, "message": "Reminder marked complete", "error": None}


# --- AI PARSE ---
@app.post("/webhook/api/reminders/parse")
async def parse_reminder(request: Request, x_user_id: str = Header(...)):
    body = await request.json()
    text = body.get("text", "").strip()

    if not text:
        return JSONResponse({"success": False, "parsed": None, "error": "No text provided"}, status_code=400)

    if not GEMINI_API_KEY:
        return JSONResponse({"success": False, "parsed": None, "error": "Gemini API key not configured"}, status_code=500)

    now = datetime.now()
    now_str = now.strftime(TZ_FORMAT)
    day_name = now.strftime("%A")

    prompt = f"""You are a reminder parsing assistant. Parse the user's natural language into a structured reminder.

Current date/time: {now_str}
Day of week: {day_name}

Available categories: homework, applications, gym, personal, work
Available priorities: high, medium, low

Return a JSON object with these fields:
- title: string (concise reminder title; strip filler like "remind me to", "don't forget to")
- description: string (any extra context, or empty string)
- category: string (best match from available categories)
- priority: "low" | "medium" | "high" (infer from urgency cues: "important"/"urgent"/"ASAP" = high, "whenever"/"no rush" = low, otherwise medium)
- event_time: string (in MM/dd/yyyy HH:mm format, resolved relative to current date/time)
- reminder_offsets: array of integers (minutes before event_time to send alert notifications)

Rules for event_time:
- "tomorrow" = next calendar day
- "next Monday" = the upcoming Monday
- "by Friday" = this Friday (or next Friday if today is after Friday)
- If no time specified, default to 09:00
- If no date specified, default to tomorrow

Rules for reminder_offsets:
- If the user specifies when to be reminded ("remind me the night before and an hour before"), honor that exactly
- "night before" = 720 minutes (12 hours before)
- Otherwise, use smart defaults:
  - Event more than 1 day away: [1440, 60, 15] (1 day, 1 hour, 15 min before)
  - Event same day but >2 hours away: [120, 30, 10] (2 hours, 30 min, 10 min before)
  - Event <2 hours away: [30, 10] (30 min, 10 min before)
- For high priority, add an extra close-to-event alert
- Never include an offset that would result in a time before {now_str}

Return ONLY valid JSON, no markdown fences."""

    try:
        resp = None
        for attempt in range(2):
            try:
                async with httpx.AsyncClient(timeout=20.0) as client:
                    resp = await client.post(
                        f"{GEMINI_URL}?key={GEMINI_API_KEY}",
                        json={
                            "contents": [
                                {"role": "user", "parts": [{"text": prompt + "\n\nUser said: " + text}]}
                            ],
                            "generationConfig": {
                                "temperature": 0.1,
                                "responseMimeType": "application/json",
                            },
                        },
                    )
                if resp.status_code == 200:
                    break
            except Exception:
                if attempt == 1:
                    raise

        if not resp or resp.status_code != 200:
            raise Exception(f"Gemini API returned {resp.status_code if resp else 'no response'}: {resp.text[:200] if resp else ''}")

        gemini_data = resp.json()
        candidates = gemini_data.get("candidates", [])
        if not candidates:
            raise Exception("Gemini returned no candidates")
        raw_text = candidates[0].get("content", {}).get("parts", [{}])[0].get("text", "{}")
        parsed = json.loads(raw_text)

        # Validate and normalize
        title = parsed.get("title", text)
        description = parsed.get("description", "")
        category = parsed.get("category", "personal")
        priority = parsed.get("priority", "medium")
        event_time = parsed.get("event_time", "")
        offsets = parsed.get("reminder_offsets", [60, 15])

        if category not in VALID_CATEGORIES:
            category = "personal"
        if priority not in VALID_PRIORITIES:
            priority = "medium"

        # Validate event_time format
        try:
            datetime.strptime(event_time, TZ_FORMAT)
        except ValueError:
            tomorrow = now + timedelta(days=1)
            event_time = tomorrow.replace(hour=9, minute=0).strftime(TZ_FORMAT)

        # Filter offsets that would be in the past
        event_dt = datetime.strptime(event_time, TZ_FORMAT)
        valid_offsets = []
        for o in offsets:
            if isinstance(o, (int, float)) and o >= 0:
                alert_time = event_dt - timedelta(minutes=int(o))
                if alert_time > now:
                    valid_offsets.append(int(o))

        if not valid_offsets:
            valid_offsets = [15, 5]
            valid_offsets = [o for o in valid_offsets if event_dt - timedelta(minutes=o) > now]

        # Build human-readable labels
        def offset_label(mins):
            if mins >= 1440:
                d = mins // 1440
                return f"{d} day{'s' if d > 1 else ''} before"
            elif mins >= 60:
                h = mins // 60
                return f"{h} hour{'s' if h > 1 else ''} before"
            else:
                return f"{mins} min before"

        reminder_times = [{"offsetMinutes": o, "label": offset_label(o)} for o in sorted(valid_offsets, reverse=True)]

        return {
            "success": True,
            "parsed": {
                "title": title,
                "description": description,
                "category": category,
                "priority": priority,
                "eventTime": event_time,
                "reminderTimes": reminder_times,
            },
            "error": None,
        }

    except Exception as e:
        # Fallback: use raw text as title, defaults for everything else
        tomorrow = (now + timedelta(days=1)).replace(hour=9, minute=0).strftime(TZ_FORMAT)
        return {
            "success": True,
            "parsed": {
                "title": text,
                "description": "",
                "category": "personal",
                "priority": "medium",
                "eventTime": tomorrow,
                "reminderTimes": [
                    {"offsetMinutes": 1440, "label": "1 day before"},
                    {"offsetMinutes": 60, "label": "1 hour before"},
                    {"offsetMinutes": 15, "label": "15 min before"},
                ],
            },
            "error": f"AI parsing failed, using defaults: {str(e)}",
        }



# --- MARK ALERT SENT ---
@app.post("/webhook/api/reminder-times/{alert_id}/mark-sent")
def mark_alert_sent(alert_id: str, x_user_id: str = Header(...)):
    conn = get_db()
    conn.execute("UPDATE reminder_times SET sent = 1 WHERE id = ?", (alert_id,))
    conn.commit()
    conn.close()
    return {"success": True, "message": "Alert marked sent", "error": None}


# Serve PWA static files (must be last — catch-all)
pwa_dir = Path(__file__).parent.parent / "pwa"
if pwa_dir.exists():
    app.mount("/", StaticFiles(directory=str(pwa_dir), html=True), name="static")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
