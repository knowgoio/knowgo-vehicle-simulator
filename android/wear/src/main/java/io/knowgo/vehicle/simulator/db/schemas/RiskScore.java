package io.knowgo.vehicle.simulator.db.schemas;

import android.provider.BaseColumns;

public final class RiskScore {
    private RiskScore() {
    }

    public static class RiskScoreEntry implements BaseColumns {
        public static final String TABLE_NAME = "risk_scores";
        public static final String COLUMN_NAME_SCORE = "score";
        public static final String COLUMN_NAME_TIMESTAMP = "timestamp";
        public static final String COLUMN_NAME_JOURNEYID = "journeyId";
    }

    public static final String SQL_CREATE_ENTRIES =
            "CREATE TABLE " + RiskScoreEntry.TABLE_NAME + " (" +
                    RiskScoreEntry._ID + "INTEGER PRIMARY KEY," +
                    RiskScoreEntry.COLUMN_NAME_SCORE + " TEXT," +
                    RiskScoreEntry.COLUMN_NAME_TIMESTAMP + " TEXT," +
                    RiskScoreEntry.COLUMN_NAME_JOURNEYID + " TEXT)";

    public static final String SQL_DELETE_ENTRIES =
            "DROP TABLE IF EXISTS " + RiskScoreEntry.TABLE_NAME;
}
