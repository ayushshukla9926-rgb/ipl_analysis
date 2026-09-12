CREATE DATABASE IF NOT EXISTS ipl_db;
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


USE ipl_db;

-- 1. Consolidated Venue Intelligence
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

-- 2. Consolidated Death-Over Pressure Index (Innings 2, Overs 15-20)
CREATE OR REPLACE VIEW view_death_pressure_summary AS
SELECT 
    season,
    'Batting' AS role_type,
    striker AS player_name,
    batting_team AS team_name,
    COUNT(ball) AS deliveries,
    SUM(runs_off_bat) AS runs_metric,
    ROUND((SUM(runs_off_bat) * 100.0 / COUNT(ball)), 2) AS primary_rate, -- Strike Rate
    SUM(CASE WHEN runs_off_bat IN (4, 6) THEN 1 ELSE 0 END) AS boundaries_or_wickets
FROM fact_deliveries
WHERE is_pressure_ball = 1
GROUP BY season, striker, batting_team
HAVING COUNT(ball) >= 15

UNION ALL

SELECT 
    season,
    'Bowling' AS role_type,
    bowler AS player_name,
    bowling_team AS team_name,
    COUNT(ball) AS deliveries,
    SUM(runs_off_bat + COALESCE(wides, 0) + COALESCE(noballs, 0)) AS runs_metric,
    ROUND((SUM(runs_off_bat + COALESCE(wides, 0) + COALESCE(noballs, 0)) * 6.0) / COUNT(ball), 2) AS primary_rate, -- Economy Rate
    SUM(CASE 
        WHEN wicket_type IS NOT NULL 
             AND wicket_type NOT IN ('run out', 'retired hurt', 'retired out', 'obstructing the field') 
        THEN 1 ELSE 0 
    END) AS boundaries_or_wickets
FROM fact_deliveries
WHERE is_pressure_ball = 1
GROUP BY season, bowler, bowling_team
HAVING COUNT(ball) >= 15;











