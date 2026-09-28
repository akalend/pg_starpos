CREATE TYPE star_pos AS (
    alt double precision,
    az  double precision
);

CREATE FUNCTION star_position(
    ts       timestamptz,
    lat      double precision,
    lon      double precision,
    ra_hours double precision,
    dec_deg  double precision
) RETURNS star_pos
AS 'MODULE_PATHNAME', 'star_position'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE OR REPLACE FUNCTION dms_to_degrees(txt text)
RETURNS double precision
LANGUAGE plpgsql
IMMUTABLE STRICT PARALLEL SAFE
AS $$
DECLARE
    s     text;
    parts text[];
    sign  double precision := 1.0;
    dd    int;
    mm    int;
    ss    double precision;
BEGIN
    s := btrim(txt);

    -- 1. Унифицируем знак минус (ASCII '-' и U+2212 '−')
    s := replace(s, U&'\2212', '-');   -- −
    s := replace(s, U&'\2013', '-');   -- – (en dash)
    s := replace(s, U&'\2014', '-');   -- — (em dash)

    -- 2. Знак вынести наружу
    IF s LIKE '-%' THEN
        sign := -1.0;
        s := btrim(substring(s FROM 2));
    ELSIF s LIKE '+%' THEN
        s := btrim(substring(s FROM 2));
    END IF;

    -- 3. Десятичная запятая
    s := replace(s, ',', '.');

    -- 4. Все символы-разделители -> пробел
    s := replace(s, ':', ' ');
    s := replace(s, U&'\00B0', ' ');   -- °
    s := replace(s, U&'\2032', ' ');   -- ′
    s := replace(s, U&'\2033', ' ');   -- ″
    s := replace(s, U&'\2034', ' ');   -- ‴
    s := replace(s, U&'\2019', ' ');   -- ’
    s := replace(s, U&'\201D', ' ');   -- ”
    s := replace(s, '''',  ' ');       -- '
    s := replace(s, '"',   ' ');       -- "

    -- 5. Убираем любые буквы (dd, mm, ss, deg, град, ч, м, с и т.п.)
    s := regexp_replace(s, '[a-zA-Zа-яА-ЯёЁ]', ' ', 'g');

    -- 6. Сжимаем пробелы
    s := btrim(regexp_replace(s, '\s+', ' ', 'g'));

    parts := string_to_array(s, ' ');

    IF array_length(parts, 1) <> 3 THEN
        RAISE EXCEPTION
            'Ожидается формат ''DD MM SS'' (допускаются ''-16° 42′ 47.3″'', ''-16:42:47.3'', ''-16d 42m 47.3s'' и т.п.), получено: %', txt;
    END IF;

    BEGIN
        dd := parts[1]::int;
        mm := parts[2]::int;
        ss := parts[3]::double precision;
    EXCEPTION WHEN others THEN
        RAISE EXCEPTION 'Не удалось разобрать: %', txt;
    END;

    IF dd < 0 OR dd > 90 OR mm < 0 OR mm > 59 OR ss < 0 OR ss >= 60 THEN
        RAISE EXCEPTION 'Недопустимое значение склонения: %', txt;
    END IF;

    RETURN sign * (dd + mm / 60.0 + ss / 3600.0);
END;
$$;

CREATE OR REPLACE FUNCTION hms_to_hours(txt text)
RETURNS double precision
LANGUAGE plpgsql
IMMUTABLE STRICT PARALLEL SAFE
AS $$
DECLARE
    s     text;
    parts text[];
    hh    int;
    mm    int;
    ss    double precision;
BEGIN
    s := btrim(txt);

    -- минус (на случай отрицательных значений — но RA обычно без знака)
    s := replace(s, U&'\2212', '-');
    s := replace(s, U&'\2013', '-');
    s := replace(s, U&'\2014', '-');

    -- десятичная запятая
    s := replace(s, ',', '.');

    -- разделители
    s := replace(s, ':', ' ');
    s := replace(s, U&'\00B0', ' ');
    s := replace(s, U&'\2032', ' ');
    s := replace(s, U&'\2033', ' ');
    s := replace(s, U&'\2034', ' ');
    s := replace(s, U&'\2019', ' ');
    s := replace(s, U&'\201D', ' ');
    s := replace(s, '''',  ' ');
    s := replace(s, '"',   ' ');

    -- буквы (h, m, s, hh, mm, ss, ч, м, с) -> пробел
    s := regexp_replace(s, '[a-zA-Zа-яА-ЯёЁ]', ' ', 'g');

    s := btrim(regexp_replace(s, '\s+', ' ', 'g'));

    parts := string_to_array(s, ' ');

    IF array_length(parts, 1) <> 3 THEN
        RAISE EXCEPTION
            'Ожидается формат ''HH MM SS'' (допускаются ''06:45:09.25'', ''06h 45m 09.25s'', ''06 ч 45 м 09.25 с'' и т.п.), получено: %', txt;
    END IF;

    BEGIN
        hh := parts[1]::int;
        mm := parts[2]::int;
        ss := parts[3]::double precision;
    EXCEPTION WHEN others THEN
        RAISE EXCEPTION 'Не удалось разобрать: %', txt;
    END;

    IF hh < 0 OR hh > 24 OR mm < 0 OR mm > 59 OR ss < 0 OR ss >= 60 THEN
        RAISE EXCEPTION 'Недопустимое значение времени: %', txt;
    END IF;

    IF hh = 24 AND (mm <> 0 OR ss <> 0) THEN
        RAISE EXCEPTION 'RA = 24h допускается только как 24 00 00.000, получено: %', txt;
    END IF;

    RETURN hh + mm / 60.0 + ss / 3600.0;
END;
$$;