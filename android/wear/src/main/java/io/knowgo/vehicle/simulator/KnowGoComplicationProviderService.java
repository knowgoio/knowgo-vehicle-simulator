package io.knowgo.vehicle.simulator;

import android.app.PendingIntent;
import android.content.ComponentName;
import android.content.Context;
import android.content.SharedPreferences;
import android.support.wearable.complications.ComplicationData;
import android.support.wearable.complications.ComplicationManager;
import android.support.wearable.complications.ComplicationProviderService;
import android.support.wearable.complications.ComplicationText;
import android.support.wearable.complications.ProviderUpdateRequester;
import android.util.Log;

import androidx.preference.PreferenceManager;

import java.util.Locale;

/**
 * Example watch face complication data provider provides a number that can be incremented on tap.
 */
public class KnowGoComplicationProviderService extends ComplicationProviderService {
    private static final String TAG = KnowGoComplicationProviderService.class.getSimpleName();
    private SharedPreferences sharedPreferences;

    @Override
    public void onCreate() {
        sharedPreferences = PreferenceManager.getDefaultSharedPreferences(getApplicationContext());
        super.onCreate();
    }

    /*
     * Called when a complication has been activated. The method is for any one-time
     * (per complication) set-up.
     *
     * You can continue sending data for the active complicationId until onComplicationDeactivated()
     * is called.
     */
    @Override
    public void onComplicationActivated(
            int complicationId, int dataType, ComplicationManager complicationManager) {
        Log.d(TAG, "onComplicationActivated(): " + complicationId);
    }

    /*
     * Called when the complication needs updated data from your provider. There are four scenarios
     * when this will happen:
     *
     *   1. An active watch face complication is changed to use this provider
     *   2. A complication using this provider becomes active
     *   3. The period of time you specified in the manifest has elapsed (UPDATE_PERIOD_SECONDS)
     *   4. You triggered an update from your own class via the
     *       ProviderUpdateRequester.requestUpdate() method.
     */
    @Override
    public void onComplicationUpdate(
            int complicationId, int dataType, ComplicationManager complicationManager) {
        Log.d(TAG, "onComplicationUpdate() id: " + complicationId);

        // Create Tap Action so that the user can trigger an update by tapping the complication.
        ComponentName thisProvider = new ComponentName(this, getClass());
        // We pass the complication id, so we can only update the specific complication tapped.
        PendingIntent complicationPendingIntent =
                ComplicationTapBroadcastReceiver.getToggleIntent(
                        this, thisProvider, complicationId);

        // Retrieves your data, in this case, we grab an incrementing number from SharedPrefs.
        int number = sharedPreferences.getInt("score",
                ComplicationTapBroadcastReceiver.MIN_NUMBER);
        String numberText = String.format(Locale.getDefault(), "%d", number);

        ComplicationData complicationData = null;

        switch (dataType) {
            case ComplicationData.TYPE_RANGED_VALUE:
                complicationData =
                        new ComplicationData.Builder(ComplicationData.TYPE_RANGED_VALUE)
                                .setValue(number)
                                .setMinValue(ComplicationTapBroadcastReceiver.MIN_NUMBER)
                                .setMaxValue(ComplicationTapBroadcastReceiver.MAX_NUMBER)
                                .setShortText(ComplicationText.plainText(numberText))
                                .setShortTitle(ComplicationText.plainText("Risk"))
                                .setTapAction(complicationPendingIntent)
                                .build();
                break;
            default:
                if (Log.isLoggable(TAG, Log.WARN)) {
                    Log.w(TAG, "Unexpected complication type " + dataType);
                }
        }

        if (complicationData != null) {
            complicationManager.updateComplicationData(complicationId, complicationData);
        } else {
            // If no data is sent, we still need to inform the ComplicationManager, so the update
            // job can finish and the wake lock isn't held any longer than necessary.
            complicationManager.noUpdateRequired(complicationId);
        }
    }

    /*
     * Called when the complication has been deactivated.
     */
    @Override
    public void onComplicationDeactivated(int complicationId) {
        Log.d(TAG, "onComplicationDeactivated(): " + complicationId);
    }

    // Force an update/redraw of the complication when new data has been pushed
    public static void requestComplicationDataUpdate(Context context) {
        ComponentName componentName = new ComponentName(context, KnowGoComplicationProviderService.class);
        ProviderUpdateRequester requester = new ProviderUpdateRequester(context, componentName);
        requester.requestUpdateAll();
    }
}
