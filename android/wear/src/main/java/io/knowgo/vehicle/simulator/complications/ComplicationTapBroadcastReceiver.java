package io.knowgo.vehicle.simulator.complications;

import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;

import io.knowgo.vehicle.simulator.MainActivity;

public class ComplicationTapBroadcastReceiver extends BroadcastReceiver {
    private static final String EXTRA_PROVIDER_COMPONENT =
            "io.knowgo.vehicle.simulator.provider.action.PROVIDER_COMPONENT";
    private static final String EXTRA_COMPLICATION_ID =
            "io.knowgo.vehicle.simulator.provider.action.COMPLICATION_ID";

    static final int MIN_NUMBER = 0;
    static final int MAX_NUMBER = 100;

    /*
     * Launch the main activity on tap
     */
    @Override
    public void onReceive(Context context, Intent intent) {
        Intent appIntent = new Intent(context, MainActivity.class);
        appIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        context.startActivity(appIntent);
    }

    /**
     * Returns a pending intent, suitable for use as a tap intent, that causes a complication to be
     * toggled and updated.
     */
    static PendingIntent getToggleIntent(
            Context context, ComponentName provider, int complicationId) {
        Intent intent = new Intent(context, ComplicationTapBroadcastReceiver.class);
        intent.putExtra(EXTRA_PROVIDER_COMPONENT, provider);
        intent.putExtra(EXTRA_COMPLICATION_ID, complicationId);

        // Pass complicationId as the requestCode to ensure that different complications get
        // different intents.
        return PendingIntent.getBroadcast(
                context, complicationId, intent, PendingIntent.FLAG_UPDATE_CURRENT);
    }
}
