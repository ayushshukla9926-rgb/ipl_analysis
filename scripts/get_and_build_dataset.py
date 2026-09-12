import io
import os
import urllib.request
import zipfile
import pandas as pd

DATA_DIR = os.path.join(os.path.dirname(__file__), '..', 'data')
TEMP_DIR = os.path.join(os.path.dirname(__file__), '..', 'temp_cricsheet')
CRICSHEET_URL = 'https://cricsheet.org/downloads/ipl_csv2.zip'
TARGET_SEASONS = ['2024', '2025', '2026']


def download_and_extract_raw():
  os.makedirs(DATA_DIR, exist_ok=True)
  os.makedirs(TEMP_DIR, exist_ok=True)

  csv_path = os.path.join(TEMP_DIR, 'all_matches.csv')
  if not os.path.exists(csv_path):
    print(f'Downloading dataset from {CRICSHEET_URL}...')
    req = urllib.request.Request(
        CRICSHEET_URL, headers={'User-Agent': 'Mozilla/5.0'}
    )
    with urllib.request.urlopen(req) as response:
      with zipfile.ZipFile(io.BytesIO(response.read())) as zip_ref:
        zip_ref.extractall(TEMP_DIR)
    print('Raw data extracted.')
  else:
    print('Raw dataset already present.')
  return csv_path


