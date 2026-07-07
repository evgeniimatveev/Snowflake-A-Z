import streamlit as st

st.set_page_config(page_title="Uber Trips Dashboard", layout="wide")
st.title("Uber Driver Trips - Native Streamlit in Snowsight")
st.caption("Data loaded via the CSV upload wizard (see 4th_Practice_CSV_Upload.sql) - fully native in Snowflake, no external DB or hosting needed.")

session = st.connection("snowflake").session()
TABLE = "SNOWFLAKE_LEARNING_DB.EVGENIIMATVEEV_LOAD_SAMPLE_DATA_FROM_S3.DRIVER_LIFETIME_TRIPS"

query = f"SELECT city_name, COUNT(*) AS trip_count, ROUND(AVG(trip_distance_miles), 2) AS avg_distance_miles, ROUND(SUM(original_fare_usd), 2) AS total_fare_usd FROM {TABLE} GROUP BY city_name ORDER BY trip_count DESC"
df = session.sql(query).to_pandas()

city_list = ["All cities"] + df["CITY_NAME"].tolist()
selected_city = st.selectbox("Filter by city", city_list)
filtered = df[df["CITY_NAME"] == selected_city] if selected_city != "All cities" else df

col1, col2, col3 = st.columns(3)
col1.metric("Total trips", int(filtered["TRIP_COUNT"].sum()))
col2.metric("Total fare (USD)", f"${filtered['TOTAL_FARE_USD'].sum():,.2f}")
col3.metric("Avg distance (mi)", round(filtered["AVG_DISTANCE_MILES"].mean(), 2))

st.subheader("Trips by city")
st.bar_chart(filtered.set_index("CITY_NAME")["TRIP_COUNT"])

st.subheader("Total fare by city (USD)")
st.bar_chart(filtered.set_index("CITY_NAME")["TOTAL_FARE_USD"])

st.subheader("Underlying data")
st.dataframe(filtered, use_container_width=True)
