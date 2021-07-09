package io.knowgo.vehicle.simulator;

import android.annotation.SuppressLint;
import android.content.ContentValues;
import android.content.Intent;
import android.content.SharedPreferences;
import android.database.sqlite.SQLiteDatabase;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.Switch;
import android.widget.TextView;

import androidx.annotation.Nullable;
import androidx.fragment.app.FragmentActivity;
import androidx.preference.PreferenceManager;

import com.google.android.material.textfield.TextInputEditText;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Objects;

import io.knowgo.vehicle.simulator.complications.RiskComplicationProviderService;
import io.knowgo.vehicle.simulator.db.DatabaseManager;
import io.knowgo.vehicle.simulator.db.KnowGoDbHelper;
import io.knowgo.vehicle.simulator.db.schemas.DriverEvent;
import io.knowgo.vehicle.simulator.db.schemas.HeartrateMeasurement;
import io.knowgo.vehicle.simulator.db.schemas.LocationMeasurement;
import io.knowgo.vehicle.simulator.db.schemas.RiskScore;
import io.knowgo.vehicle.simulator.util.HaversineDistance;

public class JourneySummaryActivity extends FragmentActivity {
    private static final String TAG = JourneySummaryActivity.class.getSimpleName();
    private HeartRateRiskScorer heartRateRiskScorer;
    private SQLiteDatabase db;
    private View mSummaryView;
    private static Instant journeyEnd;
    private static String journeyId;
    private SharedPreferences sharedPreferences;

    private String journeyDurationString(Duration duration) {
        long secondsTotal = duration.getSeconds();
        long hours = (secondsTotal % 86400) / 3600;
        long minutes = ((secondsTotal % 86400) % 3600) / 60;
        long seconds = ((secondsTotal % 86400) % 3600) % 60;
        StringBuilder stringBuilder = new StringBuilder();

        if (hours > 0)
            stringBuilder.append(hours).append("h");
        if (minutes > 0)
            stringBuilder.append(minutes).append("m");

        stringBuilder.append(seconds).append("s");

        return stringBuilder.toString();
    }

    private int calculateHeartRateRisk(Duration journeyDuration) {
        int numHeartRateEvents = KnowGoDbHelper.numRows(db, DriverEvent.DriverEventEntry.TABLE_NAME,
                DriverEvent.DriverEventEntry.COLUMN_NAME_JOURNEYID, journeyId);
        if (numHeartRateEvents > 0) {
            float totalExceeded = KnowGoDbHelper.sumColumn(db, DriverEvent.DriverEventEntry.TABLE_NAME,
                    DriverEvent.DriverEventEntry.COLUMN_NAME_HR_THRESHOLD_EXCEEDED,
                    DriverEvent.DriverEventEntry.COLUMN_NAME_JOURNEYID, journeyId);
            int averageExceeded = (int) totalExceeded / numHeartRateEvents;
            return (int) heartRateRiskScorer.score(numHeartRateEvents, averageExceeded, journeyDuration);
        }

        return -1;
    }

    // Round double to 2 decimal places
    private static double roundDouble(double value) {
        return BigDecimal.valueOf(value).setScale(2, BigDecimal.ROUND_HALF_UP).doubleValue();
    }

    private double calculateJourneyDistance() {
        double distance = 0.00;
        ArrayList<LocationMeasurement.Coordinates> coordinatesList = LocationMeasurement.getJourneyCoordinates(db, journeyId);
        if (coordinatesList.size() < 2) {
            Log.e(TAG, "Insufficient telemetry for journey");
            return -1;
        }

        LocationMeasurement.Coordinates prevCoordinates = coordinatesList.get(0);
        for (int idx = 1; idx < coordinatesList.size(); idx++) {
            LocationMeasurement.Coordinates currCoordinates = coordinatesList.get(idx);
            distance += HaversineDistance.distance(prevCoordinates.latitude, prevCoordinates.longitude,
                    currCoordinates.latitude, currCoordinates.longitude);
            prevCoordinates = currCoordinates;
        }
        return roundDouble(distance);
    }

