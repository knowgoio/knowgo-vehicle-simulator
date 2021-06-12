package io.knowgo.vehicle.simulator.db.schemas;

import android.provider.BaseColumns;

public final class LocationMeasurement {
    private LocationMeasurement() {
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
}
