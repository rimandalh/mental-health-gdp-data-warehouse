# Global Patterns in Mental Health Prevalence: Comparing GDP, Health Expenditure and Regional Differences, 2000–2017

A SQLite data warehouse and analytical SQL project examining whether national wealth and healthcare spending correspond with differences in reported mental health outcomes across countries, regions, and time.

**Course:** BUSINFO 702 — Information Management, Master of Business Analytics, University of Auckland Business School
**Team:** Group 7 — Rimanda Hidayat, Yingxin Zhao, Nien-Yi Lin, Rurry Elsa Lorenza Nasution

---

## Overview

Mental health outcomes are shaped by a country's economic conditions, healthcare investment, and social context — but relevant information is usually scattered across separate, incompatible datasets. This project builds an integrated data warehouse that brings together **mental health disorder prevalence**, **GDP per capita**, and **health expenditure per capita** into a single, query-ready star schema, then uses SQL to explore three questions about how these measures relate to each other across 194 countries and 2000–2017.

The full ELT pipeline, schema design, and all analytical SQL are implemented **entirely in SQLite** — no external ETL tool or scripting language was used to transform the data.

## Research Questions

1. **What is happening across the globe?** How does health spending share (health expenditure per capita relative to GDP per capita) compare with average mental health disorder occurrence across regions, and how have both measures changed across the 3-year periods spanning 2000–2017?
2. **What is the relationship?** How has the relationship between GDP per capita and mental health disorder rates changed across the 2000–2017 period, and does this pattern differ by region?
3. **Who stands out?** Among countries with similar levels of health expenditure per capita, which countries show disorder-specific prevalence trends that deviate most from their spending peers across the six 3-year periods from 2000 to 2017?

## Data Sources

