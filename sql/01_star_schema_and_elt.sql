--------------------- STAR SCHEMA AND ELT PROCESS ---------------------

-- # 1
-- STAR SCHEMA 

DROP TABLE IF EXISTS Mental_Health_Fact;
DROP TABLE IF EXISTS Country;
DROP TABLE IF EXISTS Time;
DROP TABLE IF EXISTS Disorder;

-- Enable foreign key enforcement before creating tables 
PRAGMA foreign_keys = ON; 

-- Create DIM Country -- 
CREATE TABLE Country (
	countryID INTEGER PRIMARY KEY AUTOINCREMENT
	, country_code TEXT UNIQUE NOT NULL
	, country_name TEXT NOT NULL
	, region TEXT
	, income_group TEXT
);


-- Create DIM Time -- 
CREATE TABLE Time (
	timeID INTEGER PRIMARY KEY AUTOINCREMENT
	, year INTEGER UNIQUE NOT NULL
	, period TEXT NOT NULL -- attribute hierarchy
);


-- Create DIM Disorder -- 
CREATE TABLE Disorder (
	disorderID INTEGER PRIMARY KEY AUTOINCREMENT
	, disorder_name TEXT UNIQUE NOT NULL
);


-- Create FACT Mental_Health_Fact -- 
CREATE TABLE Mental_Health_Fact (
	countryID INTEGER NOT NULL REFERENCES Country(countryID)
	, timeID INTEGER NOT NULL REFERENCES Time(timeID)
	, disorderID INTEGER NOT NULL REFERENCES Disorder(disorderID)
	, mentalHealth_rate REAL
	, gdp REAL
	, healthExp REAL
	, PRIMARY KEY (countryID, timeID, disorderID)
);


-- # 2
-- EXTRACT: Download raw data from each source (WHO and kaggle)


-- # 3
-- LOAD: Import each raw data (csv file) to DBMS.
-- load - explore loaded dataset

-- #3.1 Checking total row per-each dataset
SELECT 'HE' as remarks
, Count (*) as total_row -- 4585
FROM raw_health_expenditure
GROUP BY 1

union all 

SELECT 'MH' as remarks
, Count (*) as total_row -- 108553
FROM raw_mental_health
GROUP BY 1 

UNION ALL 

SELECT 'GDP' as remarks
, Count (*) as total_row -- 265
FROM raw_gdp
GROUP BY 1 

UNION ALL

SELECT 'ME' as remarks
, Count (*) as total_row -- 264
FROM raw_metadata_gdp
GROUP BY 1;

--#3.2 Checking how many countries are included
SELECT 'raw mental health' as remarks
					, COUNT (DISTINCT code) as total_country --236
FROM raw_mental_health
WHERE code IS NOT NULL AND code != ''
GROUP BY 1

UNION ALL 

SELECT 'raw gdp' as remarks
					, COUNT (DISTINCT "Country Code") as total_country --265
FROM raw_gdp
GROUP BY 1

UNION ALL 

SELECT 'raw health expenditure' as remarks
					, COUNT (DISTINCT SpatialDimValueCode) as total_country --195
FROM raw_health_expenditure
WHERE "Location type" = 'Country'
GROUP BY 1

UNION ALL 

SELECT 'raw metadata' as remarks
					, COUNT (DISTINCT "Country Code") as total_country --217
FROM raw_metadata_gdp
WHERE Region IS NOT NULL AND Region != ''
GROUP BY 1;

-- #3.3 Checking missing value
-- missing value from mental health
SELECT SUM(CASE WHEN [Schizophrenia (%)] IS NULL THEN 1 ELSE 0 END) AS null_schizophrenia
    , SUM(CASE WHEN [Bipolar disorder (%)] IS NULL THEN 1 ELSE 0 END) AS null_bipolar
    , SUM(CASE WHEN [Eating disorders (%)] IS NULL THEN 1 ELSE 0 END) AS null_eating
    , SUM(CASE WHEN [Anxiety disorders (%)] IS NULL THEN 1 ELSE 0 END) AS null_anxiety
    , SUM(CASE WHEN [Drug use disorders (%)] IS NULL THEN 1 ELSE 0 END) AS null_drug_use
    , SUM(CASE WHEN [Depression (%)] IS NULL THEN 1 ELSE 0 END) AS null_depression
    , SUM(CASE WHEN [Alcohol use disorders (%)] IS NULL THEN 1 ELSE 0 END) AS null_alcohol
    , COUNT(*) AS total_rows
FROM raw_mental_health;

