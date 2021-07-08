package io.knowgo.vehicle.simulator;

import android.annotation.SuppressLint;
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

import java.time.Duration;
import java.time.Instant;
import java.util.Objects;

import io.knowgo.vehicle.simulator.db.KnowGoDbHelper;
import io.knowgo.vehicle.simulator.db.schemas.DriverEvent;
import io.knowgo.vehicle.simulator.db.schemas.HeartrateMeasurement;

public class JourneySummaryActivity extends FragmentActivity {
    private static final String TAG = JourneySummaryActivity.class.getSimpleName();
    private KnowGoDbHelper knowGoDbHelper;
    private HeartRateRiskScorer heartRateRiskScorer;
    private SQLiteDatabase db;
    private View mSummaryView;
    private static String journeyId;

    private String journeyDurationString(Duration duration) {
        long secondsTotal = duration.getSeconds();
        long hours = (secondsTotal % 86400 ) / 3600;
        long minutes = ((secondsTotal % 86400 ) % 3600 ) / 60;
        long seconds = ((secondsTotal % 86400 ) % 3600 ) % 60;
        StringBuilder stringBuilder = new StringBuilder();

        if (hours > 0)
            stringBuilder.append(hours).append("h");
        if (minutes > 0)
            stringBuilder.append(minutes).append("m");
        if (seconds > 0)
            stringBuilder.append(seconds).append("s");

        return stringBuilder.toString();
    }

    private int calculateHeartRateRisk(Duration journeyDuration) {
        int numHeartRateEvents = knowGoDbHelper.numRows(db, DriverEvent.DriverEventEntry.TABLE_NAME,
                DriverEvent.DriverEventEntry.COLUMN_NAME_JOURNEYID, journeyId);
        if (numHeartRateEvents > 0) {
            float totalExceeded = knowGoDbHelper.sumColumn(db, DriverEvent.DriverEventEntry.TABLE_NAME,
                    DriverEvent.DriverEventEntry.COLUMN_NAME_HR_THRESHOLD_EXCEEDED,
                    DriverEvent.DriverEventEntry.COLUMN_NAME_JOURNEYID, journeyId);
            int averageExceeded = (int) totalExceeded / numHeartRateEvents;
            return (int) heartRateRiskScorer.score(numHeartRateEvents, averageExceeded, journeyDuration);
        }

        return -1;
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

        int maxHeartRate = knowGoDbHelper.maxColumnValue(db,
                HeartrateMeasurement.HeartrateMeasurementEntry.TABLE_NAME,
                HeartrateMeasurement.HeartrateMeasurementEntry.COLUMN_NAME_HEART_RATE,
                HeartrateMeasurement.HeartrateMeasurementEntry.COLUMN_NAME_JOURNEYID,
                journeyId);

        long summedReadings = knowGoDbHelper.sumColumn(db,
                HeartrateMeasurement.HeartrateMeasurementEntry.TABLE_NAME,
                HeartrateMeasurement.HeartrateMeasurementEntry.COLUMN_NAME_HEART_RATE,
                HeartrateMeasurement.HeartrateMeasurementEntry.COLUMN_NAME_JOURNEYID,
                journeyId);

        int numReadings = knowGoDbHelper.numRows(db,
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
        SharedPreferences sharedPreferences = PreferenceManager.getDefaultSharedPreferences(this);
        knowGoDbHelper = new KnowGoDbHelper(getApplicationContext());
        db = knowGoDbHelper.getReadableDatabase();

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
        Instant journeyEnd = (Instant) extras.get("journeyEnd");
        Duration journeyDuration = Duration.between(journeyBegin, journeyEnd);

        TextView journeyDurationTime = mSummaryView.findViewById(R.id.journeyDurationTime);
        journeyDurationTime.setText(journeyDurationString(journeyDuration));

        int minHeartRate = knowGoDbHelper.minColumnValue(db,
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
        }

        // TODO: Hide for now, update with calculation from GPS telemetry records
        hideDistanceSummary();
    }
}
