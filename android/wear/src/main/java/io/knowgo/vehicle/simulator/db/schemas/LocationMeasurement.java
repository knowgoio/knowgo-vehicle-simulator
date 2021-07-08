package io.knowgo.vehicle.simulator.db.schemas;

import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.provider.BaseColumns;

import java.util.ArrayList;

public final class LocationMeasurement {
    private LocationMeasurement() {
    }

    public static class Coordinates {
        public double latitude;
        public double longitude;
    }

    public static class LocationMeasurementEntry implements BaseColumns {
        public static final String TABLE_NAME = "location_measurements";
        public static final String COLUMN_NAME_LATITUDE = "latitude";
        public static final String COLUMN_NAME_LONGITUDE = "longitude";
        public static final String COLUMN_NAME_BEARING = "bearing";
        public static final String COLUMN_NAME_TIMESTAMP = "timestamp";
        public static final String COLUMN_NAME_JOURNEYID = "journeyId";
    }

    public static final String SQL_CREATE_ENTRIES =
            "CREATE TABLE " + LocationMeasurementEntry.TABLE_NAME + " (" +
                    LocationMeasurementEntry._ID + "INTEGER PRIMARY KEY," +
                    LocationMeasurementEntry.COLUMN_NAME_LATITUDE + " REAL," +
                    LocationMeasurementEntry.COLUMN_NAME_LONGITUDE + " REAL," +
                    LocationMeasurementEntry.COLUMN_NAME_BEARING + " REAL," +
                    LocationMeasurementEntry.COLUMN_NAME_TIMESTAMP + " TEXT," +
                    LocationMeasurementEntry.COLUMN_NAME_JOURNEYID + " TEXT)";

    public static final String SQL_DELETE_ENTRIES =
            "DROP TABLE IF EXISTS " + LocationMeasurementEntry.TABLE_NAME;

    public static ArrayList<Coordinates> getJourneyCoordinates(SQLiteDatabase db, String journeyId) {
        ArrayList<Coordinates> coordinates = new ArrayList<>();
        String sql = "SELECT " + LocationMeasurementEntry.COLUMN_NAME_LATITUDE + ", " +
                LocationMeasurementEntry.COLUMN_NAME_LONGITUDE + " FROM " +
                LocationMeasurementEntry.TABLE_NAME + " WHERE " +
                LocationMeasurementEntry.COLUMN_NAME_JOURNEYID + "='" + journeyId + "'";
        Cursor cursor = db.rawQuery(sql, null);
        Coordinates coordinate;

        if (cursor.moveToFirst()) {
            do {
                coordinate = new Coordinates();
                coordinate.latitude = cursor.getDouble(0);
                coordinate.longitude = cursor.getDouble(1);
                coordinates.add(coordinate);
            } while (cursor.moveToNext());
        }

        cursor.close();
        return coordinates;
    }
}