    private void updateDistanceSummary() {
        TextView journeyDistanceText = mSummaryView.findViewById(R.id.journeyDistance);
        double distance = calculateJourneyDistance();
        if (distance < 0) {
            hideDistanceSummary();
            return;
        }

        String distanceString = distance + "km";
        journeyDistanceText.setText(distanceString);
    }

    private void hideDistanceSummary() {
        LinearLayout distanceSummary = mSummaryView.findViewById(R.id.distanceSummary);
        distanceSummary.setVisibility(View.GONE);
    }

    private void hideHeartRateSummary() {
        LinearLayout minMaxSummary = mSummaryView.findViewById(R.id.heartRateMinMaxSummary);
        LinearLayout avgSummary = mSummaryView.findViewById(R.id.heartRateAvgSummary);
        minMaxSummary.setVisibility(View.GONE);
        avgSummary.setVisibility(View.GONE);
    }

    private void updateHeartRateSummary(int minHeartRate) {
        TextView minHeartRateReading = mSummaryView.findViewById(R.id.heartRateMinReading);
        TextView maxHeartRateReading = mSummaryView.findViewById(R.id.heartRateMaxReading);
        TextView avgHeartRateReading = mSummaryView.findViewById(R.id.heartRateAvgReading);

        int maxHeartRate = KnowGoDbHelper.maxColumnValue(db,
                HeartrateMeasurement.HeartrateMeasurementEntry.TABLE_NAME,
                HeartrateMeasurement.HeartrateMeasurementEntry.COLUMN_NAME_HEART_RATE,
                HeartrateMeasurement.HeartrateMeasurementEntry.COLUMN_NAME_JOURNEYID,
                journeyId);

        long summedReadings = KnowGoDbHelper.sumColumn(db,
                HeartrateMeasurement.HeartrateMeasurementEntry.TABLE_NAME,
                HeartrateMeasurement.HeartrateMeasurementEntry.COLUMN_NAME_HEART_RATE,
                HeartrateMeasurement.HeartrateMeasurementEntry.COLUMN_NAME_JOURNEYID,
                journeyId);

        int numReadings = KnowGoDbHelper.numRows(db,
                HeartrateMeasurement.HeartrateMeasurementEntry.TABLE_NAME,
                HeartrateMeasurement.HeartrateMeasurementEntry.COLUMN_NAME_JOURNEYID,
                journeyId);

        // Sanity check to prevent a worst-case div-by-0 exception
        if (numReadings <= 0) {
            Log.e(TAG, "db returned an invalid number of heartrate readings");
            hideHeartRateSummary();
            return;
        }

        int average = (int) summedReadings / numReadings;

        minHeartRateReading.setText(String.valueOf(minHeartRate));
        maxHeartRateReading.setText(String.valueOf(maxHeartRate));
        avgHeartRateReading.setText(String.valueOf(average));
    }

    void persistRiskScore(int score) {
        // Save journey score to DB
        ContentValues values = new ContentValues();

        values.put(RiskScore.RiskScoreEntry.COLUMN_NAME_TIMESTAMP, journeyEnd.toString());
        values.put(RiskScore.RiskScoreEntry.COLUMN_NAME_JOURNEYID, journeyId);
        values.put(RiskScore.RiskScoreEntry.COLUMN_NAME_SCORE, score);

        db.insert(RiskScore.RiskScoreEntry.TABLE_NAME, null, values);

        // Update latest score
        SharedPreferences.Editor editor = sharedPreferences.edit();
        editor.putInt("score", score);
        editor.apply();

        // Then notify the complication to redraw
        RiskComplicationProviderService.requestComplicationDataUpdate(getApplicationContext());
    }

