package io.knowgo.vehicle.simulator.complications;

import android.app.PendingIntent;
import android.content.ComponentName;
import android.graphics.drawable.Icon;
import android.support.wearable.complications.ComplicationData;
import android.support.wearable.complications.ComplicationManager;
import android.support.wearable.complications.ComplicationProviderService;
import android.util.Log;

import androidx.annotation.DrawableRes;

import io.knowgo.vehicle.simulator.R;

public class VehicleControlsComplicationProviderService extends ComplicationProviderService {
    private static final String TAG = VehicleControlsComplicationProviderService.class.getSimpleName();

    @Override
    public void onComplicationUpdate(
            int complicationId, int dataType, ComplicationManager complicationManager) {
        Log.d(TAG, "onComplicationUpdate() id: " + complicationId);

        ComponentName thisProvider = new ComponentName(this, getClass());
        PendingIntent complicationPendingIntent =
                ComplicationTapBroadcastReceiver.getToggleIntent(
                        this, thisProvider, complicationId, 0);
        ComplicationData complicationData = null;
        @DrawableRes int vehicleControlsIcon = R.drawable.ic_vehicle_controls;

        switch (dataType) {
            case ComplicationData.TYPE_ICON:
                complicationData =
                        new ComplicationData.Builder(ComplicationData.TYPE_ICON)
                                .setIcon(Icon.createWithResource(this, vehicleControlsIcon))
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
}