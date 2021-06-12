package io.knowgo.vehicle.simulator.db;

import android.content.Context;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;

import io.knowgo.vehicle.simulator.db.schemas.DriverEvent;
import io.knowgo.vehicle.simulator.db.schemas.HeartrateMeasurement;
import io.knowgo.vehicle.simulator.db.schemas.LocationMeasurement;
import io.knowgo.vehicle.simulator.db.schemas.RiskScore;

public class KnowGoDbHelper extends SQLiteOpenHelper {
    // If you change the database schema, you must increment the database version.
    public static final int DATABASE_VERSION = 1;
    public static final String DATABASE_NAME = "KnowGo.db";

    public KnowGoDbHelper(Context context) {
        super(context, DATABASE_NAME, null, DATABASE_VERSION);
    }

    @Override
    public void onCreate(SQLiteDatabase db) {
        db.execSQL(RiskScore.SQL_CREATE_ENTRIES);
        db.execSQL(HeartrateMeasurement.SQL_CREATE_ENTRIES);
        db.execSQL(LocationMeasurement.SQL_CREATE_ENTRIES);
        db.execSQL(DriverEvent.SQL_CREATE_ENTRIES);
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        db.execSQL(RiskScore.SQL_DELETE_ENTRIES);
        db.execSQL(HeartrateMeasurement.SQL_DELETE_ENTRIES);
        db.execSQL(LocationMeasurement.SQL_DELETE_ENTRIES);
        db.execSQL(DriverEvent.SQL_DELETE_ENTRIES);
        onCreate(db);
    }

    @Override
    public void onDowngrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        onUpgrade(db, oldVersion, newVersion);
    }
}
