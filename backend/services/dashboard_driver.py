import os
import json
from datetime import date, datetime, timedelta
from groq import Groq
from dotenv import load_dotenv
from db import get_connection
from services.arch_service import _get_device_and_table

load_dotenv()

_groq_client = Groq(api_key=os.getenv("GROQ_API_KEY"))
GROQ_MODEL   = os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile")

SCORE_PENALTIES = {
    1:  ("securite",  -15), 2:  ("securite",  -12), 3:  ("securite",  -10),
    10: ("securite",   -8), 12: ("fatigue",   -10), 14: ("securite",  -12),
    29: ("fatigue",    -8), 30: ("securite",  -10), 50: ("securite",  -15),
    4:  ("vitesse",   -10), 5:  ("vitesse",   -12), 6:  ("vitesse",   -15),
    7:  ("vitesse",    -8), 8:  ("freinage",  -10), 9:  ("freinage",  -12),
    11: ("vigilance", -10), 13: ("vigilance", -12), 15: ("vigilance",  -8),
}

FATIGUE_CODES     = {12, 29}
SEATBELT_CODES    = {14}
SMOKE_CODES       = {10}
TELEPHONE_CODES   = {9}
DISTRACTION_CODES = {11, 14}

# ── Cache insight ─────────────────────────────────────────────────────────────
_insight_cache: dict = {}


def _get_cached_insight(cin: str, **kwargs) -> dict:
    cached = _insight_cache.get(cin)
    if cached and (datetime.now() - cached["generated_at"]).seconds < 3600:
        return cached["insight"]
    # ← appelle _generate_groq_insight, pas lui-même
    insight = _generate_groq_insight(**kwargs)
    _insight_cache[cin] = {"insight": insight, "generated_at": datetime.now()}
    return insight