    @SuppressLint("UseSwitchCompatOrMaterialCode")
    @Override
    public void onCreate(@Nullable Bundle savedInstanceState) {
        Log.i(TAG, "Starting summary activity");
        Intent intent = getIntent();
        Bundle extras = intent.getExtras();

        super.onCreate(savedInstanceState);
        mSummaryView = getLayoutInflater().inflate(R.layout.journey_summary, null);
        setContentView(mSummaryView);

        View mSettingsView = getLayoutInflater().inflate(R.layout.settings_page, null);
        sharedPreferences = PreferenceManager.getDefaultSharedPreferences(this);
        db = DatabaseManager.getInstance().openDatabase();

        Switch mHeartRateSwitch = mSettingsView.findViewById(R.id.switchHeartRate);
        if (mHeartRateSwitch.isChecked()) {
            final TextInputEditText mMinHeartRateSetting = mSettingsView.findViewById(R.id.minHeartRate);
            final TextInputEditText mMaxHeartRateSetting = mSettingsView.findViewById(R.id.maxHeartRate);
            final int minHeartRateSetting = sharedPreferences.getInt("heartrate_min",
                    Integer.parseInt(Objects.requireNonNull(mMinHeartRateSetting.getText()).toString()));
            final int maxHeartRateSetting = sharedPreferences.getInt("heartrate_max",
                    Integer.parseInt(Objects.requireNonNull(mMaxHeartRateSetting.getText()).toString()));

            heartRateRiskScorer = new HeartRateRiskScorer(minHeartRateSetting, maxHeartRateSetting, this);
        }

        journeyId = extras.getString("journeyId");
        Instant journeyBegin = (Instant) extras.get("journeyBegin");
        journeyEnd = (Instant) extras.get("journeyEnd");
        Duration journeyDuration = Duration.between(journeyBegin, journeyEnd);

        TextView journeyDurationTime = mSummaryView.findViewById(R.id.journeyDurationTime);
        journeyDurationTime.setText(journeyDurationString(journeyDuration));

        int minHeartRate = KnowGoDbHelper.minColumnValue(db,
                HeartrateMeasurement.HeartrateMeasurementEntry.TABLE_NAME,
                HeartrateMeasurement.HeartrateMeasurementEntry.COLUMN_NAME_HEART_RATE,
                HeartrateMeasurement.HeartrateMeasurementEntry.COLUMN_NAME_JOURNEYID,
                journeyId);

        // If there are no heart rate readings for this journey, hide the summary data
        if (minHeartRate == 0) {
            hideHeartRateSummary();
        } else {
            // Update min/max/avg BPM readings
            updateHeartRateSummary(minHeartRate);

            // Calculate and plot the risk score
            int score = calculateHeartRateRisk(journeyDuration);
            ProgressBar riskSummaryProgress = mSummaryView.findViewById(R.id.riskSummaryProgressBar);
            TextView riskSummaryText = mSummaryView.findViewById(R.id.riskSummaryText);

            riskSummaryProgress.setProgress(score);
            riskSummaryText.setText(String.valueOf(score));

            // Persist risk score
            persistRiskScore(score);
        }

        int numLocationReadings = KnowGoDbHelper.numRows(db,
                LocationMeasurement.LocationMeasurementEntry.TABLE_NAME,
                LocationMeasurement.LocationMeasurementEntry.COLUMN_NAME_JOURNEYID, journeyId);

        // No GPS telemetry available, hide distance summary.
        if (numLocationReadings <= 0) {
            hideDistanceSummary();
        } else {
            // If we have valid GPS telemetry for this journey persisted on-watch, apply the
            // Haversine formula across all lat/lng pairs to derive the distance travelled.
            updateDistanceSummary();
        }
    }

    @Override
    protected void onStart() {
        super.onStart();
        ProgressBar riskSummaryProgress = mSummaryView.findViewById(R.id.riskSummaryProgressBar);
        int score = riskSummaryProgress.getProgress();
        ProgressBarAnimation progressBarAnimation = new ProgressBarAnimation(riskSummaryProgress,
                0, score);
        progressBarAnimation.setDuration(1000);
        riskSummaryProgress.startAnimation(progressBarAnimation);

        TextView riskSummaryText = mSummaryView.findViewById(R.id.riskSummaryText);
        TextViewNumberAnimation numberAnimation = new TextViewNumberAnimation(riskSummaryText,
                0, score);
        numberAnimation.setDuration(1000);
        riskSummaryText.startAnimation(numberAnimation);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        DatabaseManager.getInstance().closeDatabase();
    }
}
