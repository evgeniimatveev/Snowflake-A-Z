# ===========================================================
# SNOWFLAKE PRACTICE - NATIVE STREAMLIT APP (CAPSTONE)
# Dataset: driver_lifetime_trips (loaded in 4th_Practice_CSV_Upload.sql)
# Goal: build an interactive dashboard directly inside Snowsight -
# no external hosting (HF Spaces / Streamlit Cloud), no separate
# database connection string - the app runs where the data lives.
# ===========================================================
#
# This file is a companion write-up for uber_trips_dashboard/streamlit_app.py.
# A Streamlit app is mostly UI clicks + Python, not SQL, so it doesn't
# fit the usual practice-script format of 1st-4th - but the process
# still deserves the same lecture-style record.

# -----------------------------------------------------------
# PART A - CREATING THE PROJECT (done in the UI)
# -----------------------------------------------------------
# Use case: Snowsight can scaffold a full Streamlit project (with a
# .streamlit/ config folder, pyproject.toml for dependencies, and a
# snowflake.yml describing the app) in one click - no local setup,
# no pip install, no virtualenv.
#
# Steps followed:
# 1. Workspaces Home -> "Streamlit App" quick-create button
# (also reachable via "+ Add new" -> "Streamlit App")
# 2. Snowsight scaffolds a new project folder with a boilerplate
# streamlit_app.py, pyproject.toml, snowflake.yml, and a
# .streamlit/ folder - then spins up a live container to run it
# 3. Settings (gear icon next to Deploy) confirms/sets:
# - Compute pool: SYSTEM_COMPUTE_POOL_CPU (small shared pool,
# fine for a light dashboard like this)
# - Query warehouse: COMPUTE_WH (this runs the SQL the app
# issues - separate from the compute pool that runs the
# Python/container itself)

# -----------------------------------------------------------
# PART B - THE APP CODE (see streamlit_app/streamlit_app.py)
# -----------------------------------------------------------
# Use case: turn a table already sitting in Snowflake into an
# interactive dashboard with zero external plumbing.
#
# Key building blocks, in the order they appear in the app:
#
# 1. st.connection("snowflake").session()
# -> inside Snowsight, this automatically uses the session
# you're already logged in as - no credentials, no connection
# string, unlike a Streamlit Cloud / HF Spaces app talking to
# Snowflake from outside.
#
# 2. session.sql(query).to_pandas()
# -> runs a normal SQL aggregate (GROUP BY city_name) and
# hands back a pandas DataFrame - the same COMPUTE_WH warehouse
# used everywhere else in this course does the actual work.
#
# 3. st.selectbox(...) plus a filtered = df[...] line
# -> the one piece of interactivity: picking a city recomputes
# `filtered` on every rerun (Streamlit reruns the whole script
# top-to-bottom on each widget interaction - no manual callback
# wiring needed).
#
# 4. st.metric / st.bar_chart / st.dataframe
# -> three different ways to show the same underlying numbers:
# headline KPIs, a visual comparison across cities, and the
# raw rows for anyone who wants to double check.
#
# Bug fixed during practice: the two st.bar_chart calls originally
# plotted the unfiltered `df` instead of `filtered`, so selecting
# a city updated the metrics and table but the charts stayed stuck
# showing all cities. Fix: swap `df` for `filtered` in both
# bar_chart(...).set_index(...) calls so every visual element
# responds to the same selectbox.

# -----------------------------------------------------------
# PART C - RENAMING AND DEPLOYING
# -----------------------------------------------------------
# Use case: "Untitled" is fine while experimenting, but a named,
# deployed app is what you would actually show in a portfolio.
#
# Steps:
# 1. Right-click the project in the sidebar -> Rename ->
# uber_trips_dashboard (renaming resets the live dev session,
# so the app needs Run again afterwards)
# 2. Click Deploy - this turns the temporary dev preview into a
# persistent Streamlit object other roles could be granted
# access to, instead of just a live editor tab

# ===========================================================
# RECAP
# - A Snowflake-native Streamlit app needs no external hosting,
# no separate auth to Snowflake, and no requirements.txt/venv
# management - Snowsight scaffolds and runs all of it.
# - st.connection("snowflake") plus session.sql(...) is the whole
# data access layer - no ORM, no API layer to write.
# - Streamlit's rerun-the-whole-script model means filtering logic
# is just plain Python re-executed on every interaction, not event
# handlers - simpler to reason about, at the cost of re-running
# the SQL query on every widget change.
# - This closes the 3-part Snowflake plan: Time Travel/Clone
# (3rd_Practice) -> CSV Upload (4th_Practice) -> Streamlit
# capstone (this file + streamlit_app/streamlit_app.py).
# ===========================================================
