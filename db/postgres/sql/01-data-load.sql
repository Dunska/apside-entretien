/* horror-movies-database Copyright (C) 2017 Jeremiah Peschka

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.

 */

CREATE OR REPLACE FUNCTION isnumeric(text) RETURNS boolean AS '
SELECT $1 ~ ''^[0-9]+$''
' LANGUAGE 'sql';


CREATE UNLOGGED TABLE IF NOT EXISTS imdb_staging (
       id SERIAL PRIMARY KEY ,
       title varchar,
       genres varchar,
       release_date varchar,
       release_country varchar,
       movie_rating varchar,
       review_rating varchar,
       movie_run_time varchar,
       plot varchar,
       movie_cast varchar,
       movie_language varchar,
       filming_locations varchar,
       budget varchar
);


CREATE TABLE IF NOT EXISTS movies (
  id INT PRIMARY KEY,
  title VARCHAR(203),
  release_year INT,
  rating_id INT,
  country_id INT,
  review NUMERIC(3,1),
  runtime INT,
  budget NUMERIC(28,2),
  plot VARCHAR(600)
);

CREATE TABLE IF NOT EXISTS locations (
  id SERIAL PRIMARY KEY,
  location_name VARCHAR,
  country_name VARCHAR,
  CONSTRAINT uq_location UNIQUE (location_name, country_name)
);

CREATE TABLE IF NOT EXISTS genres (
  id SERIAL PRIMARY KEY,
  genre_name VARCHAR,
  CONSTRAINT uq_genre UNIQUE (genre_name)
);

CREATE TABLE IF NOT EXISTS countries (
  id SERIAL PRIMARY KEY,
  country_name VARCHAR,
  CONSTRAINT uq_country UNIQUE (country_name)
);

CREATE TABLE IF NOT EXISTS actors (
  id SERIAL PRIMARY KEY,
  actor_name VARCHAR,
  CONSTRAINT uq_actor UNIQUE (actor_name)
);

CREATE TABLE IF NOT EXISTS ratings (
  id SERIAL PRIMARY KEY,
  rating VARCHAR(10),
  CONSTRAINT uq_rating UNIQUE (rating)
);

ALTER TABLE movies
    ADD CONSTRAINT fk_movies_ratings FOREIGN KEY (rating_id) REFERENCES ratings(id);

ALTER TABLE movies
    ADD CONSTRAINT fk_movies_countries FOREIGN KEY (country_id) REFERENCES countries(id);

CREATE TABLE IF NOT EXISTS movie_locations (
  movie_id INT NOT NULL CONSTRAINT fk_movie_locations_movie REFERENCES movies(id),
  location_id INT NOT NULL CONSTRAINT fk_movie_locations_location REFERENCES locations(id),
  CONSTRAINT pk_movie_locations PRIMARY KEY (movie_id, location_id)
);

CREATE TABLE IF NOT EXISTS movie_cast (
  movie_id INT NOT NULL CONSTRAINT fk_movie_cast_movie REFERENCES movies(id),
  cast_id INT NOT NULL CONSTRAINT fk_movie_cast_actor REFERENCES actors(id),
  CONSTRAINT pk_movie_cast PRIMARY KEY (movie_id, cast_id)
);

CREATE TABLE movie_genres (
  movie_id INT NOT NULL CONSTRAINT fk_movie_genres_movie REFERENCES movies(id),
  genre_id INT NOT NULL CONSTRAINT fk_movie_genres_genre REFERENCES genres(id),
  CONSTRAINT pk_movie_genres PRIMARY KEY (movie_id, genre_id)
);

TRUNCATE imdb_staging;

-- Uncomment this to import the halloween prompt cloud data from the CSV.
-- Otherwise, you can run data-load.sql to get the fuly ETL'd data into the database.
--
-- COPY imdb_staging (title, genres, release_date, release_country, movie_rating, review_rating, movie_run_time, plot, movie_cast, movie_language, filming_locations, budget)
-- FROM 'IMDB-Halloween-PromptCloud.csv'
-- WITH CSV HEADER;



