-- 1.How does health spending share (health expenditure per capita relative to GDP per capita) 
-- compare with average mental health disorder occurrence across regions, and how have both measures changed across the 3-year periods spanning 2000–2017?
WITH country_year AS (
    SELECT
        c.country_name,
        c.region,
        t.year,
        t.period,
        m.countryID,
        m.timeID,

        MAX(m.gdp) AS gdp_per_capita,
        MAX(m.healthExp) AS health_exp_per_capita,

        AVG(m.mentalHealth_rate)
            AS avg_mental_health_rate

    FROM Mental_Health_Fact AS m

    JOIN Country AS c
        ON m.countryID = c.countryID

    JOIN Time AS t
        ON m.timeID = t.timeID

    GROUP BY
        c.country_name,
        c.region,
        t.year,
        t.period,
        m.countryID,
        m.timeID
),

complete_cases AS (
    SELECT
        *,
        100.0 * health_exp_per_capita
        / NULLIF(gdp_per_capita, 0)
        AS health_spending_share
    FROM country_year

    WHERE gdp_per_capita IS NOT NULL
      AND health_exp_per_capita IS NOT NULL
      AND gdp_per_capita > 0
)

SELECT
    region,
    period,

    COUNT(*) AS country_year_observations,

    ROUND(
        AVG(health_spending_share),
        2
    ) AS avg_health_spending_share_pct,

    ROUND(
        AVG(avg_mental_health_rate),
        3
    ) AS avg_mental_health_disorder_rate_pct

FROM complete_cases

GROUP BY
    region,
    period

ORDER BY
    period,
    region;
	
-- 2.How has the relationship between GDP per capita and mental health disorder rates changed across the 2000–2017 period, 
-- and does this pattern differ by region?
WITH country_year AS (
    SELECT
        c.countryID,
        c.country_name,
        c.region,
        t.period,
        t.year,
        MAX(m.gdp) AS gdp_per_capita,
        AVG(m.mentalHealth_rate) AS avg_mental_health_rate
    FROM Mental_Health_Fact AS m
    JOIN Country AS c
        ON m.countryID = c.countryID
    JOIN Time AS t
        ON m.timeID = t.timeID
    WHERE m.gdp IS NOT NULL
      AND m.gdp > 0
    GROUP BY
        c.countryID,
        c.country_name,
        c.region,
        t.period,
        t.year
),

country_period AS (
    SELECT
        countryID,
        country_name,
        region,
        period,
        AVG(gdp_per_capita) AS avg_gdp_per_capita,
        AVG(avg_mental_health_rate) AS avg_mental_health_rate
    FROM country_year
    GROUP BY
        countryID,
        country_name,
        region,
        period
),

correlation_stats AS (
    SELECT
        region,
        period,
        COUNT(*) AS n,
        SUM(avg_gdp_per_capita) AS sum_x,
        SUM(avg_mental_health_rate) AS sum_y,
        SUM(avg_gdp_per_capita * avg_mental_health_rate) AS sum_xy,
        SUM(avg_gdp_per_capita * avg_gdp_per_capita) AS sum_x2,
        SUM(avg_mental_health_rate * avg_mental_health_rate) AS sum_y2
    FROM country_period
    GROUP BY
        region,
        period
)

SELECT
    region,
    period,
    n AS countries,
    ROUND(
        (n * sum_xy - sum_x * sum_y)
        /
        NULLIF(
            SQRT(
                (n * sum_x2 - sum_x * sum_x)
                *
                (n * sum_y2 - sum_y * sum_y)
            ),
            0
        ),
        3
    ) AS pearson_r
FROM correlation_stats
ORDER BY
    region,
    period;
--3. Among countries with similar levels of health expenditure per capita, which countries show disorder-specific prevalence trends that deviate most from their spending peers across the six 3-year periods from 2000 to 2017?
WITH country_year AS (
    SELECT
        c.countryID,
        c.country_name,
        t.year,
        t.period,
        MAX(m.healthExp) AS health_exp_per_capita
    FROM Mental_Health_Fact AS m
    JOIN Country AS c
        ON m.countryID = c.countryID
    JOIN Time AS t
        ON m.timeID = t.timeID
    WHERE m.healthExp IS NOT NULL
    GROUP BY
        c.countryID,
        c.country_name,
        t.year,
        t.period
),

country_period_spending AS (
    SELECT
        countryID,
        country_name,
        period,
        AVG(health_exp_per_capita)
            AS avg_health_exp_per_capita
    FROM country_year
    GROUP BY
        countryID,
        country_name,
        period
),

spending_groups AS (
    SELECT
        *,
        NTILE(4) OVER (
            PARTITION BY period
            ORDER BY avg_health_exp_per_capita
        ) AS spending_quartile
    FROM country_period_spending
),

country_period_disorder AS (
    SELECT
        c.countryID,
        c.country_name,
        t.period,
        d.disorder_name,
        AVG(m.mentalHealth_rate)
            AS avg_prevalence
    FROM Mental_Health_Fact AS m
    JOIN Country AS c
        ON m.countryID = c.countryID
    JOIN Time AS t
        ON m.timeID = t.timeID
    JOIN Disorder AS d
        ON m.disorderID = d.disorderID
    GROUP BY
        c.countryID,
        c.country_name,
        t.period,
        d.disorder_name
),

peer_data AS (
    SELECT
        cpd.countryID,
        cpd.country_name,
        cpd.period,
        cpd.disorder_name,
        cpd.avg_prevalence,
        sg.avg_health_exp_per_capita,
        sg.spending_quartile
    FROM country_period_disorder AS cpd
    JOIN spending_groups AS sg
        ON cpd.countryID = sg.countryID
       AND cpd.period = sg.period
),

peer_stats AS (
    SELECT
        *,
        AVG(avg_prevalence) OVER (
            PARTITION BY
                period,
                spending_quartile,
                disorder_name
        ) AS peer_mean,

        AVG(avg_prevalence * avg_prevalence) OVER (
            PARTITION BY
                period,
                spending_quartile,
                disorder_name
        ) AS peer_mean_sq

    FROM peer_data
),

scored AS (
    SELECT
        *,
        CASE
            WHEN peer_mean_sq - peer_mean * peer_mean > 0
            THEN
                (avg_prevalence - peer_mean)
                /
                SQRT(
                    peer_mean_sq
                    - peer_mean * peer_mean
                )
        END AS z_score
    FROM peer_stats
),

summary AS (
    SELECT
        country_name,
        disorder_name,
        COUNT(*) AS periods_observed,

        ROUND(
            AVG(ABS(z_score)), 2
        ) AS avg_abs_z,

        ROUND(
            AVG(z_score), 2
        ) AS avg_signed_z,

        ROUND(
            MAX(ABS(z_score)), 2
        ) AS max_abs_z,

        SUM(
            CASE
                WHEN ABS(z_score) >= 2
                THEN 1
                ELSE 0
            END
        ) AS outlier_periods

    FROM scored

    GROUP BY
        country_name,
        disorder_name

    HAVING COUNT(*) = 6
)

SELECT
    country_name,
    disorder_name,
    avg_abs_z,
    avg_signed_z,
    max_abs_z,
    outlier_periods
FROM summary

ORDER BY
    avg_abs_z DESC,
    country_name,
    disorder_name

LIMIT 10;
