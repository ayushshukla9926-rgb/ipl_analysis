CREATE DATABASE IF NOT EXISTS ipl_db;
USE ipl_db;

USE ipl_db;

DROP TABLE IF EXISTS fact_deliveries;
DROP TABLE IF EXISTS dim_matches;

CREATE TABLE dim_matches (
    match_id BIGINT PRIMARY KEY,
    season VARCHAR(10) NOT NULL,
    match_date DATE NOT NULL,
    venue VARCHAR(255) NOT NULL,
    team1 VARCHAR(100) NOT NULL,
    team2 VARCHAR(100) NOT NULL,
    inn1_score INT,
    inn1_wickets INT,
    chasing_team VARCHAR(100),
    inn2_score INT,
    inn2_wickets INT,
    match_winner VARCHAR(100),
    result_type VARCHAR(20),
    win_narrative VARCHAR(100),
    is_chasing_win INT DEFAULT 0,
    match_stage VARCHAR(30) DEFAULT 'League'
);

CREATE TABLE fact_deliveries (
    match_id BIGINT NOT NULL,
    season VARCHAR(10),
    start_date DATE,
    venue VARCHAR(255),
    innings INT NOT NULL,
    ball DECIMAL(4, 1) NOT NULL,
    batting_team VARCHAR(100) NOT NULL,
    bowling_team VARCHAR(100) NOT NULL,
    striker VARCHAR(100) NOT NULL,
    non_striker VARCHAR(100) NOT NULL,
    bowler VARCHAR(100) NOT NULL,
    runs_off_bat INT NOT NULL DEFAULT 0,
    extras INT NOT NULL DEFAULT 0,
    wides INT DEFAULT 0,
    noballs INT DEFAULT 0,
    byes INT DEFAULT 0,
    legbyes INT DEFAULT 0,
    penalty INT DEFAULT 0,
    wicket_type VARCHAR(50),
    player_dismissed VARCHAR(100),
    other_wicket_type VARCHAR(50),
    other_player_dismissed VARCHAR(100),
    over_number INT NOT NULL,
    match_phase VARCHAR(20) NOT NULL,
    is_pressure_ball INT NOT NULL DEFAULT 0,
    total_runs INT NOT NULL DEFAULT 0,
    INDEX idx_match (match_id),
    INDEX idx_striker (striker),
    INDEX idx_phase (match_phase),
    CONSTRAINT fk_deliveries_match FOREIGN KEY (match_id) REFERENCES dim_matches(match_id) ON DELETE CASCADE
);

/*
Views
*/

USE ipl_db;

-- ============================================================================
-- 1. VENUE INTELLIGENCE (Par Scores, Chasing/Defending Bias, Pitch Archetypes)
-- ============================================================================
CREATE OR REPLACE VIEW view_venue_intelligence AS
SELECT 
    season,
    venue,
    COUNT(match_id) AS total_matches,
    ROUND(AVG(inn1_score), 1) AS avg_1st_innings_score,
    ROUND(AVG(inn2_score), 1) AS avg_2nd_innings_score,
    ROUND(SUM(is_chasing_win) * 100.0 / COUNT(match_id), 1) AS chasing_win_pct,
    CASE 
        WHEN AVG(inn1_score) >= 195 THEN 'High-Scoring Track'
        WHEN AVG(inn1_score) <= 165 THEN 'Low-Scoring / Bowling Track'
        ELSE 'Balanced Surface'
    END AS pitch_archetype,
    CASE 
        WHEN (SUM(is_chasing_win) * 100.0 / COUNT(match_id)) >= 60.0 THEN 'Strong Chasing Advantage'
        WHEN (SUM(is_chasing_win) * 100.0 / COUNT(match_id)) <= 40.0 THEN 'Defending Advantage'
        ELSE 'Neutral / Toss Independent'
    END AS venue_chase_bias
FROM dim_matches
GROUP BY season, venue;

-- ============================================================================
-- 2. DEATH PRESSURE BATTERS (Innings 2, Overs 15-20 Chase Acceleration)
-- ============================================================================
CREATE OR REPLACE VIEW view_death_pressure_strikers AS
SELECT 
    season,
    striker AS player_name,
    batting_team AS team_name,
    COUNT(ball) AS death_balls_faced,
    SUM(runs_off_bat) AS total_death_runs,
    ROUND((SUM(runs_off_bat) * 100.0 / COUNT(ball)), 2) AS pressure_strike_rate,
    SUM(CASE WHEN runs_off_bat IN (4, 6) THEN 1 ELSE 0 END) AS death_boundaries,
    ROUND(SUM(CASE WHEN runs_off_bat IN (4, 6) THEN runs_off_bat ELSE 0 END) * 100.0 / NULLIF(SUM(runs_off_bat), 0), 1) AS boundary_run_pct
