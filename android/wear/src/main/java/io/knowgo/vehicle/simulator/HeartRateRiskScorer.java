package io.knowgo.vehicle.simulator;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;

import androidx.preference.PreferenceManager;

import org.tensorflow.lite.DataType;
import org.tensorflow.lite.support.tensorbuffer.TensorBuffer;

import java.io.IOException;
import java.math.BigDecimal;
import java.time.Duration;

import io.knowgo.vehicle.simulator.ml.HeartrateRiskDnnModel;

import static java.lang.Math.max;
import static java.lang.Math.min;

/**
 * Watch-local Heartrate risk scorer for approximating risk based on measured heart rate levels
 * and pre-defined min/max thresholds. Implemented either through a bundled TFLite DNN model,
 * or through a fallback algorithm.
 *
 * In either case, the input features are the number of times a heartrate measurement has exceeded
 * the pre-defined thresholds, the average extent at which the thresholds have been exceeded, and
 * the duration of the journey.
 */
public class HeartRateRiskScorer implements SharedPreferences.OnSharedPreferenceChangeListener {
    private static final String TAG = HeartRateRiskScorer.class.getSimpleName();
    private HeartrateRiskDnnModel model;
    private int minHeartRateThreshold;
    private int maxHeartRateThreshold;

    HeartRateRiskScorer(int minThreshold, int maxThreshold, Context context) {
        SharedPreferences prefs = PreferenceManager.getDefaultSharedPreferences(context);

        this.minHeartRateThreshold = minThreshold;
        this.maxHeartRateThreshold = maxThreshold;

        // Try to load the TFLite DNN model. Fall back on approximate scoring if this fails.
        try {
            this.model = HeartrateRiskDnnModel.newInstance(context);
        } catch (IOException e) {
            Log.e(TAG, "Failed to load DNN, falling back on approximate scoring");
            this.model = null;
        }

        prefs.registerOnSharedPreferenceChangeListener(this);
    }

    // Calculate the percentage exceeded
    public int calculatePercentageExceeded(int heartRateMeasurement) {
        int exceeded = -1;

        if (heartRateMeasurement > maxHeartRateThreshold) {
            exceeded = ((heartRateMeasurement - maxHeartRateThreshold) / maxHeartRateThreshold) * 100;
        } else if (heartRateMeasurement < minHeartRateThreshold) {
            exceeded = ((minHeartRateThreshold - heartRateMeasurement) / minHeartRateThreshold) * 100;
        }

        return exceeded;
    }

    // Round float to 2 decimal places
    private static float roundFloat(float d) {
        return BigDecimal.valueOf(d).setScale(2, BigDecimal.ROUND_HALF_UP).floatValue();
    }

    // Predict a risk score using the bundled TFLite DNN model
    private float scoreDNN(int numEvents, int avgExceeded, Duration journeyDuration) {
        TensorBuffer tensorBuffer = TensorBuffer.createFixedSize(new int[]{1, 3}, DataType.FLOAT32);
        tensorBuffer.loadArray(new float[]{numEvents, avgExceeded, journeyDuration.toMinutes()});
        HeartrateRiskDnnModel.Outputs outputs = this.model.process(tensorBuffer);
        float score = roundFloat(outputs.getOutputFeature0AsTensorBuffer().getFloatValue(0));
        Log.d(TAG, "scoreDNN(): " + score);
        return min(score, 100);
    }

    // Calculate risk score, either with the TFLite DNN model, or as an approximation
    public float score(int numEvents, int avgExceeded, Duration journeyDuration) {
        if (this.model != null) {
            return scoreDNN(numEvents, avgExceeded, journeyDuration);
        } else {
            // Calculate an approximate risk score
            long minutes = max(journeyDuration.toMinutes(), 5);
            float score = min(roundFloat(((numEvents * 15F) / minutes) * avgExceeded), 100);
            Log.d(TAG, "score(): " + score);
            return min(score, 100);
        }
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
