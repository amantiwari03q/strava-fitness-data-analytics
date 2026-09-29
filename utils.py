"""
Shared helpers for the Bellabeat / Fitbit Streamlit app.
Every page imports load_clean_data() so cleaning logic lives in one place
and stays identical across Home, SQL Explorer, EDA Dashboard and Insights.
"""
import sqlite3
from pathlib import Path

import numpy as np
import pandas as pd
import streamlit as st

APP_DIR = Path(__file__).parent
DATA_PATH = APP_DIR / "data" / "fitbit_merged_daily.csv"
SQL_PATH = APP_DIR / "sql" / "00_combined.sql"

WEEKDAY_ORDER = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

PRIMARY = "#6C5CE7"
TEAL = "#00B894"
PINK = "#FD79A8"
AMBER = "#FDCB6E"
GREY = "#B2BEC3"
BLUE = "#0984E3"
PALETTE = [PRIMARY, TEAL, PINK, AMBER, BLUE, GREY]


@st.cache_data(show_spinner="Loading and cleaning data...")
def load_clean_data() -> pd.DataFrame:
    """Load the merged daily CSV and add the same derived columns used in the SQL view and notebook."""
    df = pd.read_csv(DATA_PATH, parse_dates=["Date"])

    ids = sorted(df["Id"].unique())
    label = {i: f"U{n:02d}" for n, i in enumerate(ids, 1)}
    df["User"] = df["Id"].map(label)

    df["IsWorn"] = ~((df["TotalSteps"] == 0) | (df["SedentaryMinutes"] == 1440))

    df["Weekday"] = pd.Categorical(df["Date"].dt.day_name(), categories=WEEKDAY_ORDER, ordered=True)
    df["WeekdayNo"] = df["Date"].dt.weekday
    df["DayType"] = np.where(df["Weekday"].isin(["Saturday", "Sunday"]), "Weekend", "Weekday")
    df["Week"] = df["Date"].dt.isocalendar().week.astype(int)

    df["ActiveMinutes"] = df[["VeryActiveMinutes", "FairlyActiveMinutes", "LightlyActiveMinutes"]].sum(axis=1)
    df["SedentaryHours"] = df["SedentaryMinutes"] / 60
    df["SleepHours"] = df["TotalMinutesAsleep"] / 60
    df["SleepEfficiency"] = np.where(
        df["TotalTimeInBed"] > 0, 100 * df["TotalMinutesAsleep"] / df["TotalTimeInBed"], np.nan
    )
    df["Met10k"] = (df["TotalSteps"] >= 10000).astype(int)
    df["StepCategory"] = pd.cut(
        df["TotalSteps"],
        [-1, 5000, 7500, 10000, 12500, np.inf],
        labels=[
            "1. Sedentary (<5k)",
            "2. Low active (5-7.5k)",
            "3. Somewhat active (7.5-10k)",
            "4. Active (10-12.5k)",
            "5. Highly active (12.5k+)",
        ],
    )
    return df


@st.cache_data(show_spinner=False)
def worn_only(df: pd.DataFrame) -> pd.DataFrame:
    """Rows where the tracker was actually worn - the basis for almost every analysis."""
    return df[df["IsWorn"]].copy()


@st.cache_resource(show_spinner="Building in-memory SQL database...")
def get_sql_connection():
    """SQLite connection with fitbit_daily loaded and fitbit_clean view created, ready for SQL Explorer."""
    df = load_clean_data()
    # fitbit_daily = the RAW merged file, exactly as 01_cleaning.sql expects it
    raw = pd.read_csv(DATA_PATH)
    con = sqlite3.connect(":memory:", check_same_thread=False)
    raw.to_sql("fitbit_daily", con, index=False)

    sql_text = SQL_PATH.read_text()
    part_a = sql_text.split("-- ================= PART B : ANALYSIS ==========================")[0]
    con.executescript(part_a)
    return con


def parse_named_queries() -> dict:
    """Read 00_combined.sql and return {name: (title, sql)} for every '-- name:' block in Part B."""
    import re

    text = SQL_PATH.read_text()
    part_b = text.split("-- ================= PART B : ANALYSIS ==========================")[1]
    blocks = re.split(r"\n-- name: ", part_b)[1:]
    queries = {}
    for b in blocks:
        lines = b.split("\n")
        name = lines[0].strip()
        title = lines[1].replace("-- title:", "").strip() if lines[1].startswith("-- title:") else name
        sql = "\n".join(lines[2:]).strip()
        queries[name] = (title, sql)
    return queries


def kpi_row(st_container, df_worn: pd.DataFrame):
    """Five-card KPI row reused on Home and Insights pages."""
    c1, c2, c3, c4, c5 = st_container.columns(5)
    c1.metric("Users", f"{df_worn['User'].nunique()}")
    c2.metric("Avg Daily Steps", f"{df_worn['TotalSteps'].mean():,.0f}")
    c3.metric("Avg Calories", f"{df_worn['Calories'].mean():,.0f}")
    c4.metric("Avg Sedentary Hrs", f"{df_worn['SedentaryHours'].mean():.1f} h")
    c5.metric("Days Hitting 10k Steps", f"{df_worn['Met10k'].mean():.1%}")
