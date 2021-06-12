package io.knowgo.vehicle.simulator.db.schemas;

import android.provider.BaseColumns;

public final class DriverEvent {
    private DriverEvent() {
    }

    public static class DriverEventEntry implements BaseColumns {
        public static final String TABLE_NAME = "driver_events";
        public static final String COLUMN_NAME_HR_THRESHOLD_EXCEEDED = "hr_threshold_exceeded";
        public static final String COLUMN_NAME_TIMESTAMP = "timestamp";
        public static final String COLUMN_NAME_JOURNEYID = "journeyId";
    }

    public static final String SQL_CREATE_ENTRIES =
            "CREATE TABLE " + DriverEventEntry.TABLE_NAME + " (" +
                    DriverEventEntry._ID + "INTEGER PRIMARY KEY," +
                    DriverEventEntry.COLUMN_NAME_HR_THRESHOLD_EXCEEDED + " REAL," +
                    DriverEventEntry.COLUMN_NAME_TIMESTAMP + " TEXT," +
                    DriverEventEntry.COLUMN_NAME_JOURNEYID + " TEXT)";

    public static final String SQL_DELETE_ENTRIES =
            "DROP TABLE IF EXISTS " + DriverEventEntry.TABLE_NAME;
}