| Dataset | Source | Format |
|---|---|---|
| Mental health disorder prevalence (7 disorder types) | [Kaggle / Our World in Data](https://www.kaggle.com/datasets/thedevastator/uncover-global-trends-in-mental-health-disorder) | CSV |
| GDP per capita | [World Bank Open Data](https://data.worldbank.org/indicator/NY.GDP.PCAP.CD) | XLSX |
| Country metadata (region, income group) | World Bank Open Data (same workbook, Metadata sheet) | XLSX |
| Current health expenditure per capita | [WHO Global Health Observatory](https://www.who.int/data/gho/data/indicators/indicator-details/GHO/current-health-expenditure-(che)-per-capita-in-us-dollar) | CSV |

All four sources were extracted as flat files (no API access required) and imported into SQLite as unmodified staging tables — cleaning and integration happen entirely in the Transform stage, consistent with an **ELT** (not ETL) architecture.

## Star Schema

A single fact table sits at the center, surrounded by three dimension tables describing the *who*, *when*, and *what kind* of each fact row.

**Grain:** one row = one **Country × Year × Disorder** combination.

```mermaid
erDiagram
    Country ||--o{ Mental_Health_Fact : has
    Time ||--o{ Mental_Health_Fact : has
    Disorder ||--o{ Mental_Health_Fact : has

    Country {
        int countryID PK
        text country_code
        text country_name
        text region
        text income_group
    }
    Time {
        int timeID PK
        int year
        text period
    }
    Disorder {
        int disorderID PK
        text disorder_name
    }
    Mental_Health_Fact {
        int countryID PK_FK
        int timeID PK_FK
        int disorderID PK_FK
        real mentalHealth_rate
        real gdp
        real healthExp
    }
```

**Attribute hierarchies:**
- **Time:** year → 3-year period (2000-02 through 2015-17)
- **Country:** country → region, with income group as a supporting classification

Because GDP and health expenditure are reported at the country-year level while mental health prevalence is at the country-year-disorder level, GDP and health expenditure values are deliberately repeated across each country-year's seven disorder rows — this keeps Disorder queryable as a genuine dimension rather than flattening it into seven separate measure columns.

## ELT Implementation

Full pipeline: [`sql/01_star_schema_and_elt.sql`](sql/01_star_schema_and_elt.sql)

- **Extract:** all four files downloaded directly from their public providers, no transformation applied
- **Load:** imported into SQLite via DB Browser for SQLite's Import CSV wizard as raw staging tables (`raw_mental_health`, `raw_gdp`, `raw_metadata_gdp`, `raw_health_expenditure`), then verified with row-count, missing-value, and cross-source coverage checks before any cleaning began
- **Transform:** star schema built and populated entirely in SQL —
  - A recursive CTE generates the Time dimension's year sequence and buckets it into 3-year periods
  - The Country dimension is filtered from World Bank metadata, excluding aggregate/regional rows via a non-null `Region` check
  - The raw mental health file was found to concatenate **four different data blocks** under the same seven column headers (only one is genuine prevalence data); isolating it required filtering to rows where all seven disorder columns are simultaneously non-null
  - Both the disorder and GDP data are unpivoted from wide to long format using `UNION ALL`, since SQLite has no native `UNPIVOT` operator
  - The fact table is populated by a single `INSERT` built on four CTEs, joining all three sources on country code and year

**Result:** 24,444 fact rows across 194 countries, all 7 disorders, 2000–2017, with 93.5% of rows carrying complete GDP and health-expenditure values.

## SQL for Business Analytics

Full scripts: [`sql/02_research_questions.sql`](sql/02_research_questions.sql)

| RQ | Technique | Headline Finding |
|---|---|---|
| 1 | Aggregation by region and 3-year period, health spending share calculated as `healthExp / gdp × 100` | Health spending share rose in most regions (North America: 10.88% → 13.58%), while average disorder prevalence stayed largely flat everywhere |
| 2 | Pearson correlation coefficient computed per region per period using raw SQL aggregates (no built-in stats function) | The GDP–prevalence relationship varies sharply by region — strongly positive in Europe & Central Asia (~0.63), strongly negative in South Asia (~-0.7), near zero in Sub-Saharan Africa |
| 3 | `NTILE(4)` spending-quartile peer grouping + window-function z-scores per disorder per period | Ten country-disorder pairs showed persistent deviation (\|z\| ≥ 2 in all 6 periods) from their spending peers — e.g., Afghanistan's drug use disorder prevalence averaged 5.75 standard deviations above peers |

## Key Insights

- Higher GDP or total health expenditure does **not** consistently correspond with lower reported mental health prevalence — spending alone is an incomplete benchmark
- The GDP–mental health relationship is strongly **region-dependent**, not a single global pattern
- Countries with comparable health spending can still show large, persistent, disorder-specific differences — useful as a screening signal for where to investigate further, not as a performance ranking

## Limitations

- Health expenditure per capita measures **total** health-system investment, not mental-health-specific spending (WHO Mental Health Atlas 2020 reports mental health receives a global median of only 2.1% of government health budgets)
- Regional averages are unweighted across countries, so a small country counts equally to a large one
- Findings are descriptive and correlational — the warehouse identifies patterns, not causal effects

## Future Work

- Incorporate mental-health-specific expenditure and psychiatric workforce/service-capacity indicators
- Add contextual variables (unemployment, income inequality, education) to help explain regional and country-level variation
- Move from bivariate comparisons to multivariable and longitudinal (panel-data) methods
- Use purchasing-power-parity-adjusted GDP and population-weighted regional estimates

## Repository Structure

```
├── sql/
│   ├── 01_star_schema_and_elt.sql       # Schema DDL + full Extract/Load/Transform pipeline
│   └── 02_research_questions.sql        # Analytical SQL for RQ1–RQ3
├── database/
│   └── mental_health_data_warehouse.db  # Final populated SQLite database
├── docs/
│   └── Final_Report.pdf                 # Full written report (motivation, results, figures, references)
└── README.md
```

## How to Reproduce

1. Clone this repo and open `database/mental_health_data_warehouse.db` directly in [DB Browser for SQLite](https://sqlitebrowser.org/) to explore the finished warehouse, **or**
2. Run `sql/01_star_schema_and_elt.sql` against your own staging tables (built from the raw source files linked above) to rebuild the warehouse from scratch, then run `sql/02_research_questions.sql` against the result to reproduce the analysis

## References

- Patel, V., Saxena, S., Lund, C., et al. (2018). The Lancet Commission on global mental health and sustainable development. *The Lancet, 392*(10157), 1553–1598. https://doi.org/10.1016/S0140-6736(18)31612-X
- World Health Organization. (2021). *Mental Health Atlas 2020*. https://www.who.int/publications/i/item/9789240036703
- World Health Organization. (n.d.). *Current health expenditure (CHE) per capita in US$* [Data set]. Global Health Observatory.
- World Bank. (n.d.). *GDP per capita (current US$)* [Data set]. World Bank Open Data.
- The Devastator. (n.d.). *Global trends in mental health disorder* [Data set]. Kaggle.

---

*This project was completed as a group assignment for BUSINFO 702 at the University of Auckland Business School.*
