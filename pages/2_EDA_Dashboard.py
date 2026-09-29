import sys
from pathlib import Path

import numpy as np
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import streamlit as st
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler

sys.path.append(str(Path(__file__).resolve().parents[1]))
from utils import PALETTE, PINK, PRIMARY, TEAL, WEEKDAY_ORDER, load_clean_data, worn_only  # noqa: E402

st.set_page_config(page_title="EDA Dashboard | Bellabeat", page_icon="📈", layout="wide")
st.title("📈 Interactive EDA Dashboard")

df = load_clean_data()
worn = worn_only(df)

# ---------------- Sidebar filters ----------------
st.sidebar.header("Filters")
users = st.sidebar.multiselect("Users", sorted(worn["User"].unique()), default=sorted(worn["User"].unique()))
day_types = st.sidebar.multiselect("Day type", ["Weekday", "Weekend"], default=["Weekday", "Weekend"])
date_range = st.sidebar.date_input(
    "Date range",
    value=(worn["Date"].min().date(), worn["Date"].max().date()),
    min_value=worn["Date"].min().date(),
    max_value=worn["Date"].max().date(),
)

f = worn[worn["User"].isin(users) & worn["DayType"].isin(day_types)]
if isinstance(date_range, tuple) and len(date_range) == 2:
    f = f[(f["Date"].dt.date >= date_range[0]) & (f["Date"].dt.date <= date_range[1])]

if f.empty:
    st.warning("No data for the current filters - widen your selection in the sidebar.")
    st.stop()

st.caption(f"Showing **{len(f)} rows** across **{f['User'].nunique()} users**.")

tabs = st.tabs(["Activity", "Sleep", "Correlations", "User Clusters"])

# ================= ACTIVITY =================
with tabs[0]:
    c1, c2 = st.columns(2)
    with c1:
        wk = f.groupby("Weekday", observed=True)["TotalSteps"].mean().reindex(WEEKDAY_ORDER).reset_index()
        fig = px.bar(wk, x="Weekday", y="TotalSteps", color_discrete_sequence=[PRIMARY], title="Avg steps by weekday")
        fig.add_hline(y=10000, line_dash="dash", line_color=PINK)
        st.plotly_chart(fig, use_container_width=True)
    with c2:
        fig = px.violin(f, x="Weekday", y="TotalSteps", category_orders={"Weekday": WEEKDAY_ORDER},
                         color_discrete_sequence=[TEAL], box=True, points=False, title="Step distribution by weekday")
        st.plotly_chart(fig, use_container_width=True)

    c3, c4 = st.columns(2)
    with c3:
        act = f.groupby("Weekday", observed=True)[["LightlyActiveMinutes", "FairlyActiveMinutes", "VeryActiveMinutes"]].mean().reindex(WEEKDAY_ORDER)
        fig = go.Figure()
        for col, name, color in zip(act.columns, ["Lightly active", "Fairly active", "Very active"], [TEAL, "#FDCB6E", PINK]):
            fig.add_trace(go.Bar(x=act.index, y=act[col], name=name, marker_color=color))
        fig.update_layout(barmode="stack", title="Active minutes by intensity & weekday")
        st.plotly_chart(fig, use_container_width=True)
    with c4:
        pt = f.pivot_table(index="User", columns="Weekday", values="TotalSteps", aggfunc="mean", observed=True)
        pt = pt.reindex(columns=WEEKDAY_ORDER)
        fig = px.imshow(pt, color_continuous_scale="YlGnBu", aspect="auto", title="Avg steps: user x weekday")
        st.plotly_chart(fig, use_container_width=True)

    cat = f["StepCategory"].value_counts(normalize=True).sort_index().mul(100).reset_index()
    cat.columns = ["StepCategory", "pct"]
    fig = px.bar(cat, x="pct", y="StepCategory", orientation="h", color_discrete_sequence=[PRIMARY],
                 title="Share of days by step category", labels={"pct": "% of days"})
    st.plotly_chart(fig, use_container_width=True)

