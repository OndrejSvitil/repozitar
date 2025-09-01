-- Vytvoření finálních tabulek – Ondřej Svitil
-- Předpokládá existenci:
--   data_academy_content.v_payroll_year_industry
--   data_academy_content.v_price_year_category
--   data_academy_content.v_common_years

DROP TABLE IF EXISTS data_academy_content.t_ondrej_svitil_project_sql_primary_final;

CREATE TABLE data_academy_content.t_ondrej_svitil_project_sql_primary_final (
    dataset      VARCHAR(20),   -- 'PAYROLL' / 'PRICE'
    year         INT,
    code         VARCHAR(20),   -- odvětví nebo kategorie
    name         VARCHAR(255),  -- název odvětví / potraviny
    metric_value NUMERIC(18,2), -- mzda nebo cena v Kč
    PRIMARY KEY (dataset, year, code)
);

-- MZDY
INSERT INTO data_academy_content.t_ondrej_svitil_project_sql_primary_final (dataset, year, code, name, metric_value)
SELECT
  'PAYROLL' AS dataset,
  p.year,
  p.industry_branch_code AS code,
  p.industry_branch_name AS name,
  p.avg_wage_year AS metric_value
FROM data_academy_content.v_payroll_year_industry p
JOIN data_academy_content.v_common_years y USING (year);

-- CENY
INSERT INTO data_academy_content.t_ondrej_svitil_project_sql_primary_final (dataset, year, code, name, metric_value)
SELECT
  'PRICE' AS dataset,
  pr.year,
  pr.category_code AS code,
  pr.category_name AS name,
  pr.avg_price_year AS metric_value
FROM data_academy_content.v_price_year_category pr
JOIN data_academy_content.v_common_years y USING (year);

-- Sekundární tabulka (Evropa)
DROP TABLE IF EXISTS data_academy_content.t_ondrej_svitil_project_sql_secondary_final;

CREATE TABLE data_academy_content.t_ondrej_svitil_project_sql_secondary_final AS
SELECT
  e.country AS country_name,
  e.year,
  e.gdp,
  e.gini,
  e.population
FROM economies e
JOIN countries c
  ON e.country = c.country
WHERE c.continent = 'Europe'
  AND e.year IN (SELECT year FROM data_academy_content.v_common_years)
ORDER BY e.country, e.year;
