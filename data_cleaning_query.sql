-- =========================================================
-- DATA CLEANING PROJECT: WORLD LAYOFFS
-- Purpose: Prepare the layoffs dataset for analysis by
--          removing duplicates, fixing missing values,
--          standardizing text, and formatting dates.
-- =========================================================

-- Set the database
USE world_layoffs;

-- =========================================================
-- STEP 1: Create a raw copy of the dataset
-- =========================================================
CREATE TABLE layoffs_raw
LIKE layoffs;

INSERT INTO layoffs_raw
SELECT *
FROM layoffs;

-- Optional check: identify duplicates (preview only)
SELECT *,
ROW_NUMBER() OVER(
    PARTITION BY company, location, industry, total_laid_off,
    percentage_laid_off, `date`, stage, country, funds_raised_millions
) AS row_num
FROM layoffs_raw;

-- =========================================================
-- STEP 2: Create staging table with row number for duplicates removal
-- =========================================================
CREATE TABLE layoffs_raw2 (
  company TEXT,
  location TEXT,
  industry TEXT,
  total_laid_off INT DEFAULT NULL,
  percentage_laid_off TEXT,
  `date` TEXT,
  stage TEXT,
  country TEXT,
  funds_raised_millions INT DEFAULT NULL,
  row_num INT
);

-- Force date column to TEXT temporarily to avoid type errors
ALTER TABLE layoffs_raw2
MODIFY COLUMN `date` TEXT;

-- Insert data and generate row numbers for duplicates
INSERT INTO layoffs_raw2
SELECT *,
ROW_NUMBER() OVER(
    PARTITION BY company, location, industry, total_laid_off,
    percentage_laid_off, `date`, stage, country, funds_raised_millions
) AS row_num
FROM layoffs_raw;

-- =========================================================
-- STEP 3: Remove duplicates
-- =========================================================
SET SQL_SAFE_UPDATES = 0;

DELETE
FROM layoffs_raw2
WHERE row_num > 1;

-- =========================================================
-- STEP 4: Standardize text fields
-- =========================================================

-- Clean company names: remove leading/trailing spaces
UPDATE layoffs_raw2
SET company = TRIM(company);

-- Standardize industry names
UPDATE layoffs_raw2
SET industry = 'crypto'
WHERE industry LIKE 'crypto%';

-- Clean country names: remove trailing dots
UPDATE layoffs_raw2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

-- =========================================================
-- STEP 5: Convert date text to DATE type
-- =========================================================
UPDATE layoffs_raw2
SET `date` = STR_TO_DATE(TRIM(`date`), '%m/%d/%Y')
WHERE `date` LIKE '%/%/%';

ALTER TABLE layoffs_raw2
MODIFY COLUMN `date` DATE;

-- =========================================================
-- STEP 6: Handle missing or blank industries
-- =========================================================

-- Convert empty strings to NULL
UPDATE layoffs_raw2
SET industry = NULL
WHERE industry = '';

-- Fill missing industries using self-join on company
UPDATE layoffs_raw2 t1
JOIN layoffs_raw2 t2
  ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;

-- Final check for missing industries
SELECT *
FROM layoffs_raw2
WHERE industry IS NULL
   OR industry = '';


-- STEP 7: Remove rows missing both total laid off and percentage

SELECT * 
FROM layoffs_raw2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

DELETE
FROM layoffs_raw2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

-- =========================================================
-- STEP 8: Preview specific companies and industry fill (optional checks)
-- =========================================================

-- Example: check Airbnb rows
SELECT * 
FROM layoffs_raw2
WHERE company = 'Airbnb';

-- Example: check industry fill join
SELECT t1.industry AS missing_industry, t2.industry AS filled_industry
FROM layoffs_raw2 t1
JOIN layoffs_raw2 t2
  ON t1.company = t2.company
WHERE (t1.industry IS NULL OR t1.industry = '')
AND t2.industry IS NOT NULL;