-- missing value from gdp
SELECT 2000 AS year, SUM(CASE WHEN "2000" IS NULL THEN 1 ELSE 0 END) AS null_count FROM raw_gdp
UNION ALL
SELECT 2001, SUM(CASE WHEN "2001" IS NULL THEN 1 ELSE 0 END) FROM raw_gdp
UNION ALL
SELECT 2002, SUM(CASE WHEN "2002" IS NULL THEN 1 ELSE 0 END) FROM raw_gdp
UNION ALL
SELECT 2003, SUM(CASE WHEN "2003" IS NULL THEN 1 ELSE 0 END) FROM raw_gdp
UNION ALL
SELECT 2004, SUM(CASE WHEN "2004" IS NULL THEN 1 ELSE 0 END) FROM raw_gdp
UNION ALL
SELECT 2005, SUM(CASE WHEN "2005" IS NULL THEN 1 ELSE 0 END) FROM raw_gdp
UNION ALL
SELECT 2006, SUM(CASE WHEN "2006" IS NULL THEN 1 ELSE 0 END) FROM raw_gdp
UNION ALL
SELECT 2007, SUM(CASE WHEN "2007" IS NULL THEN 1 ELSE 0 END) FROM raw_gdp
UNION ALL
SELECT 2008, SUM(CASE WHEN "2008" IS NULL THEN 1 ELSE 0 END) FROM raw_gdp
UNION ALL
SELECT 2009, SUM(CASE WHEN "2009" IS NULL THEN 1 ELSE 0 END) FROM raw_gdp
UNION ALL
SELECT 2010, SUM(CASE WHEN "2010" IS NULL THEN 1 ELSE 0 END) FROM raw_gdp
UNION ALL
SELECT 2011, SUM(CASE WHEN "2011" IS NULL THEN 1 ELSE 0 END) FROM raw_gdp
UNION ALL
SELECT 2012, SUM(CASE WHEN "2012" IS NULL THEN 1 ELSE 0 END) FROM raw_gdp
UNION ALL
SELECT 2013, SUM(CASE WHEN "2013" IS NULL THEN 1 ELSE 0 END) FROM raw_gdp
UNION ALL
SELECT 2014, SUM(CASE WHEN "2014" IS NULL THEN 1 ELSE 0 END) FROM raw_gdp
UNION ALL
SELECT 2015, SUM(CASE WHEN "2015" IS NULL THEN 1 ELSE 0 END) FROM raw_gdp
UNION ALL
SELECT 2016, SUM(CASE WHEN "2016" IS NULL THEN 1 ELSE 0 END) FROM raw_gdp
UNION ALL
SELECT 2017, SUM(CASE WHEN "2017" IS NULL THEN 1 ELSE 0 END) FROM raw_gdp
ORDER BY year;


-- missing value from health expenditure
SELECT COUNT (*) as all_rows
				, SUM (CASE WHEN FactValueNumeric IS NULL  THEN 1 ELSE 0 END) AS missing_rows
FROM raw_health_expenditure;



--#3.4 Checking country code 
-- total uncomplete data: 83 entity
-- m.code is null --> mental health aggregate rows
-- g."Country Code" null --> missing value & World Bank aggregate row
-- h.SpatialDimValueCode null --> missing value 
SELECT DISTINCT m.Entity
										, m.code
										, g."Country Code"
										, h.SpatialDimValueCode
FROM raw_mental_health m
LEFT JOIN raw_gdp g on m.code =  g."Country Code"
LEFT JOIN raw_health_expenditure h on m.code = h.SpatialDimValueCode
WHERE g."Country Code" IS NULL OR h.SpatialDimValueCode IS NULL;


-- # 4
-- TRANSFORM

-- #4.1 Country -- 
-- Inserting country data to Country DIM
-- Excludes World Bank aggregate rows ("World", "Africa Eastern and Southern", etc.) by requiring a non-null Region.
DELETE FROM Country;
INSERT INTO Country (country_code, country_name, region, income_group)
SELECT DISTINCT [Country Code]
										, TableName
										, Region
										, IncomeGroup
FROM raw_metadata_gdp -- taken from gdp data; Selected due to its broader country coverage (265 countries vs. 195 and 236).
WHERE Region IS NOT NULL AND Region != '';


-- #4.2 Time  -- 
-- Inserting time data to Time DIM
-- Year --> Period attribute hierarchy, six 3-year buckets accross 2000-2017
DELETE FROM Time;
INSERT INTO Time (year, period)
SELECT n
			  , CASE
				WHEN n BETWEEN 2000 AND 2002 THEN '2000-2002'
				WHEN n BETWEEN 2003 AND 2005 THEN '2003-2005'
				WHEN n BETWEEN 2006 AND 2008 THEN '2006-2008'
				WHEN n BETWEEN 2009 AND 2011 THEN '2009-2011'
				WHEN n BETWEEN 2012 AND 2014 THEN '2012-2014'
				WHEN n BETWEEN 2015 AND 2017 THEN '2015-2017'
			  END
