Otázka 1. Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají?

Použitý SQL dotaz

SELECT 
    code AS industry_code,
    name AS industry_name,
    COUNT(*) FILTER (WHERE rozdil < 0) AS pocet_poklesu,     -- počet meziročních poklesů
    COUNT(*) FILTER (WHERE rozdil >= 0) AS pocet_rustu	-- počet meziročních růstů
FROM (
    SELECT 
        code,
        name,
        metric_value,
        LAG(metric_value) OVER (PARTITION BY code ORDER BY year) AS prev_year_wage,	-- mzda z předchozího roku ve stejném odvětví
        metric_value - LAG(metric_value) OVER (PARTITION BY code ORDER BY year) AS rozdil	-- meziroční rozdíl mezd
    FROM data_academy_content.t_ondrej_svitil_project_sql_primary_final
    WHERE dataset = 'PAYROLL'
) t
GROUP BY code, name
ORDER BY pocet_poklesu DESC;

Závěr: mezi lety 2006–2018 mzdy v ČR spíše rostly, ale ne ve všech odvětvích stejně. Nejvíce poklesů měla Těžba a dobývání (4),
zatímco ve zpracovatelském průmyslu, zdravotnictví, dopravě administrativě a v nezařazených odvětvích mzdy neklesly ani jednou.
_________________________________________________________________________________________________________________________________

Otázka 2. Kolik je možné si koupit litrů mléka a kilogramů chleba za první a poslední srovnatelné období v dostupných 
datech cen a mezd?

Použitý SQL dotaz

SELECT
  year,
  ROUND(
    (AVG(metric_value) FILTER (WHERE dataset = 'PAYROLL'))	-- průměrná mzda v daném roce
    /
    (AVG(metric_value) FILTER (WHERE dataset = 'PRICE' AND name = 'Mléko polotučné pasterované'))	-- průměrná cena mléka
  , 0) AS litru_mleka,							
  ROUND(
    (AVG(metric_value) FILTER (WHERE dataset = 'PAYROLL'))	-- průměrná mzda v daném roce
    /
    (AVG(metric_value) FILTER (WHERE dataset = 'PRICE' AND name = 'Chléb konzumní kmínový'))	-- průměrná cena chleba
  , 0) AS kg_chleba
FROM data_academy_content.t_ondrej_svitil_project_sql_primary_final
WHERE year IN (2006, 2018)
GROUP BY year;

Závěr: V roce 2006 průměrná mzda stačila na 1 409 litrů mléka nebo 1 262 kg chleba.
V roce 2018 to bylo cca 1 614 litrů mléka nebo 1 319 kg chleba.
Kupní síla vzrostla: mzdy rostly rychleji než ceny uvedených potravin.
_________________________________________________________________________________________________________________________________

Otázka 3 – Která kategorie potravin zdražuje nejpomaleji?

Použitý SQL dotaz

SELECT
    code,
    name,
    ROUND(AVG((cena - predchozi_cena) / predchozi_cena * 100), 2) AS zmena_cen	--průměrný meziroční růst cen v procentech
FROM (
    SELECT
        code,
        name,
        year,
        metric_value AS cena,	-- aktuální cena v daném roce
        LAG(metric_value) OVER (PARTITION BY code ORDER BY year) AS predchozi_cena	-- cena stejného produktu z předchozího roku
    FROM data_academy_content.t_ondrej_svitil_project_sql_primary_final
    WHERE dataset = 'PRICE'
) t
WHERE predchozi_cena IS NOT NULL
GROUP BY code, name
ORDER BY zmena_cen ASC	-- produkty podle průměrného růstu
LIMIT 10;

Závěr: ceny cukru krystalového (-1,9 % ročně) a rajčat (-0,7 %) zaznamenaly mírný pokles, pomalu zdražovaly banány (+0,8 %), vepřové maso (0,99 %) 
nebo minerální voda (+1,0 %). Maso a pečivo měly vyšší růst (okolo 2–2,6 % ročně). Ne všechny potraviny zdražují – u některých cena v průměru mírně klesala.
_________________________________________________________________________________________________________________________________

Otázka 4 – Existuje rok, ve kterém byl meziroční nárůst cen potravin výrazně vyšší než růst mezd (o více než 10 %)?

Použitý SQL dotaz

SELECT
  w.year,
  ROUND((w.avg - w.prev)/w.prev*100, 2) AS rust_mezd,	-- meziroční růst průměrné mzdy v procentech
  ROUND((p.avg - p.prev)/p.prev*100, 2) AS rust_cen,  -- meziroční růst průměrné ceny v procentech
  ROUND(((p.avg - p.prev)/p.prev - (w.avg - w.prev)/w.prev)*100, 2) AS rozdil	-- rozdíl, růst cen mínus růst mezd
