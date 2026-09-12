import pandas as pd

df_m = pd.read_csv("data/dim_matches.csv")
df_d = pd.read_csv("data/fact_deliveries.csv")

print("--- Data Health Check ---")
print(f"Total Matches: {len(df_m)}")
print(f"Total Deliveries: {len(df_d)}")

# 1. Null checks
print("\nMissing values in dim_matches:")
print(df_m[['match_id', 'season', 'venue', 'match_winner']].isnull().sum())

# 2. Team name consistency check
print("\nUnique Teams in Dataset:")
print(sorted(df_m['team1'].dropna().unique()))

# 3. Match Result Breakdown
print("\nMatch Result Breakdown:")
print(df_m['result_type'].value_counts())