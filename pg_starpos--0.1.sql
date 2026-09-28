
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