FROM (
			  WITH 
			  RECURSIVE seq(n) AS (
				SELECT 2000
				UNION ALL
				SELECT n + 1 
				FROM seq 
				WHERE n < 2017
			  )
  SELECT n FROM seq
);


-- #4.3 Disorder --
-- Inserting disorder data to Disorder DIM
-- Disorder name --> from mental health raw data column names
DELETE FROM Disorder;
INSERT INTO Disorder (disorder_name) VALUES
    ('Schizophrenia'), ('Bipolar disorder'), ('Eating disorders'),
    ('Anxiety disorders'), ('Drug use disorders'), ('Depression'),
    ('Alcohol use disorders');
	

-- #3.4 Mental Healt Fact --	
-- FACT TABLE; use INSERT + CTE to select the data
DELETE FROM Mental_Health_Fact;
INSERT INTO Mental_Health_Fact (countryID, timeID, disorderID, mentalHealth_rate, gdp, healthExp)

-- (Start) CTE: Select and prepare data for insertion into Mental_Health_Fact

WITH 

-- disorder_cleaning: Filter mental health records with non-null country codes, non-null each disorders pct, and retain data from 2000–2017
disorder_cleaning as (
SELECT
    Entity AS country_name,
    Code AS country_code,
    Year AS year,
    [Schizophrenia (%)]         AS schizophrenia_pct,
    [Bipolar disorder (%)]      AS bipolar_pct,
    [Eating disorders (%)]      AS eating_disorders_pct,
    [Anxiety disorders (%)]     AS anxiety_disorders_pct,
    [Drug use disorders (%)]    AS drug_use_disorders_pct,
    [Depression (%)]            AS depression_pct,
    [Alcohol use disorders (%)] AS alcohol_use_disorders_pct
FROM raw_mental_health
WHERE [Schizophrenia (%)] IS NOT NULL
  AND [Bipolar disorder (%)] IS NOT NULL
  AND [Eating disorders (%)] IS NOT NULL
  AND [Anxiety disorders (%)] IS NOT NULL
  AND [Drug use disorders (%)] IS NOT NULL
  AND [Depression (%)] IS NOT NULL
  AND [Alcohol use disorders (%)] IS NOT NULL
  AND Code IS NOT NULL AND Code != ''
  AND Year BETWEEN 2000 AND 2017
  )
  
 -- disorder_unpivot: Unpivot disorder data from disorder_cleaning
 , disorder_unpivot as ( 
SELECT country_code, year, 'Schizophrenia' as disorder_name, schizophrenia_pct as mentalHealth_rate FROM disorder_cleaning
UNION ALL 
SELECT country_code, year, 'Bipolar disorder' as disorder_name, bipolar_pct as mentalHealth_rate FROM disorder_cleaning
UNION ALL 
SELECT country_code, year, 'Eating disorders' as disorder_name, eating_disorders_pct as mentalHealth_rate FROM disorder_cleaning
UNION ALL 
SELECT country_code, year, 'Anxiety disorders' as disorder_name, anxiety_disorders_pct as mentalHealth_rate FROM disorder_cleaning
UNION ALL 
SELECT country_code, year, 'Drug use disorders' as disorder_name, drug_use_disorders_pct as mentalHealth_rate FROM disorder_cleaning
UNION ALL 
SELECT country_code, year, 'Depression' as disorder_name, depression_pct as mentalHealth_rate FROM disorder_cleaning
UNION ALL 
SELECT country_code, year, 'Alcohol use disorders' as disorder_name, alcohol_use_disorders_pct as mentalHealth_rate FROM disorder_cleaning
)

-- health_expenditure_clean: Select country-level health expenditure data for 2000–2017
-- Rename fields to country_code, year, and healthExp for the fact table
-- Convert Period from text to integer for consistent year handling
, health_expenditure_clean as (
SELECT SpatialDimValueCode as country_code 
					, CAST (Period AS INTEGER) as year
					, FactValueNumeric as healthExp
FROM raw_health_expenditure
WHERE Period BETWEEN 2000 AND 2017
AND "Location type" = 'Country'
)

 -- gdp_unpivot: Unpivot disorder data from raw_gdp
