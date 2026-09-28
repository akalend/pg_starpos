/*
 * contrib/pg_starpos/pg_starpos.c
 */
#include "postgres.h"
#include "fmgr.h"
#include "funcapi.h"
#include "c.h"
#include "access/htup_details.h"
#include "utils/builtins.h"
#include "utils/float.h"
#include "utils/fmgrprotos.h"
#include "utils/timestamp.h"
#include <math.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

PG_MODULE_MAGIC;

PG_FUNCTION_INFO_V1(star_position);

Datum
star_position(PG_FUNCTION_ARGS)
{
    TimestampTz ts       = PG_GETARG_TIMESTAMPTZ(0);
    double      lat      = PG_GETARG_FLOAT8(1);
    double      lon      = PG_GETARG_FLOAT8(2);
    double      ra_hours = PG_GETARG_FLOAT8(3);
    double      dec_deg  = PG_GETARG_FLOAT8(4);

    /* RA из часов в градусы */
    double ra_deg = ra_hours * 15.0;

    /* Юлианская дата: epoch PostgreSQL = 2000-01-01 00:00:00 UTC = JD 2451545.0 */
    double jd = 2451545.0 + (double) ts / (86400.0 * 1000000.0);

    /* GMST */
    double T = (jd - 2451545.0) / 36525.0;
    double gmst = 280.46061837
                + 360.98564736629 * (jd - 2451545.0)
                + 0.000387933 * T * T
                - T * T * T / 38710000.0;

    double lst;
    double H;
    double phi;
    double dec;
    double Hr;
    double sin_h;
    double h;
    double x;
    double y;
    double A;
    double alt_deg;
    double az_deg;

    Datum values[2];
    bool  nulls[2] = { false, false };
    TupleDesc tupdesc;
    HeapTuple tuple;


    gmst = fmod(gmst, 360.0);
    if (gmst < 0.0) gmst += 360.0;

    /* LST */
    lst = gmst + lon;
    lst = fmod(lst, 360.0);
    if (lst < 0.0) lst += 360.0;

    /* Часовой угол */
    H = lst - ra_deg;
    H = fmod(H + 180.0, 360.0);
    if (H < 0.0) H += 360.0;
    H -= 180.0;

    phi = lat     * M_PI / 180.0;
    dec = dec_deg * M_PI / 180.0;
    Hr  = H       * M_PI / 180.0;

    /* Высота */
    sin_h = sin(phi) * sin(dec)
                 + cos(phi) * cos(dec) * cos(Hr);

    if (sin_h >  1.0) sin_h =  1.0;
    if (sin_h < -1.0) sin_h = -1.0;

    h = asin(sin_h);

    /* Азимут 0=север, 90=восток */
    y = -cos(dec) * sin(Hr);
    x =  sin(dec) * cos(phi)
              - cos(dec) * sin(phi) * cos(Hr);

    A = atan2(y, x);

    alt_deg = h * 180.0 / M_PI;
    az_deg  = A * 180.0 / M_PI;

    if (az_deg < 0.0) az_deg += 360.0;

    /* Формируем композитный тип star_pos */
    if (get_call_result_type(fcinfo, NULL, &tupdesc) != TYPEFUNC_COMPOSITE)
        ereport(ERROR,
                (errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
                 errmsg("function returning record called in context "
                        "that cannot accept type record")));


    values[0] = Float8GetDatum(alt_deg);
    values[1] = Float8GetDatum(az_deg);

    tuple = heap_form_tuple(tupdesc, values, nulls);

    PG_RETURN_DATUM(HeapTupleGetDatum(tuple));
}