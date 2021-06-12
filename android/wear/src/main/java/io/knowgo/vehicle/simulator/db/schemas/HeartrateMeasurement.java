package io.knowgo.vehicle.simulator.db.schemas;

import android.provider.BaseColumns;

public final class HeartrateMeasurement {
    private HeartrateMeasurement() {
    }

    public static class HeartrateMeasurementEntry implements BaseColumns {
        public static final String TABLE_NAME = "heartrate_measurements";
        public static final String COLUMN_NAME_HEART_RATE = "heart_rate";
        public static final String COLUMN_NAME_TIMESTAMP = "timestamp";
        public static final String COLUMN_NAME_JOURNEYID = "journeyId";
    }

    public static final String SQL_CREATE_ENTRIES =
            "CREATE TABLE " + HeartrateMeasurementEntry.TABLE_NAME + " (" +
                    HeartrateMeasurementEntry._ID + "INTEGER PRIMARY KEY," +
                    HeartrateMeasurementEntry.COLUMN_NAME_HEART_RATE + " TEXT," +
                    HeartrateMeasurementEntry.COLUMN_NAME_TIMESTAMP + " TEXT," +
                    HeartrateMeasurementEntry.COLUMN_NAME_JOURNEYID + " TEXT)";

    public static final String SQL_DELETE_ENTRIES =
            "DROP TABLE IF EXISTS " + HeartrateMeasurementEntry.TABLE_NAME;
}