def get_dashboard_data(cin: str) -> dict:
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        today = date.today()

        # ── Driver + véhicule ──────────────────────────────────────────────
        cursor.execute("""
            SELECT d.first_name, d.last_name, d.vehicule_id,
                   v.mark, v.model, v.matricule
            FROM compte_driver d
            LEFT JOIN vehicule v ON v.matricule = d.vehicule_id
            WHERE d.cin = %s LIMIT 1
        """, (cin,))
        drv = cursor.fetchone()
        if not drv:
            return {"error": "driver_not_found"}

        driver_name  = f"{drv['first_name']} {drv['last_name']}"
        vehicule_id  = drv.get("vehicule_id")
        vehicle_name = f"{drv['mark']} {drv['model']}" if drv.get("mark") else "Véhicule"

        # ── Ignition ───────────────────────────────────────────────────────
        ignition = 0
        if vehicule_id:
            try:
                result = _get_device_and_table(cin)
                if result and len(result) == 2:
                    device_id, arch_table = result
                    if arch_table and device_id:
                        cursor.execute(f"""
                            SELECT ignition FROM {arch_table}
                            WHERE id_device = %s
                              AND ignition IS NOT NULL
                            ORDER BY date DESC LIMIT 1
                        """, (device_id,))
                        row_ign = cursor.fetchone()
                        if row_ign:
                            ignition = int(row_ign["ignition"] or 0)
            except Exception as e:
                print(f">>> [DASHBOARD] Erreur ignition: {e}")

        # ── Events du jour ─────────────────────────────────────────────────
        cursor.execute("""
            SELECT added_info AS code, COUNT(*) AS cnt
            FROM events
            WHERE driver_id = %s
              AND subtype = 11
              AND DATE(date) = %s
              AND added_info IS NOT NULL AND added_info != 0
            GROUP BY added_info
        """, (cin, today))
        today_events = cursor.fetchall()
        print(f">>> [DASHBOARD] {len(today_events)} types d'events aujourd'hui pour {cin}")

        # ── Calcul score ───────────────────────────────────────────────────
        categories = {
            "vitesse": 100, "freinage": 100, "vigilance": 100,
            "fatigue": 100, "securite": 100
        }
        fatigue_count     = 0
        telephone_count   = 0
        distraction_count = 0
        seatbelt_issue    = False
        smoke_issue       = False
        event_summary     = {}

        for row in today_events:
            code = int(row["code"])
            cnt  = int(row["cnt"])
            event_summary[code] = cnt

            if code in SCORE_PENALTIES:
                cat, penalty = SCORE_PENALTIES[code]
                categories[cat] = max(0, categories[cat] + penalty * cnt)

            if code in FATIGUE_CODES:
                fatigue_count += cnt
            if code in SEATBELT_CODES:
                seatbelt_issue = True
            if code in SMOKE_CODES:
                smoke_issue = True
            if code in TELEPHONE_CODES:
                telephone_count += cnt
            if code in DISTRACTION_CODES:
                distraction_count += cnt

        print(f">>> [DASHBOARD] categories={categories}")
        print(f">>> [DASHBOARD] fatigue={fatigue_count} tel={telephone_count} dist={distraction_count}")

        score_today       = round(sum(categories.values()) / len(categories))
        vigilance_score   = categories.get("vigilance", 100)
        telephone_score   = max(0, 100 - telephone_count   * 20)
        distraction_score = max(0, 100 - distraction_count * 15)

        # ── Score d'hier ───────────────────────────────────────────────────
        cursor.execute("""
            SELECT score_today FROM daily_reports
            WHERE driver_id = %s AND report_date = %s
            LIMIT 1
        """, (cin, today - timedelta(days=1)))
        row_y           = cursor.fetchone()
        score_yesterday = row_y["score_today"] if row_y else None
        score_delta     = (score_today - score_yesterday) if score_yesterday is not None else None

        # ── Fatigue % ──────────────────────────────────────────────────────
        fatigue_pct = min(round((fatigue_count / 5) * 100), 100)

        cursor.execute("""
            SELECT DATE(date) AS day, COUNT(*) AS cnt
            FROM events
            WHERE driver_id = %s
              AND subtype = 11
              AND added_info IN (12, 29)
              AND date >= %s
            GROUP BY DATE(date)
        """, (cin, today - timedelta(days=7)))
        f_rows          = cursor.fetchall()
        avg_fat_cnt     = (sum(r["cnt"] for r in f_rows) / 7) if f_rows else 0
        avg_fatigue_pct = min(round((avg_fat_cnt / 5) * 100), 100)

        # ── Historique score 7j ────────────────────────────────────────────
        cursor.execute("""
            SELECT report_date, score_today
            FROM daily_reports
            WHERE driver_id = %s AND report_date >= %s
            ORDER BY report_date DESC
        """, (cin, today - timedelta(days=7)))
        score_history = [
            {"date": str(r["report_date"]), "score": r["score_today"]}
            for r in cursor.fetchall()
        ]

        # ── Insight Groq (avec cache) ──────────────────────────────────────
        insight = _get_cached_insight(
            cin,
            driver_name    = driver_name,
            score_today    = score_today,
            score_delta    = score_delta,
            categories     = categories,
            fatigue_pct    = fatigue_pct,
            seatbelt_issue = seatbelt_issue,
            smoke_issue    = smoke_issue,
            event_summary  = event_summary,
            score_history  = score_history,
        )

        if score_today >= 85:
            score_label = "Excellent · Top 10% des conducteurs"
        elif score_today >= 70:
            score_label = "Bonne conduite, quelques axes à améliorer"
        elif score_today >= 50:
            score_label = "Conduite correcte, restez vigilant"
        else:
            score_label = "Journée difficile, consultez votre rapport"

        return {
            "driver_name":      driver_name,
            "vehicle_name":     vehicle_name,
            "ignition":         ignition,
            "score_today":      score_today,
            "score_yesterday":  score_yesterday,
            "score_delta":      score_delta,
            "score_label":      score_label,
            "categories":       categories,
            "fatigue_pct":      fatigue_pct,
            "avg_fatigue_pct":  avg_fatigue_pct,
            "fatigue_count":    fatigue_count,
            "seatbelt_ok":      not seatbelt_issue,
            "smoke_ok":         not smoke_issue,
            "events_count":     sum(event_summary.values()),
            "insight":          insight,
            "score_history":    score_history,
            "vigilance_pct":    vigilance_score,
            "telephone_pct":    telephone_score,
            "distraction_pct":  distraction_score,
        }

    except Exception as e:
        import traceback
        traceback.print_exc()
        raise e
    finally:
        conn.close()


