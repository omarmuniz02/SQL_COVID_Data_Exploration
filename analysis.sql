/* 
   COVID DATA EXPLORATION (PostgreSQL)
   Notes:
   - My raw tables were imported with many columns as TEXT.
   - My dataset’s "total_deaths" behaves like DAILY deaths.
   - Dates are stored as text like '2/24/20'.
   */


-- Cleaned deaths view: casts text to numeric and parses date
DROP VIEW IF EXISTS covid_deaths_clean;

CREATE VIEW covid_deaths_clean AS
SELECT
    NULLIF(continent, '') AS continent,
    NULLIF(location, '') AS location,
    TO_DATE(date, 'MM/DD/YY') AS date,
    NULLIF(population, '')::double precision AS population,
    NULLIF(total_cases, '')::double precision AS total_cases,
    NULLIF(new_cases, '')::double precision AS new_cases,
    total_deaths::double precision AS total_deaths
FROM
    covid_deaths;


-- Cleaned vaccines view: casts text to numeric and parses date
DROP VIEW IF EXISTS covid_vaccines_clean;

CREATE VIEW covid_vaccines_clean AS
SELECT
    NULLIF(location, '') AS location,
    TO_DATE(date, 'MM/DD/YY') AS date,
    NULLIF(new_vaccinations, '')::double precision AS new_vaccinations
FROM
    covid_vaccines;


-- Quick validation:
SELECT
    COUNT(*) AS joined_rows
FROM
    covid_deaths_clean AS dea
JOIN
    covid_vaccines_clean AS vac
        ON dea.location = vac.location
        AND dea.date = vac.date;


-- 2) BASELINE CHECK

SELECT
    location,
    date,
    total_cases,
    new_cases,
    total_deaths,
    population
FROM
    covid_deaths_clean
ORDER BY
    1, 2;


-- 3) TOTAL CASES VS TOTAL DEATHS (Death rate)

-- Looking at total cases vs total deaths (US)

SELECT
    location,
    date,
    total_cases,
    total_deaths,
    (total_deaths
        / NULLIF(total_cases, 0)
    ) * 100.0 AS death_rate_pct
FROM
    covid_deaths_clean
WHERE
    location = 'United States'
ORDER BY
    location, date;


-- 4) TOTAL CASES VS POPULATION (Infection rate)

SELECT
    location,
    date,
    total_cases,
    population,
    (total_cases
        / NULLIF(population, 0)
    ) * 100.0 AS infection_rate_pct
FROM
    covid_deaths_clean
WHERE
    location = 'United States'
ORDER BY
    1, 2;


-- 5) HIGHEST INFECTION RATE BY COUNTRY

-- Looking at countries with the highest infection rates compared to their population
-- Using MAX(total_cases) assumes total_cases behaves like a cumulative measure.

SELECT
    location,
    MAX(total_cases) AS highest_total_cases,
    (MAX(total_cases)
        / NULLIF(MAX(population), 0)
    ) * 100.0 AS percentage_infected
FROM
    covid_deaths_clean
WHERE
    continent IS NOT NULL
    AND continent <> ''
GROUP BY
    location
ORDER BY
    percentage_infected DESC;


-- Alternative: sum daily cases instead

 SELECT
     location,
     SUM(total_cases) AS total_cases_sum,
     (SUM(total_cases)
        / NULLIF(MAX(population), 0)
     ) * 100.0 AS percentage_infected
FROM
    covid_deaths_clean
WHERE
     continent IS NOT NULL
     AND continent <> ''
 GROUP BY
     location
 ORDER BY
     percentage_infected DESC;


-- 6) HIGHEST DEATH COUNTS (Country + Continent)

-- Showing countries with the highest deaths
-- IMPORTANT: total_deaths behaves like DAILY deaths. We sum to get total death count.
SELECT
    location,
    SUM(total_deaths) AS total_death_count
FROM
    covid_deaths_clean
WHERE
    continent IS NOT NULL
    AND continent <> ''
GROUP BY
    location
ORDER BY
    total_death_count DESC;


-- Breakdown by continent

SELECT
    continent,
    SUM(total_deaths) AS total_death_count
FROM
    covid_deaths_clean
WHERE
    continent IS NOT NULL
    AND continent <> ''
GROUP BY
    continent
ORDER BY
    total_death_count DESC;


-- 7) GLOBAL NUMBERS (Daily death rate)
-- Global numbers by date
-- total_deaths is treated as daily deaths here.

SELECT
    date,
    SUM(total_deaths) AS total_new_deaths,
    (SUM(total_deaths)
        / NULLIF(SUM(new_cases), 0)
    ) * 100.0 AS death_rate_pct
FROM
    covid_deaths_clean
WHERE
    continent IS NOT NULL
    AND continent <> ''
GROUP BY
    date
ORDER BY
    date;


-- 8) POPULATION VS VACCINATIONS (Join + running total)

SELECT
    dea.continent,
    dea.location,
    dea.date,
    dea.population,
    vac.new_vaccinations,
    SUM(vac.new_vaccinations)
        OVER (PARTITION BY dea.location ORDER BY dea.date) AS cumulative_vaccinations
FROM
    covid_deaths_clean AS dea
JOIN
    covid_vaccines_clean AS vac
        ON dea.location = vac.location
        AND dea.date = vac.date
WHERE
    dea.continent IS NOT NULL
    AND dea.continent <> ''
ORDER BY
    2, 3;


-- 9) FINAL REPORTING VIEW (for visualization)
-- Creating view to store data for visualization

DROP VIEW IF EXISTS percentpopulation_vaccinated;

CREATE VIEW percentpopulation_vaccinated AS
WITH vax AS (
    SELECT
        dea.continent,
        dea.location,
        dea.date,
        MAX(dea.population) OVER (PARTITION BY dea.location) AS population,
        vac.new_vaccinations,
        SUM(vac.new_vaccinations)
            OVER (PARTITION BY dea.location ORDER BY dea.date) AS cumulative_vaccinations
    FROM
        covid_deaths_clean AS dea
    JOIN
        covid_vaccines_clean AS vac
            ON dea.location = vac.location
            AND dea.date = vac.date
    WHERE
        dea.continent IS NOT NULL
        AND dea.continent <> ''
)
SELECT
    continent,
    location,
    date,
    population,
    new_vaccinations,
    cumulative_vaccinations,
    (cumulative_vaccinations / NULLIF(population, 0)) * 100.0 AS vaccination_rate_pct
FROM
    vax;


-- Quick check: sample output for one country
SELECT
    *
FROM
    percentpopulation_vaccinated
WHERE
    location = 'United States'
ORDER BY
    date;
---------------------------------------
SELECT
    table_schema,
    table_name
FROM
    information_schema.views
WHERE
    table_name = 'percentpopulation_vaccinated';