FROM
  (SELECT t1.*, LAG(t1.avg) OVER (ORDER BY year) AS prev
   FROM (
     SELECT year, AVG(metric_value) AS avg	 -- průměrná mzda v daném roce
     FROM data_academy_content.t_ondrej_svitil_project_sql_primary_final
     WHERE dataset='PAYROLL'
     GROUP BY year
   ) t1
  ) w
JOIN
  (SELECT t2.*, LAG(t2.avg) OVER (ORDER BY year) AS prev
   FROM (
     SELECT year, AVG(metric_value) AS avg	-- průměrná cena v daném roce
     FROM data_academy_content.t_ondrej_svitil_project_sql_primary_final
     WHERE dataset='PRICE'
     GROUP BY year
   ) t2
  ) p
USING (year)
WHERE w.prev IS NOT NULL AND p.prev IS NOT NULL
ORDER BY w.year;

Závěr: V žádném roce rozdíl nepřekročil hranici 10 %.
Nejblíže byl rok 2009, kdy ceny potravin výrazně klesly (-6,4 %), zatímco mzdy mírně rostly (+3,3 %). 
_________________________________________________________________________________________________________________________________

Otázka 5. Má výška HDP vliv na změny ve mzdách a cenách potravin? Neboli, pokud HDP vzroste výrazněji v jednom roce, projeví se to na cenách potravin či mzdách ve stejném nebo následujícím roce výraznějším růstem?

Použitý SQL dotaz

SELECT
  hdp.rok,   -- rok
  ROUND((hdp.hdp - hdp.predchozi_hdp) / hdp.predchozi_hdp * 100.0)       AS rust_hdp_procenta,  -- růst HDP v %
  ROUND((mzdy.prumerna_mzda - mzdy.predchozi_mzda) / mzdy.predchozi_mzda * 100.0) AS rust_mezd_procenta, -- růst mezd v %
  ROUND((ceny.prumerna_cena - ceny.predchozi_cena) / ceny.predchozi_cena * 100.0) AS rust_cen_procenta  -- růst cen v %
FROM
  (
    -- HDP a předchozí hodnota
    SELECT
      year AS rok,
      gdp  AS hdp,
      LAG(gdp) OVER (ORDER BY year) AS predchozi_hdp
    FROM data_academy_content.t_ondrej_svitil_project_sql_secondary_final
    WHERE country_name = 'Czech Republic'
  ) hdp
JOIN
  (
    -- průměrná mzda a předchozí hodnota
    SELECT
      rok,
      prumerna_mzda,
      LAG(prumerna_mzda) OVER (ORDER BY rok) AS predchozi_mzda
    FROM (
      SELECT year AS rok, AVG(metric_value) AS prumerna_mzda
      FROM data_academy_content.t_ondrej_svitil_project_sql_primary_final
      WHERE dataset = 'PAYROLL'
      GROUP BY year
    ) a
  ) mzdy
USING (rok)
JOIN
  (
    -- průměrná cena a předchozí hodnota
    SELECT
      rok,
      prumerna_cena,
      LAG(prumerna_cena) OVER (ORDER BY rok) AS predchozi_cena
    FROM (
      SELECT year AS rok, AVG(metric_value) AS prumerna_cena
      FROM data_academy_content.t_ondrej_svitil_project_sql_primary_final
      WHERE dataset = 'PRICE'
      GROUP BY year
    ) b
  ) ceny
USING (rok)
WHERE hdp.predchozi_hdp IS NOT NULL   -- vynechám první rok (nemá předchozí hodnotu)
  AND mzdy.predchozi_mzda IS NOT NULL
  AND ceny.predchozi_cena IS NOT NULL
ORDER BY hdp.rok;

Závěr: Od roku 2006 do 2018 je vidět, že když roste HDP, rostou i mzdy – a to jak ve stejném roce, tak i s menším zpožděním.
Naopak u cen potravin to tak jasné není, ty se hýbou různě a na HDP tolik nereagují

## Poznámky k datům
- V datasetu `economies` chybí pro některé evropské státy údaje o GINI koeficientu (zobrazuje se `NULL`).
- Společné roky pro mzdy a ceny potravin byly dostupné pouze v období 2006–2018.
- V některých letech vykazují ceny potravin záporný růst (deflace), což se projevilo v interpretaci.