# ── Groq insight ───────────────────────────────────────────────────────────────
def _generate_groq_insight(driver_name, score_today, score_delta, categories,
                            fatigue_pct, seatbelt_issue, smoke_issue,
                            event_summary, score_history) -> dict:
    try:
        delta_str = ""
        if score_delta is not None:
            arrow     = "↑" if score_delta >= 0 else "↓"
            delta_str = f"{arrow}{abs(score_delta)} pts vs hier"

        history_str = ""
        if score_history:
            history_str = "Historique 7j: " + ", ".join(
                f"{r['date']}: {r['score']}" for r in score_history[:5]
            )

        events_str = ""
        if event_summary:
            events_str = "Événements (code: occurrences): " + ", ".join(
                f"{k}: {v}" for k, v in sorted(event_summary.items())
            )

        worst_cat = min(categories, key=categories.get)
        worst_val = categories[worst_cat]

        prompt = f"""Tu es un assistant de coaching conducteur. Analyse ce bilan et génère un insight court.

Conducteur: {driver_name}
Score du jour: {score_today}/100 {delta_str}
Catégories: vitesse={categories['vitesse']}, freinage={categories['freinage']}, vigilance={categories['vigilance']}, fatigue={categories['fatigue']}, securite={categories['securite']}
Pire catégorie: {worst_cat} ({worst_val}/100)
Fatigue: {fatigue_pct}%
Ceinture non bouclée: {"oui" if seatbelt_issue else "non"}
Tabac détecté: {"oui" if smoke_issue else "non"}
{events_str}
{history_str}

Réponds UNIQUEMENT en JSON valide, sans markdown, sans texte avant ou après:
{{
  "titre": "phrase courte percutante (max 8 mots)",
  "message": "analyse en 1-2 phrases, ton positif ou encourageant selon le score",
  "conseil": "1 conseil actionnable concret pour aujourd'hui",
  "priorite": "faible|normale|haute"
}}"""

        response = _groq_client.chat.completions.create(
            model=GROQ_MODEL,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=250,
            temperature=0.4,
        )

        raw = response.choices[0].message.content.strip()
        if raw.startswith("```"):
            raw = raw.split("```")[1]
            if raw.startswith("json"):
                raw = raw[4:]
        raw = raw.strip()

        parsed = json.loads(raw)
        return {
            "titre":    parsed.get("titre",    "Bilan du jour"),
            "message":  parsed.get("message",  ""),
            "conseil":  parsed.get("conseil",  ""),
            "priorite": parsed.get("priorite", "normale"),
        }

    except Exception as e:
        print(f"[DASHBOARD] Groq insight error: {e}")
        return _fallback_insight(score_today, seatbelt_issue, smoke_issue)


def _fallback_insight(score, seatbelt_issue, smoke_issue) -> dict:
    if seatbelt_issue:
        return {
            "titre":    "Ceinture non bouclée détectée",
            "message":  "Vous avez conduit sans ceinture aujourd'hui.",
            "conseil":  "Bouclez votre ceinture dès la mise en route.",
            "priorite": "haute",
        }
    if smoke_issue:
        return {
            "titre":    "Tabac détecté dans le véhicule",
            "message":  "De la fumée a été détectée dans l'habitacle.",
            "conseil":  "Évitez de fumer au volant pour la sécurité de tous.",
            "priorite": "haute",
        }
    if score >= 85:
        return {
            "titre":    "Excellente journée de conduite",
            "message":  "Votre score est parmi les meilleurs aujourd'hui.",
            "conseil":  "Maintenez cette régularité pour améliorer votre moyenne.",
            "priorite": "faible",
        }
    if score >= 70:
        return {
            "titre":    "Bonne conduite globale",
            "message":  "Votre journée se passe bien, continuez ainsi.",
            "conseil":  "Surveillez les petits excès de vitesse pour booster votre score.",
            "priorite": "normale",
        }
    return {
        "titre":    "Des axes à améliorer aujourd'hui",
        "message":  "Votre score est en dessous de votre moyenne habituelle.",
        "conseil":  "Faites une pause si vous ressentez de la fatigue.",
        "priorite": "normale",
    }