# ================= SLEEP =================
with tabs[1]:
    sl = f.dropna(subset=["SleepHours"])
    if sl.empty:
        st.warning("No sleep data for the current filters.")
    else:
        c1, c2 = st.columns(2)
        with c1:
            fig = px.histogram(sl, x="SleepHours", nbins=30, color_discrete_sequence=["#0984E3"],
                                title="Nightly sleep duration")
            fig.add_vrect(x0=7, x1=9, fillcolor=TEAL, opacity=0.15, line_width=0, annotation_text="recommended")
            st.plotly_chart(fig, use_container_width=True)
        with c2:
            sw = sl.groupby("Weekday", observed=True)["SleepHours"].mean().reindex(WEEKDAY_ORDER).reset_index()
            fig = px.bar(sw, x="Weekday", y="SleepHours", color_discrete_sequence=["#74B9FF"], title="Avg sleep hours by weekday")
            fig.add_hline(y=7, line_dash="dash", line_color=PINK)
            st.plotly_chart(fig, use_container_width=True)

        c3, c4 = st.columns(2)
        with c3:
            fig = px.scatter(sl, x="TotalSteps", y="SleepHours", trendline="ols",
                              color_discrete_sequence=[PRIMARY], title="Steps vs sleep hours")
            st.plotly_chart(fig, use_container_width=True)
        with c4:
            fig = px.box(sl, x="StepCategory", y="SleepHours", color_discrete_sequence=[TEAL],
                         title="Sleep hours by step category")
            st.plotly_chart(fig, use_container_width=True)

        st.metric("Avg sleep efficiency", f"{sl['SleepEfficiency'].mean():.1f}%")

# ================= CORRELATIONS =================
with tabs[2]:
    num = f[["TotalSteps", "TotalDistance", "VeryActiveMinutes", "FairlyActiveMinutes", "LightlyActiveMinutes",
             "SedentaryMinutes", "Calories", "SleepHours", "SleepEfficiency"]]
    corr = num.corr()
    fig = px.imshow(corr, text_auto=".2f", color_continuous_scale="RdBu_r", zmin=-1, zmax=1, title="Correlation matrix")
    st.plotly_chart(fig, use_container_width=True)

    c1, c2 = st.columns(2)
    with c1:
        fig = px.scatter(f, x="TotalSteps", y="Calories", color="VeryActiveMinutes",
                          color_continuous_scale="Magma", trendline="ols", title="Steps vs calories")
        st.plotly_chart(fig, use_container_width=True)
    with c2:
        rows = []
        for c in ["TotalSteps", "TotalDistance", "VeryActiveMinutes", "FairlyActiveMinutes", "LightlyActiveMinutes", "SedentaryMinutes"]:
            r = f[[c, "Calories"]].corr().iloc[0, 1]
            rows.append((c, r ** 2))
        rank = pd.DataFrame(rows, columns=["variable", "R2"]).sort_values("R2")
        fig = px.bar(rank, x="R2", y="variable", orientation="h", color_discrete_sequence=[PINK],
                     title="R² of each variable vs calories")
        st.plotly_chart(fig, use_container_width=True)

# ================= CLUSTERS =================
with tabs[3]:
    per_user = f.groupby("User").agg(
        avg_steps=("TotalSteps", "mean"), avg_cal=("Calories", "mean"),
        sedentary_h=("SedentaryHours", "mean"), very_active=("VeryActiveMinutes", "mean"),
        days_worn=("TotalSteps", "size"), goal_rate=("Met10k", "mean"),
    ).dropna()

    if len(per_user) < 4:
        st.warning("Need at least 4 users with data to cluster - widen the filters.")
    else:
        k = st.slider("Number of clusters (k)", 2, 6, 3)
        X = StandardScaler().fit_transform(per_user)
        km = KMeans(k, n_init=10, random_state=42).fit(X)
        per_user = per_user.copy()
        per_user["Cluster"] = km.labels_.astype(str)

        c1, c2 = st.columns([1.3, 1])
        with c1:
            fig = px.scatter(
                per_user.reset_index(), x="avg_steps", y="sedentary_h", color="Cluster",
                size="avg_cal", hover_name="User", color_discrete_sequence=PALETTE,
                title="User clusters: steps vs sedentary hours",
            )
            st.plotly_chart(fig, use_container_width=True)
        with c2:
            st.dataframe(
                per_user.reset_index().sort_values("avg_steps", ascending=False).round(1),
                use_container_width=True, height=400,
            )
