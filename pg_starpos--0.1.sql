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
    s := lower(txt);

    -- десятичная запятая -> точка
    s := replace(s, ',', '.');

    -- двоеточия -> пробелы
    s := replace(s, ':', ' ');

    -- любые буквы (в т.ч. приклеенные: 06h, 45m, 09.25s) -> пробел
    s := regexp_replace(s, '[a-zа-яё]', ' ', 'g');

    -- сжать пробелы и обрезать
    s := trim(both ' ' from regexp_replace(s, '\s+', ' ', 'g'));

    parts := string_to_array(s, ' ');

    IF array_length(parts, 1) <> 3 THEN
        RAISE EXCEPTION 'Ожидается формат ''HH MM SS'' (допускаются ''HH:MM:SS'', ''06h 45m 09.25s'' и т.п.), получено: %', txt;
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
    s := trim(both ' ' from txt);

    -- знак
    IF s LIKE '-%' THEN
        sign := -1.0;
        s := substring(s FROM 2);
    ELSIF s LIKE '+%' THEN
        s := substring(s FROM 2);
    END IF;

    s := lower(s);
    s := replace(s, ',', '.');
    s := replace(s, ':', ' ');

    -- все буквы -> пробел (dd, mm, ss, deg, °, ч, м, с — всё сразу)
    s := regexp_replace(s, '[a-zа-яё]', ' ', 'g');

    s := trim(both ' ' from regexp_replace(s, '\s+', ' ', 'g'));

    parts := string_to_array(s, ' ');

    IF array_length(parts, 1) <> 3 THEN
        RAISE EXCEPTION 'Ожидается формат ''DD MM SS'' (допускаются ''DD:MM:SS'', ''-30d 22m 38.3s'' и т.п.), получено: %', txt;
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