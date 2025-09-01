-- Pomocné pohledy

-- 1) Roční průměr mezd podle odvětví
CREATE OR REPLACE VIEW data_academy_content.v_payroll_year_industry AS
SELECT
  x.year,
  x.industry_branch_code,
  ib.name AS industry_branch_name,
  ROUND(x.avg_wage_year::numeric, 2) AS avg_wage_year
FROM
(
  SELECT
    cp.payroll_year AS year,
    cp.industry_branch_code,
    AVG(cp.value) AS avg_wage_year
  FROM czechia_payroll cp
  WHERE cp.value_type_code = 5958  -- průměrná hrubá mzda na zaměstnance
    AND cp.calculation_code = 100  -- fyzické osoby
    AND cp.unit_code = 200         -- Kč
  GROUP BY cp.payroll_year, cp.industry_branch_code
) x
JOIN czechia_payroll_industry_branch ib
  ON ib.code = x.industry_branch_code;

-- 2) Roční průměrné ceny potravin podle kategorií
CREATE OR REPLACE VIEW data_academy_content.v_price_year_category AS
SELECT
  y.year,
  y.category_code,
  pc.name AS category_name,
  ROUND(y.avg_price_year::numeric, 2) AS avg_price_year
FROM
(
  SELECT
    EXTRACT(YEAR FROM p.date_from)::int AS year,
    p.category_code,
    AVG(p.value) AS avg_price_year
  FROM czechia_price p
  GROUP BY EXTRACT(YEAR FROM p.date_from), p.category_code
) y
JOIN czechia_price_category pc
  ON pc.code = y.category_code;

-- 3) Společné roky (průnik)
CREATE OR REPLACE VIEW data_academy_content.v_common_years AS
SELECT a.year
FROM (SELECT DISTINCT year FROM data_academy_content.v_payroll_year_industry) a
JOIN (SELECT DISTINCT year FROM data_academy_content.v_price_year_category) b
  ON a.year = b.year;
