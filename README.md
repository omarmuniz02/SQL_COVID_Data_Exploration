## SQL Analysis Highlights

### Cleaned Vaccines View

```sql
CREATE VIEW covid_vaccines_clean AS
SELECT
    NULLIF(location, '') AS location,
    TO_DATE(date, 'MM/DD/YY') AS date,
    NULLIF(new_vaccinations, '')::double precision AS new_vaccinations
FROM covid_vaccines;
```

This view standardizes vaccine data by parsing date fields and converting numeric values stored as text into usable numeric types.

---

### Highest Infection Rate by Country

```sql
SELECT
    location,
    MAX(total_cases) AS highest_total_cases,
    (MAX(total_cases) / NULLIF(MAX(population), 0)) * 100.0 AS percentage_infected
FROM covid_deaths_clean
WHERE continent IS NOT NULL AND continent <> ''
GROUP BY location
ORDER BY percentage_infected DESC;
```

This query identifies countries with the highest infection rate relative to population.

---

### Global Daily Death Rate

```sql
SELECT
    date,
    SUM(total_deaths) AS total_new_deaths,
    (SUM(total_deaths) / NULLIF(SUM(new_cases), 0)) * 100.0 AS death_rate_pct
FROM covid_deaths_clean
WHERE continent IS NOT NULL AND continent <> ''
GROUP BY date
ORDER BY date;
```

This query calculates global daily death rate by comparing summed daily deaths to summed new cases.

---

### Reporting View: Vaccination Rate (Join + Window Function)

```sql
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
    FROM covid_deaths_clean AS dea
    JOIN covid_vaccines_clean AS vac
        ON dea.location = vac.location
        AND dea.date = vac.date
    WHERE dea.continent IS NOT NULL AND dea.continent <> ''
)
SELECT
    continent,
    location,
    date,
    population,
    new_vaccinations,
    cumulative_vaccinations,
    (cumulative_vaccinations / NULLIF(population, 0)) * 100.0 AS vaccination_rate_pct
FROM vax;
```

This reporting view joins deaths and vaccination data, calculates a running cumulative vaccination total using a window function, and derives vaccination rate as a percentage of population.

## Notes
- Many source columns were imported as text and converted via cleaned views.
- In this dataset, `total_deaths` behaved like a daily measure, so totals were calculated using `SUM()` where appropriate.
- The final reporting view was created to support future visualization in tools like Tableau or Power BI.