-- Add a date column
ALTER TABLE imdb_staging ADD COLUMN IF NOT EXISTS release_year INT NULL;

-- Cast four digit dates to years
UPDATE imdb_staging
SET    release_year = CAST(release_date AS INT)
WHERE  LENGTH(release_date) = 4;

-- Clean up dates:
UPDATE imdb_staging
SET    release_year = date_part('year', CAST(release_date AS DATE))
WHERE  release_date IS NOT NULL
       AND LENGTH(release_date) > 4 ;








INSERT INTO locations (location_name, country_name)
SELECT DISTINCT
        trim(f_array[array_length(f_array, 1) - 1]) AS city,
        trim(f_array[array_length(f_array, 1)]) AS location
FROM (
SELECT DISTINCT filming_locations, regexp_split_to_array(filming_locations, ',') AS f_array
FROM imdb_staging
WHERE filming_locations IS NOT NULL) AS x;


INSERT INTO genres (genre_name)
SELECT DISTINCT regexp_split_to_table(imdb_staging.genres, E'\\|')
FROM imdb_staging
WHERE imdb_staging.genres IS NOT NULL;


INSERT INTO countries (country_name)
SELECT DISTINCT release_country
FROM imdb_staging
WHERE release_country IS NOT NULL
ORDER BY release_country;


INSERT INTO actors (actor_name)
SELECT DISTINCT regexp_split_to_table(imdb_staging.movie_cast, E'\\|')
FROM imdb_staging
WHERE imdb_staging.movie_cast IS NOT NULL ;








INSERT INTO movies (id, title, release_year, review, runtime, plot)
SELECT
  id,
  title,
  COALESCE(release_year,
           CASE WHEN sy_length > 1 THEN CAST(second_year[sy_length] AS INT) ELSE NULL END),
  rating,
  run_time_in_minutes,
  plot
FROM (
    SELECT
      id ,
      TRIM(title) AS title,
      release_year,
      CASE WHEN position('(' IN title) > 0 THEN regexp_split_to_array(replace(title, ')', ''), E'\\(')
                                           ELSE NULL END AS second_year,
      array_length(regexp_split_to_array(replace(title, ')', ''), E'\\('), 1) AS sy_length,
      CAST(review_rating AS NUMERIC(3, 1)) AS rating,
      CAST(regexp_replace(movie_run_time, ' min', '') AS INT) AS run_time_in_minutes,
      plot
    FROM imdb_staging
) AS x;







-- wire up ratings
UPDATE movies m
SET   rating_id = r.id
FROM  imdb_staging AS i
      JOIN ratings AS r ON i.movie_rating = r.rating
WHERE m.id = i.id;



-- wire up cast and movies



WITH mc AS (
  SELECT
    i.id,
    regexp_split_to_table(i.movie_cast, E'\\|') AS cast_member
  FROM imdb_staging AS i
)
INSERT INTO movie_cast
SELECT DISTINCT mc.id, a.id
FROM mc
  JOIN movies AS m ON mc.id = m.id
  JOIN actors AS a ON TRIM(mc.cast_member) = a.actor_name ;



-- wire up films and locations
ALTER TABLE imdb_staging
    ADD location_location VARCHAR;
ALTER TABLE imdb_staging
    ADD location_country VARCHAR;




UPDATE imdb_staging is1
SET location_location = trim(f_array[array_length(f_array, 1) - 1]),
    location_country =trim(f_array[array_length(f_array, 1)])
FROM (SELECT DISTINCT
          id,
          regexp_split_to_array(filming_locations, ',') AS f_array
        FROM imdb_staging
        WHERE filming_locations IS NOT NULL) is2
WHERE is1.id = is2.id ;

INSERT INTO movie_locations
SELECT  i.id, l.id
FROM    imdb_staging AS i
        JOIN locations AS l ON i.location_country = l.country_name
WHERE   i.location_location IS NULL AND l.location_name IS NULL ;

INSERT INTO movie_locations
SELECT  i.id, l.id
FROM    imdb_staging AS i
        JOIN locations AS l ON i.location_location = l.location_name AND i.location_country = l.country_name
