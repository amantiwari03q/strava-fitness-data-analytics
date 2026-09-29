import plotly.express as px
import plotly.graph_objects as go
import streamlit as st

from utils import PALETTE, PINK, PRIMARY, TEAL, WEEKDAY_ORDER, kpi_row, load_clean_data, worn_only

st.set_page_config(page_title="Bellabeat | Fitbit Analytics", page_icon="💪", layout="wide")

st.title("💪 Bellabeat x Fitbit Fitness Data Analytics")
st.caption(
    "Case study: how do consumers use smart fitness trackers, and what should Bellabeat's "
    "marketing team do with that insight? Data: 33 Fitbit users, Apr 12 - May 12, 2016."
)

df = load_clean_data()
worn = worn_only(df)

st.markdown("### 📌 Headline numbers (tracker-worn days only)")
kpi_row(st, worn)

st.divider()

left, right = st.columns([1.3, 1])

with left:
    st.subheader("Average steps by weekday")
    wk = (
        worn.groupby("Weekday", observed=True)["TotalSteps"]
        .mean()
        .reindex(WEEKDAY_ORDER)
        .reset_index()
    )
    fig = px.bar(wk, x="Weekday", y="TotalSteps", color_discrete_sequence=[PRIMARY])
    fig.add_hline(y=10000, line_dash="dash", line_color=PINK, annotation_text="10,000-step goal")
    fig.update_layout(yaxis_title="Avg steps", xaxis_title="", showlegend=False, height=380)
    st.plotly_chart(fig, use_container_width=True)

with right:
    st.subheader("How the day is spent")
    minutes = worn[["SedentaryMinutes", "LightlyActiveMinutes", "FairlyActiveMinutes", "VeryActiveMinutes"]].sum()
    labels = ["Sedentary", "Lightly active", "Fairly active", "Very active"]
    fig = go.Figure(
        data=[go.Pie(labels=labels, values=minutes.values, hole=0.45, marker_colors=["#B2BEC3", TEAL, "#FDCB6E", PINK])]
    )
    fig.update_layout(height=380, margin=dict(t=10, b=10))
    st.plotly_chart(fig, use_container_width=True)

st.divider()

st.subheader("Steps trend over the study period (7-day rolling average)")
daily = worn.groupby("Date")["TotalSteps"].mean().reset_index()
daily["Rolling7"] = daily["TotalSteps"].rolling(7, min_periods=3).mean()
fig = go.Figure()
fig.add_trace(go.Scatter(x=daily["Date"], y=daily["TotalSteps"], mode="lines+markers",
                          name="Daily avg", line=dict(color="#B2BEC3", width=1), marker=dict(size=4)))
fig.add_trace(go.Scatter(x=daily["Date"], y=daily["Rolling7"], mode="lines",
                          name="7-day avg", line=dict(color=PRIMARY, width=3)))
fig.add_hline(y=10000, line_dash="dash", line_color=PINK)
fig.update_layout(height=380, yaxis_title="Avg steps across users", legend=dict(orientation="h", y=1.1))
st.plotly_chart(fig, use_container_width=True)

st.divider()

st.subheader("User segments by average daily steps")
seg = (
    worn.groupby("User")["TotalSteps"]
    .mean()
    .reset_index()
)
seg["Segment"] = seg["TotalSteps"].apply(
    lambda s: "1. Sedentary (<5k)" if s < 5000
    else "2. Lightly active (5-7.5k)" if s < 7500
    else "3. Fairly active (7.5-10k)" if s < 10000
    else "4. Very active (10k+)"
)
counts = seg["Segment"].value_counts().sort_index().reset_index()
counts.columns = ["Segment", "Users"]
c1, c2 = st.columns([1, 1.4])
with c1:
    fig = px.pie(counts, names="Segment", values="Users", hole=0.4, color_discrete_sequence=PALETTE)
    fig.update_layout(height=340, margin=dict(t=10, b=10))
    st.plotly_chart(fig, use_container_width=True)
with c2:
    fig = px.bar(
        seg.sort_values("TotalSteps", ascending=False),
        x="User", y="TotalSteps", color="Segment", color_discrete_sequence=PALETTE,
    )
    fig.add_hline(y=10000, line_dash="dash", line_color=PINK)
    fig.update_layout(height=340, yaxis_title="Avg steps", xaxis_title="")
    st.plotly_chart(fig, use_container_width=True)

st.info(
    "Use the pages in the left sidebar: **SQL Explorer** to run the 24 case-study queries live, "
    "**EDA Dashboard** for interactive filtered charts, and **Insights** for the findings & "
    "recommendations written up for Bellabeat's marketing team.",
    icon="👈",
)
