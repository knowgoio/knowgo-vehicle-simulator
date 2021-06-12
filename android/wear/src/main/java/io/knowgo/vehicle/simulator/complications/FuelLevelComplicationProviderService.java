package io.knowgo.vehicle.simulator.complications;

import android.app.PendingIntent;
import android.content.ComponentName;
import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.drawable.Icon;
import android.support.wearable.complications.ComplicationData;
import android.support.wearable.complications.ComplicationManager;
import android.support.wearable.complications.ComplicationProviderService;
import android.support.wearable.complications.ComplicationText;
import android.support.wearable.complications.ProviderUpdateRequester;
import android.util.Log;

import androidx.annotation.DrawableRes;
import androidx.preference.PreferenceManager;

import java.util.Locale;

import io.knowgo.vehicle.simulator.R;

public class FuelLevelComplicationProviderService extends ComplicationProviderService {
    private static final String TAG = FuelLevelComplicationProviderService.class.getSimpleName();
    private SharedPreferences sharedPreferences;

    @Override
    public void onCreate() {
        sharedPreferences = PreferenceManager.getDefaultSharedPreferences(getApplicationContext());
        super.onCreate();
    }

    @Override
    public void onComplicationUpdate(
            int complicationId, int dataType, ComplicationManager complicationManager) {
        Log.d(TAG, "onComplicationUpdate() id: " + complicationId);

        ComponentName thisProvider = new ComponentName(this, getClass());
        PendingIntent complicationPendingIntent =
                ComplicationTapBroadcastReceiver.getToggleIntent(
                        this, thisProvider, complicationId, 0);

        int number = sharedPreferences.getInt("fuel_level",
                ComplicationTapBroadcastReceiver.MAX_NUMBER);
        String percentText = String.format(Locale.getDefault(), "%d%%", number);

        ComplicationData complicationData = null;
        @DrawableRes int petrolPumpIcon = R.drawable.ic_petrol_pump;

        switch (dataType) {
            case ComplicationData.TYPE_RANGED_VALUE:
                complicationData =
                        new ComplicationData.Builder(ComplicationData.TYPE_RANGED_VALUE)
                                .setValue(number)
                                .setMinValue(ComplicationTapBroadcastReceiver.MIN_NUMBER)
                                .setMaxValue(ComplicationTapBroadcastReceiver.MAX_NUMBER)
                                .setShortText(ComplicationText.plainText(percentText))
                                .setIcon(Icon.createWithResource(this, petrolPumpIcon))
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

    // Force an update/redraw of the complication when new data has been pushed
    public static void requestComplicationDataUpdate(Context context) {
        ComponentName componentName = new ComponentName(context, FuelLevelComplicationProviderService.class);
        ProviderUpdateRequester requester = new ProviderUpdateRequester(context, componentName);
        requester.requestUpdateAll();
    }
}
