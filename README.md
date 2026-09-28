# pg_starpos
Calculating the position of a star in the sky based on the time and location on Earth.

	
	CREATE TYPE star_pos AS (
	    alt double precision,
	    az  double precision
	);

	CREATE FUNCTION star_position(
	    ts       timestamptz,       -- time of observation
	    lat      double precision,  -- geo coordinate
	    lon      double precision,
	    ra_hours double precision,  -- star coordinate J2000
	    dec_deg  double precision
	) RETURNS star_pos

	SELECT * from star_position('2026-09-28 19:44:00',45.0,32.34, 15, 28);
	        alt        |        az         
	-------------------+-------------------
	 4.650182120702318 | 54.21211940754664