WHERE   i.location_location IS NOT NULL AND l.location_name IS NOT NULL;




-- wire up genres
WITH stage AS (
    SELECT DISTINCT
      id,
      regexp_split_to_table(imdb_staging.genres, E'\\|') AS genre
    FROM imdb_staging
    WHERE imdb_staging.genres IS NOT NULL
)
INSERT INTO movie_genres
SELECT s.id AS movie_id, g.id AS genre_id
FROM stage s
JOIN genres g ON s.genre = g.genre_name;



-- Wire up countries
UPDATE  movies
SET     country_id = c.id
FROM    imdb_staging AS i
        JOIN countries AS c ON i.release_country = c.country_name
WHERE   i.release_country IS NOT NULL
        AND movies.id = i.id;



-- prepare the currencies!
ALTER TABLE imdb_staging ADD COLUMN cleaned_currency VARCHAR;
ALTER TABLE imdb_staging ADD COLUMN currency_unit VARCHAR;
ALTER TABLE imdb_staging ADD COLUMN currency_amount NUMERIC(28,2);

UPDATE imdb_staging SET cleaned_currency = TRIM(budget);
-- Remove commas
UPDATE imdb_staging SET cleaned_currency = REGEXP_REPLACE(cleaned_currency, ',', '', 'g');
-- Remove currency symbols
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, '$', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, '€', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, '£', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'AUD', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'BEF', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'BRL', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'CAD', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'CHF', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'CLP', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'CNY', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'COP', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'CZK', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'DEM', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'DKK', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'ESP', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'FIM', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'FRF', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'HKD', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'HUF', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'IDR', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'INR', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'ITL', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'JPY', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'KRW', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'MXN', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'MYR', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'NGN', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'NOK', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'NZD', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'NZK', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'PHP', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'PYG', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'RUR', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'SEK', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'SGD', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'THB', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'TRL', '');
UPDATE imdb_staging SET cleaned_currency = replace(cleaned_currency, 'TWD', '');

-- Trim off the nasty ends
UPDATE imdb_staging SET cleaned_currency = TRIM(cleaned_currency);

-- remove one off currencies that we don't know about
UPDATE imdb_staging
SET cleaned_currency = NULL
WHERE isnumeric(cleaned_currency)= FALSE;

-- I have no idea which magical control character got stuck in this data, but now it's gone.
UPDATE imdb_staging SET cleaned_currency = REPLACE(cleaned_currency, ' ', '');
UPDATE imdb_staging SET cleaned_currency = TRIM(cleaned_currency);

-- now remove empty budgets that have no money or currency symbol
UPDATE imdb_staging SET cleaned_currency = NULL WHERE TRIM(cleaned_currency) = '';