, gdp_unpivot as (
SELECT "Country Name" as country_name, "Country Code" as country_code, 2000 as year, "2000" as gdp FROM raw_gdp WHERE "2000" IS NOT NULL
UNION ALL
SELECT "Country Name" as country_name, "Country Code" as country_code, 2001 as year, "2001" as gdp FROM raw_gdp WHERE "2001" IS NOT NULL
UNION ALL
SELECT "Country Name" as country_name, "Country Code" as country_code, 2002 as year, "2002" as gdp FROM raw_gdp WHERE "2002" IS NOT NULL
UNION ALL
SELECT "Country Name" as country_name, "Country Code" as country_code, 2003 as year, "2003" as gdp FROM raw_gdp WHERE "2003" IS NOT NULL
UNION ALL
SELECT "Country Name" as country_name, "Country Code" as country_code, 2004 as year, "2004" as gdp FROM raw_gdp WHERE "2004" IS NOT NULL
UNION ALL
SELECT "Country Name" as country_name, "Country Code" as country_code, 2005 as year, "2005" as gdp FROM raw_gdp WHERE "2005" IS NOT NULL
UNION ALL
SELECT "Country Name" as country_name, "Country Code" as country_code, 2006 as year, "2006" as gdp FROM raw_gdp WHERE "2006" IS NOT NULL
UNION ALL
SELECT "Country Name" as country_name, "Country Code" as country_code, 2007 as year, "2007" as gdp FROM raw_gdp WHERE "2007" IS NOT NULL
UNION ALL
SELECT "Country Name" as country_name, "Country Code" as country_code, 2008 as year, "2008" as gdp FROM raw_gdp WHERE "2008" IS NOT NULL
UNION ALL
SELECT "Country Name" as country_name, "Country Code" as country_code, 2009 as year, "2009" as gdp FROM raw_gdp WHERE "2009" IS NOT NULL
UNION ALL
SELECT "Country Name" as country_name, "Country Code" as country_code, 2010 as year, "2010" as gdp FROM raw_gdp WHERE "2010" IS NOT NULL
UNION ALL
SELECT "Country Name" as country_name, "Country Code" as country_code, 2011 as year, "2011" as gdp FROM raw_gdp WHERE "2011" IS NOT NULL
UNION ALL
SELECT "Country Name" as country_name, "Country Code" as country_code, 2012 as year, "2012" as gdp FROM raw_gdp WHERE "2012" IS NOT NULL
UNION ALL
SELECT "Country Name" as country_name, "Country Code" as country_code, 2013 as year, "2013" as gdp FROM raw_gdp WHERE "2013" IS NOT NULL
UNION ALL
SELECT "Country Name" as country_name, "Country Code" as country_code, 2014 as year, "2014" as gdp FROM raw_gdp WHERE "2014" IS NOT NULL
UNION ALL
SELECT "Country Name" as country_name, "Country Code" as country_code, 2015 as year, "2015" as gdp FROM raw_gdp WHERE "2015" IS NOT NULL
UNION ALL
SELECT "Country Name" as country_name, "Country Code" as country_code, 2016 as year, "2016" as gdp FROM raw_gdp WHERE "2016" IS NOT NULL
UNION ALL
SELECT "Country Name" as country_name, "Country Code" as country_code, 2017 as year, "2017" as gdp FROM raw_gdp WHERE "2017" IS NOT NULL
)
 
 -- Combine mental health rates with Country, Time, and Disorder dimensions,
-- and add corresponding GDP and health expenditure data by country and year.
 SELECT c.countryID 
					, t.timeID 
					, d.disorderID
					, du.mentalHealth_rate
					, g.gdp 
					, h.healthExp
FROM disorder_unpivot du
JOIN Country c on c.country_code = du.country_code 
JOIN Time t on t.year = du.year 
JOIN Disorder d on d.disorder_name = du.disorder_name
LEFT JOIN gdp_unpivot g on g.country_code = du.country_code AND g.year = du.year
LEFT JOIN health_expenditure_clean h on h.country_code = du.country_code AND h.year = du.year
-- (End): CTE end
;


-- #5 
-- Fact table checking
-- Validation Queries
SELECT Count (*) as total_fact_rows FROM Mental_Health_Fact;

SELECT COUNT (DISTINCT countryID) as total_country
					, COUNT (DISTINCT disorderID) as total_disorder
					, MIN (t.year) as min_year
					, MAX (t.year) as max_year
FROM Mental_Health_Fact m 
LEFT JOIN Time t on m.timeID = t.timeID;

SELECT ROUND (100.0 * SUM (CASE WHEN gdp IS NOT NULL AND healthExp IS NOT NULL THEN 1 ELSE 0 END) / COUNT (*), 1) as pct_rows_all_sources_present
FROM Mental_Health_Fact;

