package io.knowgo.vehicle.simulator;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;

import androidx.preference.PreferenceManager;

import java.math.BigDecimal;
import java.time.Duration;

import static java.lang.Math.max;
import static java.lang.Math.min;

/**
 * A simple watch-local risk scorer for approximating risk based on measured heart rate levels
 * and pre-defined min/max thresholds. This is not expected to take the place of a more robust
 * ML-based scorer provided by KnowGo Score, but can provide approximate functionality when
 * no backend connectivity is possible, or when using offline.
 */
public class HeartRateRiskScorer implements SharedPreferences.OnSharedPreferenceChangeListener {
    private static final String TAG = HeartRateRiskScorer.class.getSimpleName();

    private int minHeartRateThreshold;
    private int maxHeartRateThreshold;

    HeartRateRiskScorer(int minThreshold, int maxThreshold, Context context) {
        SharedPreferences prefs = PreferenceManager.getDefaultSharedPreferences(context);

        this.minHeartRateThreshold = minThreshold;
        this.maxHeartRateThreshold = maxThreshold;

        prefs.registerOnSharedPreferenceChangeListener(this);
    }

    // Calculate the percentage exceeded
    public int calculatePercentageExceeded(int heartRateMeasurement) {
        int exceeded = -1;

        if (heartRateMeasurement > maxHeartRateThreshold) {
            exceeded = ((heartRateMeasurement - maxHeartRateThreshold) / maxHeartRateThreshold) * 100;
        } else if (heartRateMeasurement < maxHeartRateThreshold) {
            exceeded = ((minHeartRateThreshold - heartRateMeasurement) / minHeartRateThreshold) * 100;
        }

        return exceeded;
    }

    // Round float to 2 decimal places
    private static float roundFloat(float d) {
        return BigDecimal.valueOf(d).setScale(2, BigDecimal.ROUND_HALF_UP).floatValue();
    }

    // Calculate approximate risk score
    public float score(int numEvents, int avgExceeded, Duration journeyDuration) {
        long minutes = max(journeyDuration.toMinutes(), 5);
        float score = min(roundFloat(((numEvents * 15F) / minutes) * avgExceeded), 100);
        Log.d(TAG, "score(): " + score);
        return min(score, 100);
    }

    @Override
    public void onSharedPreferenceChanged(SharedPreferences sharedPreferences, String key) {
        if (key.equals("heartrate_min")) {
            minHeartRateThreshold = sharedPreferences.getInt("heartrate_min", minHeartRateThreshold);
        } else if (key.equals("heartrate_max")) {
            maxHeartRateThreshold = sharedPreferences.getInt("heartrate_max", maxHeartRateThreshold);
        }
    }
}