# ── Weekly stats ──────────────────────────────────────────────────────────────
def get_weekly_stats(cin: str) -> dict:
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        today    = date.today()
        week_ago = today - timedelta(days=7)

        cursor.execute("""
            SELECT DATE(date) as day, added_info AS code, COUNT(*) AS cnt
            FROM events
            WHERE driver_id = %s
              AND subtype = 11
              AND date >= %s
              AND added_info IS NOT NULL AND added_info != 0
            GROUP BY DATE(date), added_info
        """, (cin, week_ago))
        events = cursor.fetchall()

        categories_per_day = {}
        for i in range(7):
            day_str = (week_ago + timedelta(days=i + 1)).strftime("%Y-%m-%d")
            categories_per_day[day_str] = {
                "vitesse": 100, "freinage": 100, "vigilance": 100,
                "fatigue": 100, "securite": 100
            }

        for event in events:
            day_str = str(event["day"])
            code    = int(event["code"])
            cnt     = int(event["cnt"])
            if code in SCORE_PENALTIES and day_str in categories_per_day:
                cat, penalty = SCORE_PENALTIES[code]
                categories_per_day[day_str][cat] = max(
                    0, categories_per_day[day_str][cat] + penalty * cnt
                )

        daily_scores = {
            day: round(sum(cats.values()) / len(cats))
            for day, cats in categories_per_day.items()
        }
        avg_score = round(sum(daily_scores.values()) / len(daily_scores))

        category_scores = {"vitesse": 0, "freinage": 0, "vigilance": 0,
                           "fatigue": 0, "securite": 0}
        for cats in categories_per_day.values():
            for k in category_scores:
                category_scores[k] += cats[k]
        category_scores = {k: round(v / 7) for k, v in category_scores.items()}

        cursor.execute("""
            SELECT DATE(date) as day, COUNT(*) as cnt
            FROM events
            WHERE driver_id = %s AND subtype = 11
              AND added_info IN (12, 29) AND date >= %s
            GROUP BY DATE(date)
        """, (cin, week_ago))
        fatigue_by_day     = {str(r["day"]): r["cnt"] for r in cursor.fetchall()}
        fatigue_week_total = sum(fatigue_by_day.values())
        fatigue_week_pct   = min(round((fatigue_week_total / (5 * 7)) * 100), 100)

        cursor.execute("""
            SELECT DATE(date) as day FROM events
            WHERE driver_id = %s AND subtype = 11
              AND added_info = 14 AND date >= %s
            GROUP BY DATE(date)
        """, (cin, week_ago))
        seatbelt_days = [str(r["day"]) for r in cursor.fetchall()]

        cursor.execute("""
            SELECT DATE(date) as day FROM events
            WHERE driver_id = %s AND subtype = 11
              AND added_info = 10 AND date >= %s
            GROUP BY DATE(date)
        """, (cin, week_ago))
        smoke_days = [str(r["day"]) for r in cursor.fetchall()]

        if avg_score >= 85:   score_label = "Excellent"
        elif avg_score >= 70: score_label = "Très bien"
        elif avg_score >= 50: score_label = "Correct"
        else:                 score_label = "À améliorer"

        today_str = str(today)
        return {
            "weekly_scores":       daily_scores,
            "category_scores":     category_scores,
            "avg_score":           avg_score,
            "score_label":         score_label,
            "fatigue_week_pct":    fatigue_week_pct,
            "seatbelt_ok":         today_str not in seatbelt_days,
            "smoke_ok":            today_str not in smoke_days,
            "seatbelt_days_count": len(seatbelt_days),
            "smoke_days_count":    len(smoke_days),
            "best_day":            max(daily_scores, key=daily_scores.get),
            "worst_day":           min(daily_scores, key=daily_scores.get),
        }

    except Exception as e:
        import traceback
        traceback.print_exc()
        return {"error": str(e)}
    finally:
        conn.close()