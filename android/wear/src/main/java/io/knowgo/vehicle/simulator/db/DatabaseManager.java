package io.knowgo.vehicle.simulator.db;

import android.database.sqlite.SQLiteDatabase;

/**
 * Thread-safe SQLiteDatabase wrapper, adapted from:
 * https://stackoverflow.com/a/19996964/11355043
 */
public class DatabaseManager {
    private final static String TAG = DatabaseManager.class.getSimpleName();
    private int mOpenCounter;
    private static DatabaseManager instance;
    private static KnowGoDbHelper mDatabaseHelper;
    private SQLiteDatabase mDatabase;

    public static synchronized void initializeInstance(KnowGoDbHelper helper) {
        if (instance == null) {
            instance = new DatabaseManager();
            mDatabaseHelper = helper;
        }
    }

    public static synchronized DatabaseManager getInstance() {
        if (instance == null) {
            throw new IllegalStateException(TAG +
                    " is not initialized, call initializeInstance(..) method first.");
        }

        return instance;
    }

    public synchronized SQLiteDatabase openDatabase() {
        mOpenCounter++;
        if(mOpenCounter == 1) {
            mDatabase = mDatabaseHelper.getWritableDatabase();
        }
        return mDatabase;
    }

    public synchronized void closeDatabase() {
        mOpenCounter--;
        if (mOpenCounter == 0) {
            mDatabase.close();
        }
    }
}