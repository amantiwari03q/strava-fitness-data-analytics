import sys
from pathlib import Path

import pandas as pd
import streamlit as st

sys.path.append(str(Path(__file__).resolve().parents[1]))
from utils import get_sql_connection, parse_named_queries  # noqa: E402

st.set_page_config(page_title="SQL Explorer | Bellabeat", page_icon="🗄️", layout="wide")
st.title("🗄️ SQL Explorer")
st.caption(
    "The full SQL file (data cleaning + 24 analysis queries) runs live against an in-memory "
    "SQLite database built from fitbit_merged_daily.csv. Pick a saved query or write your own."
)

con = get_sql_connection()
queries = parse_named_queries()

tab1, tab2 = st.tabs(["📋 Saved case-study queries", "✍️ Custom SQL"])

with tab1:
    names = list(queries.keys())
    labels = [f"{n} - {queries[n][0]}" for n in names]
    choice = st.selectbox("Choose a query", labels, index=0)
    qname = names[labels.index(choice)]
    title, sql = queries[qname]

    st.markdown(f"**{title}**")
    st.code(sql, language="sql")

    if st.button("▶ Run query", type="primary"):
        try:
            result = pd.read_sql(sql, con)
            st.success(f"{len(result)} rows returned")
            st.dataframe(result, use_container_width=True)

            numeric_cols = result.select_dtypes("number").columns.tolist()
            first_col = result.columns[0]
            if len(numeric_cols) >= 1 and result[first_col].nunique() <= 40 and result[first_col].dtype == object:
                st.markdown("**Quick chart**")
                st.bar_chart(result.set_index(first_col)[numeric_cols[:3]])

            csv = result.to_csv(index=False).encode()
            st.download_button("Download result as CSV", csv, file_name=f"{qname}.csv", mime="text/csv")
        except Exception as e:
            st.error(f"Query failed: {e}")

with tab2:
    st.markdown(
        "Tables available: `fitbit_daily` (raw merged data) and `fitbit_clean` "
        "(cleaned view with weekday, sleep hours, step categories, `is_worn_day` flag, etc.)"
    )
    default_sql = "SELECT * FROM fitbit_clean LIMIT 20;"
    user_sql = st.text_area("Write a SQL query", value=default_sql, height=160)
    if st.button("▶ Run custom query"):
        try:
            result = pd.read_sql(user_sql, con)
            st.success(f"{len(result)} rows returned")
            st.dataframe(result, use_container_width=True)
            csv = result.to_csv(index=False).encode()
            st.download_button("Download result as CSV", csv, file_name="custom_query.csv", mime="text/csv")
        except Exception as e:
            st.error(f"Query failed: {e}")

with st.expander("📄 View the full SQL file"):
    st.code(Path(__file__).resolve().parents[1].joinpath("sql", "00_combined.sql").read_text(), language="sql")