UPDATE imdb_staging
SET    currency_unit = CASE WHEN position('$' IN budget) > 0 THEN 'USD'
                            WHEN position('€' IN budget) > 0 THEN 'EUR'   -- Euro              1 = $1.17
                            WHEN position('£' IN budget) > 0 THEN 'GBP'   -- brit bux          1 = $1.32
                            WHEN position('AUD' IN budget) > 0 THEN 'AUD' -- AUS               1 = $0.76
                            WHEN position('BEF' IN budget) > 0 THEN NULL  -- belgian franc
                            WHEN position('BRL' IN budget) > 0 THEN 'BRL' -- Brazilian Real    1 = $0.31
                            WHEN position('CAD' IN budget) > 0 THEN 'CAD' -- Canada bucks      1 = $0.79
                            WHEN position('CHF' IN budget) > 0 THEN 'CHF' -- swiss franc       1 = $1.01
                            WHEN position('CLP' IN budget) > 0 THEN 'CLP' -- Chilean peso      1 = $0.0016
                            WHEN position('CNY' IN budget) > 0 THEN 'CNY' -- Chinese yuan      1 = $0.15
                            WHEN position('COP' IN budget) > 0 THEN 'COP' -- Columbian peso    1 = $0.000332
                            WHEN position('CZK' IN budget) > 0 THEN 'CZK' -- Czech Koruna      1 = $0.05
                            WHEN position('DEM' IN budget) > 0 THEN NULL  -- Deutsche Marks
                            WHEN position('DKK' IN budget) > 0 THEN 'DKK' -- Danish Krone      1 = $0.16
                            WHEN position('ESP' IN budget) > 0 THEN NULL  -- Spanish Peso
                            WHEN position('FIM' IN budget) > 0 THEN NULL  -- Finnish Markka
                            WHEN position('FRF' IN budget) > 0 THEN NULL  -- French Franc
                            WHEN position('HKD' IN budget) > 0 THEN 'HKD' -- Hong Kong Dollar  1 = $0.13
                            WHEN position('HUF' IN budget) > 0 THEN 'HUF' -- Hungarian Forint  1 = $0.0038
                            WHEN position('IDR' IN budget) > 0 THEN 'IDR' -- Indonesian Rupiah 1 = $0.000074
                            WHEN position('INR' IN budget) > 0 THEN 'INR' -- Indian Rupee      1 = $0.02
                            WHEN position('ITL' IN budget) > 0 THEN NULL  -- Italian Lira
                            WHEN position('JPY' IN budget) > 0 THEN 'JPY' -- Japanese Yen      1 = $0.0089
                            WHEN position('KRW' IN budget) > 0 THEN 'KRW' -- South Korean Won  1 = $0.000913
                            WHEN position('MXN' IN budget) > 0 THEN 'MXN' -- Mexican peso      1 = $0.05
                            WHEN position('MYR' IN budget) > 0 THEN 'MYR' -- Malaysian Ringgit 1 = $0.24
                            WHEN position('NGN' IN budget) > 0 THEN 'NGN' -- Nigerian Naira    1 = $0.0028
                            WHEN position('NOK' IN budget) > 0 THEN 'NOK' -- Norwegian Krone   1 = $0.12
                            WHEN position('NZD' IN budget) > 0 THEN 'NZD' -- New Zealand bux   1 = $0.69
                            WHEN position('PHP' IN budget) > 0 THEN 'PHP' -- Phillipine Peso   1 = $0.02
                            WHEN position('PKR' IN budget) > 0 THEN 'PKR' -- Pakistani Rupee   1 = $0.0095
                            WHEN position('PYG' IN budget) > 0 THEN 'PYG' -- Paraguayan bux    1 = $0.000177
                            WHEN position('RUR' IN budget) > 0 THEN 'RUR' -- Russian Ruble     1 = $0.02
                            WHEN position('SEK' IN budget) > 0 THEN 'SEK' -- Swedish Krona     1 = $0.12
                            WHEN position('SGD' IN budget) > 0 THEN 'SGD' -- Singapore Dollar  1 = $0.74
                            WHEN position('THB' IN budget) > 0 THEN 'THB' -- Thai Bhat         1 = $0.03
                            WHEN position('TRL' IN budget) > 0 THEN 'TRL' -- Turkish Lira      1 = $0.25
                            WHEN position('TWD' IN budget) > 0 THEN 'TWD' -- Taiwan New Dollar 1 = $0.03
                            END;



-- set the currency to the uncoverted amount
UPDATE imdb_staging
SET currency_amount = CAST(cleaned_currency AS DECIMAL(28,2));