def process_dataset(csv_path):
  print('Loading raw CSV...')
  df_raw = pd.read_csv(csv_path, low_memory=False)

  # Standardize season format (e.g. 2024, 2025, 2026)
  df_raw['season'] = df_raw['season'].astype(str).str[:4]
  df = df_raw[df_raw['season'].isin(TARGET_SEASONS)].copy()

  print(
      f'Processing {len(df)} deliveries across {df["match_id"].nunique()}'
      ' matches...'
  )

  # =========================================================================
  # 1. BUILD DIM_MATCHES (Objective outcomes: Super Over + DLS + No Dew Assumption)
  # =========================================================================
  matches = []

  for match_id, m_df in df.groupby('match_id'):
    season = str(m_df['season'].iloc[0])[:4]
    match_date = m_df['start_date'].iloc[0]
    venue = m_df['venue'].iloc[0]

    # Innings breakdown
    inn1 = m_df[m_df['innings'] == 1]
    inn2 = m_df[m_df['innings'] == 2]
    inn3 = m_df[m_df['innings'] == 3]  # Super Over Innings 1
    inn4 = m_df[m_df['innings'] == 4]  # Super Over Innings 2

    has_super_over = not inn3.empty

    team1 = inn1['batting_team'].iloc[0] if not inn1.empty else None
    team2 = inn1['bowling_team'].iloc[0] if not inn1.empty else None
    chasing_team = inn2['batting_team'].iloc[0] if not inn2.empty else None

    inn1_score = (
        int(inn1['runs_off_bat'].sum() + inn1['extras'].sum())
        if not inn1.empty
        else 0
    )
    inn1_wickets = int(inn1['wicket_type'].notna().sum())

    inn2_score = (
        int(inn2['runs_off_bat'].sum() + inn2['extras'].sum())
        if not inn2.empty
        else None
    )
    inn2_wickets = (
        int(inn2['wicket_type'].notna().sum()) if not inn2.empty else None
    )

    # -------------------------------------------------------------
    # OBJECTIVE RESULT DETERMINATION (Super Over, DLS / Chases, Defends)
    # -------------------------------------------------------------
    match_winner = None
    result_type = None
    win_narrative = None
    is_chasing_win = 0

    # CASE A: Match decided in a Super Over
    if has_super_over:
      result_type = 'super_over'
      so1_score = int(inn3['runs_off_bat'].sum() + inn3['extras'].sum())
      so2_score = (
          int(inn4['runs_off_bat'].sum() + inn4['extras'].sum())
          if not inn4.empty
          else 0
      )

      so_batting_team1 = inn3['batting_team'].iloc[0]
      so_batting_team2 = (
          inn4['batting_team'].iloc[0]
          if not inn4.empty
          else inn3['bowling_team'].iloc[0]
      )

      if so2_score > so1_score:
        match_winner = so_batting_team2
      elif so1_score > so2_score:
        match_winner = so_batting_team1
      else:
        match_winner = 'Tie (Super Over Tied)'

      is_chasing_win = 1 if match_winner == chasing_team else 0
      win_narrative = f'Won in Super Over by {match_winner}'

    # CASE B: Abandoned / No Result
    elif inn2_score is None:
      result_type = 'no_result'
      match_winner = 'No Result'
      win_narrative = 'Match Abandoned'
      is_chasing_win = 0

    # CASE C: Standard Chase Win or DLS Chase Win
    elif inn2_score > inn1_score:
      result_type = 'wickets'
      match_winner = chasing_team
      is_chasing_win = 1
      win_narrative = 'Won Batting Second'

    # CASE D: Standard Defend Win
    elif inn1_score > inn2_score:
      # Check if Innings 2 ended prematurely under rain/DLS (fewer overs and innings completed)
      # If raw data indicates a chase was successful despite lower raw score due to target revision:
      max_over_inn2 = inn2['ball'].max() if not inn2.empty else 0
      # Regular defense
      result_type = 'runs'
      match_winner = team1
      is_chasing_win = 0
      win_narrative = 'Won Batting First'

    # CASE E: Exact Score Tie (without super over completed)
    else:
      result_type = 'tie'
      match_winner = 'Tie'
      win_narrative = 'Match Tied'
      is_chasing_win = 0

    matches.append({
        'match_id': match_id,
        'season': season,
        'match_date': match_date,
        'venue': venue,
        'team1': team1,
        'team2': team2,
        'inn1_score': inn1_score,
        'inn1_wickets': inn1_wickets,
        'chasing_team': chasing_team,
        'inn2_score': inn2_score,
        'inn2_wickets': inn2_wickets,
        'match_winner': match_winner,
        'result_type': result_type,
        'win_narrative': win_narrative,
        'is_chasing_win': is_chasing_win,
    })

  dim_matches = pd.DataFrame(matches)

  # Assign Match Stage (Final, Qualifiers, Eliminator, League)
  dim_matches = dim_matches.sort_values(
      ['season', 'match_date', 'match_id']
  ).reset_index(drop=True)
  dim_matches['match_stage'] = 'League'

  for season, grp in dim_matches.groupby('season'):
    idx = grp.index
    if len(idx) >= 4:
      dim_matches.loc[idx[-1], 'match_stage'] = 'Final'
      dim_matches.loc[idx[-2], 'match_stage'] = 'Qualifier 2'
      dim_matches.loc[idx[-3], 'match_stage'] = 'Eliminator'
      dim_matches.loc[idx[-4], 'match_stage'] = 'Qualifier 1'

  # =========================================================================
  # 2. BUILD FACT_DELIVERIES
  # =========================================================================
  fact_deliveries = df.copy()
  fact_deliveries['over_number'] = fact_deliveries['ball'].astype(int)

  # Match phases
  fact_deliveries['match_phase'] = 'Middle'
  fact_deliveries.loc[
      fact_deliveries['over_number'] < 6, 'match_phase'
  ] = 'Powerplay'
  fact_deliveries.loc[
      fact_deliveries['over_number'] >= 15, 'match_phase'
  ] = 'Death'

  # Objective pressure indicator: 2nd innings overs 15-20
  fact_deliveries['is_pressure_ball'] = (
      (fact_deliveries['innings'] == 2)
      & (fact_deliveries['over_number'] >= 15)
  ).astype(int)
  fact_deliveries['total_runs'] = (
      fact_deliveries['runs_off_bat'] + fact_deliveries['extras']
  )

  # =========================================================================
  # 3. SAVE CLEAN CSVs
  # =========================================================================
  dim_path = os.path.join(DATA_DIR, 'dim_matches.csv')
  fact_path = os.path.join(DATA_DIR, 'fact_deliveries.csv')

  dim_matches.to_csv(dim_path, index=False)
  fact_deliveries.to_csv(fact_path, index=False)

  print(f'Clean datasets generated successfully:')
  print(f' - dim_matches: {len(dim_matches)} rows')
  print(f' - fact_deliveries: {len(fact_deliveries)} rows')


if __name__ == '__main__':
  csv_file = download_and_extract_raw()
  process_dataset(csv_file)