FROM fact_deliveries
WHERE is_pressure_ball = 1
GROUP BY season, striker, batting_team
HAVING COUNT(ball) >= 15
ORDER BY pressure_strike_rate DESC;

-- ============================================================================
-- 3. DEATH PRESSURE BOWLERS (Innings 2, Overs 15-20 Target Defending)
-- ============================================================================
CREATE OR REPLACE VIEW view_death_pressure_bowlers AS
SELECT 
    season,
    bowler AS player_name,
    bowling_team AS team_name,
    COUNT(ball) AS death_balls_bowled,
    ROUND(COUNT(ball) / 6.0, 1) AS overs_bowled,
    SUM(runs_off_bat + COALESCE(wides, 0) + COALESCE(noballs, 0)) AS runs_conceded,
    ROUND((SUM(runs_off_bat + COALESCE(wides, 0) + COALESCE(noballs, 0)) * 6.0) / COUNT(ball), 2) AS pressure_economy_rate,
    SUM(CASE 
        WHEN wicket_type IS NOT NULL 
             AND wicket_type NOT IN ('run out', 'retired hurt', 'retired out', 'obstructing the field') 
        THEN 1 ELSE 0 
    END) AS pressure_wickets,
    SUM(CASE WHEN total_runs = 0 THEN 1 ELSE 0 END) AS dot_balls,
    ROUND((SUM(CASE WHEN total_runs = 0 THEN 1 ELSE 0 END) * 100.0) / COUNT(ball), 1) AS dot_ball_pct
FROM fact_deliveries
WHERE is_pressure_ball = 1
GROUP BY season, bowler, bowling_team
HAVING COUNT(ball) >= 15
ORDER BY pressure_economy_rate ASC;

-- ============================================================================
-- 4. PLAYOFF CLUTCH BATTERS (Qualifiers, Eliminator, and Final)
-- ============================================================================
CREATE OR REPLACE VIEW view_playoff_clutch_leaders AS
SELECT 
    f.season,
    f.striker AS player_name,
    f.batting_team AS team_name,
    COUNT(DISTINCT f.match_id) AS playoff_matches,
    SUM(f.runs_off_bat) AS playoff_runs,
    ROUND(SUM(f.runs_off_bat) * 100.0 / COUNT(f.ball), 2) AS playoff_strike_rate,
    COUNT(CASE WHEN f.runs_off_bat = 6 THEN 1 END) AS playoff_sixes
FROM fact_deliveries f
JOIN dim_matches m ON f.match_id = m.match_id
WHERE m.match_stage IN ('Qualifier 1', 'Eliminator', 'Qualifier 2', 'Final')
GROUP BY f.season, f.striker, f.batting_team
ORDER BY playoff_runs DESC;

-- ============================================================================
-- 5. PLAYOFF CLUTCH BOWLERS (Qualifiers, Eliminator, and Final)
-- ============================================================================
CREATE OR REPLACE VIEW view_playoff_clutch_bowlers AS
SELECT 
    f.season,
    f.bowler AS player_name,
    f.bowling_team AS team_name,
    COUNT(DISTINCT f.match_id) AS playoff_matches,
    ROUND(COUNT(f.ball) / 6.0, 1) AS playoff_overs_bowled,
    SUM(f.runs_off_bat + COALESCE(f.wides, 0) + COALESCE(f.noballs, 0)) AS runs_conceded,
    ROUND((SUM(f.runs_off_bat + COALESCE(f.wides, 0) + COALESCE(f.noballs, 0)) * 6.0) / COUNT(f.ball), 2) AS playoff_economy_rate,
    SUM(CASE 
        WHEN f.wicket_type IS NOT NULL 
             AND f.wicket_type NOT IN ('run out', 'retired hurt', 'retired out', 'obstructing the field') 
        THEN 1 ELSE 0 
    END) AS playoff_wickets
FROM fact_deliveries f
JOIN dim_matches m ON f.match_id = m.match_id
WHERE m.match_stage IN ('Qualifier 1', 'Eliminator', 'Qualifier 2', 'Final')
GROUP BY f.season, f.bowler, f.bowling_team
ORDER BY playoff_wickets DESC, playoff_economy_rate ASC;

-- ============================================================================
-- 6. PHASE-WISE BATTER PERFORMANCE (Powerplay vs Middle vs Death)
-- ============================================================================
CREATE OR REPLACE VIEW view_phase_breakdown AS
SELECT 
    season,
    match_phase,
    striker AS player_name,
    batting_team AS team_name,
    COUNT(ball) AS balls_faced,
    SUM(runs_off_bat) AS runs_scored,
    ROUND(SUM(runs_off_bat) * 100.0 / COUNT(ball), 2) AS phase_strike_rate,
    SUM(CASE WHEN runs_off_bat IN (4, 6) THEN 1 ELSE 0 END) AS phase_boundaries
FROM fact_deliveries
GROUP BY season, match_phase, striker, batting_team
HAVING COUNT(ball) >= 30;