-- perform currency conversion into USD
UPDATE imdb_staging
SET currency_amount = CASE WHEN currency_unit = 'USD' THEN currency_amount
                           WHEN currency_unit = 'EUR' THEN currency_amount * 1.17     -- Euro              1 = $1.17
                           WHEN currency_unit = 'GBP' THEN currency_amount * 1.32     -- brit bux          1 = $1.32
                           WHEN currency_unit = 'AUD' THEN currency_amount * 0.76     -- AUS               1 = $0.76
                           WHEN currency_unit = 'BEF' THEN NULL                       -- belgian franc
                           WHEN currency_unit = 'BRL' THEN currency_amount * 0.31     -- Brazilian Real    1 = $0.31
                           WHEN currency_unit = 'CAD' THEN currency_amount * 0.79     -- Canada bucks      1 = $0.79
                           WHEN currency_unit = 'CHF' THEN currency_amount * 1.01     -- swiss franc       1 = $1.01
                           WHEN currency_unit = 'CLP' THEN currency_amount * 0.0016   -- Chilean peso      1 = $0.0016
                           WHEN currency_unit = 'CNY' THEN currency_amount * 0.15     -- Chinese yuan      1 = $0.15
                           WHEN currency_unit = 'COP' THEN currency_amount * 0.000332 -- Columbian peso    1 = $0.000332
                           WHEN currency_unit = 'CZK' THEN currency_amount * 0.05     -- Czech Koruna      1 = $0.05
                           WHEN currency_unit = 'DEM' THEN NULL                       -- Deutsche Marks
                           WHEN currency_unit = 'DKK' THEN currency_amount * 0.16     -- Danish Krone      1 = $0.16
                           WHEN currency_unit = 'ESP' THEN NULL                       -- Spanish Peso
                           WHEN currency_unit = 'FIM' THEN NULL                       -- Finnish Markka
                           WHEN currency_unit = 'FRF' THEN NULL                       -- French Franc
                           WHEN currency_unit = 'HKD' THEN currency_amount * 0.13     -- Hong Kong Dollar  1 = $0.13
                           WHEN currency_unit = 'HUF' THEN currency_amount * 0.0038   -- Hungarian Forint  1 = $0.0038
                           WHEN currency_unit = 'IDR' THEN currency_amount * 0.000074 -- Indonesian Rupiah 1 = $0.000074
                           WHEN currency_unit = 'INR' THEN currency_amount * 0.02     -- Indian Rupee      1 = $0.02
                           WHEN currency_unit = 'ITL' THEN NULL                       -- Italian Lira
                           WHEN currency_unit = 'JPY' THEN currency_amount * 0.0089   -- Japanese Yen      1 = $0.0089
                           WHEN currency_unit = 'KRW' THEN currency_amount * 0.000913 -- South Korean Won  1 = $0.000913
                           WHEN currency_unit = 'MXN' THEN currency_amount * 0.05     -- Mexican peso      1 = $0.05
                           WHEN currency_unit = 'MYR' THEN currency_amount * 0.24     -- Malaysian Ringgit 1 = $0.24
                           WHEN currency_unit = 'NGN' THEN currency_amount * 0.0028   -- Nigerian Naira    1 = $0.0028
                           WHEN currency_unit = 'NOK' THEN currency_amount * 0.12     -- Norwegian Krone   1 = $0.12
                           WHEN currency_unit = 'NZD' THEN currency_amount * 0.69     -- New Zealand bux   1 = $0.69
                           WHEN currency_unit = 'PHP' THEN currency_amount * 0.02     -- Phillipine Peso   1 = $0.02
                           WHEN currency_unit = 'PKR' THEN currency_amount * 0.0095   -- Pakistani Rupee   1 = $0.0095
                           WHEN currency_unit = 'PYG' THEN currency_amount * 0.000177 -- Paraguayan bux    1 = $0.000177
                           WHEN currency_unit = 'RUR' THEN currency_amount * 0.02     -- Russian Ruble     1 = $0.02
                           WHEN currency_unit = 'SEK' THEN currency_amount * 0.12     -- Swedish Krona     1 = $0.12
                           WHEN currency_unit = 'SGD' THEN currency_amount * 0.74     -- Singapore Dollar  1 = $0.74
                           WHEN currency_unit = 'THB' THEN currency_amount * 0.03     -- Thai Bhat         1 = $0.03
                           WHEN currency_unit = 'TRL' THEN currency_amount * 0.25     -- Turkish Lira      1 = $0.25
                           WHEN currency_unit = 'TWD' THEN currency_amount * 0.03     -- Taiwan New Dollar 1 = $0.03
                           END;


-- Update the movies table
UPDATE movies m
SET budget = currency_amount
FROM imdb_staging i
WHERE m.id = i.id ;



-- Clean up genre names
UPDATE genres
SET genre_name = TRIM(genre_name)
