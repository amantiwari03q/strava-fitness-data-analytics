import sys
from pathlib import Path

import streamlit as st

sys.path.append(str(Path(__file__).resolve().parents[1]))
from utils import kpi_row, load_clean_data, worn_only  # noqa: E402

st.set_page_config(page_title="Insights | Bellabeat", page_icon="💡", layout="wide")
st.title("💡 Key Findings & Recommendations")
st.caption("Written for Bellabeat's marketing analytics team.")

df = load_clean_data()
worn = worn_only(df)
kpi_row(st, worn)
st.divider()

pct_below_10k = 1 - worn["Met10k"].mean()
pct_sedentary_time = worn["SedentaryMinutes"].sum() / (
    worn["SedentaryMinutes"].sum() + worn["ActiveMinutes"].sum()
)
sleep = worn.dropna(subset=["SleepHours"])
pct_short_sleep = (sleep["SleepHours"] < 7).mean()
pct_sleep_users = worn.loc[worn["SleepHours"].notna(), "User"].nunique() / worn["User"].nunique()
pct_hr_users = worn.loc[worn["HR_Avg"].notna(), "User"].nunique() / worn["User"].nunique()
pct_weight_users = worn.loc[worn["WeightKg"].notna(), "User"].nunique() / worn["User"].nunique()
never_10k = worn.groupby("User")["Met10k"].mean().eq(0).sum()

st.markdown("### What the data says")
st.markdown(
    f"""
| # | Finding | Evidence |
|---|---|---|
| 1 | Most days fall short of the 10,000-step benchmark | only **{1 - pct_below_10k:.0%}** of days reach it; **{never_10k} of {worn['User'].nunique()}** users never reach it |
| 2 | Users are sedentary most of the day | **{pct_sedentary_time:.0%}** of tracked minutes are sedentary |
| 3 | Activity depends on the person, not the day of week | weekday vs weekend averages are almost identical |
| 4 | Sleep is short, not restless | **{pct_short_sleep:.0%}** of nights are under 7 hours, but sleep efficiency stays high |
| 5 | Intensity beats volume for calorie burn | very-active minutes and distance explain calories better than raw steps |
| 6 | Secondary features are under-used | sleep **{pct_sleep_users:.0%}**, heart rate **{pct_hr_users:.0%}**, weight **{pct_weight_users:.0%}** of users |
"""
)

st.markdown("### Recommendations for Bellabeat")
st.markdown(
    """
1. **"Move a little more, more often"** - most users are light-activity; short guided sessions and hourly
   move/stand reminders (via Leaf or Time) can nudge light activity into moderate activity.
2. **Personalised step goals** instead of a flat 10,000 - segment users (sedentary / light / fairly / very
   active) and give each a realistic next milestone.
3. **Sleep programme** - bedtime reminders and wind-down routines targeted at the large share sleeping
   under 7 hours; efficiency is already high, so the fix is *bedtime*, not sleep quality.
4. **Retention nudges** - streaks, weekly summaries and reminders for users who wear the tracker
   inconsistently.
5. **Promote under-used features** - heart-rate tracking and automatic weight sync are used by a
   minority; in-app prompts could lift adoption.
6. **Segment marketing messages** - "every step counts" for beginners vs. performance/intensity
   messaging for the already-active group.
"""
)

st.markdown("### Limitations")
st.markdown(
    """
- Small sample: 33 users over 31 days, demographics unknown (may not represent Bellabeat's core audience).
- Sleep, heart-rate and weight data are available only for subsets of users.
- Correlation does not imply causation; this is an exploratory analysis, not a controlled study.
"""
)

st.divider()
st.download_button(
    "⬇ Download this summary as Markdown",
    data=f"""# Bellabeat x Fitbit - Key Findings & Recommendations

## Headline numbers
- Users: {worn['User'].nunique()}
- Avg daily steps: {worn['TotalSteps'].mean():,.0f}
- Avg daily calories: {worn['Calories'].mean():,.0f}
- % days hitting 10,000 steps: {1 - pct_below_10k:.1%}
- % time sedentary: {pct_sedentary_time:.1%}
- % nights under 7h sleep: {pct_short_sleep:.1%}

See the in-app Insights page for the full findings table and recommendations.
""",
    file_name="bellabeat_insights_summary.md",
    mime="text/markdown",
)
