package io.knowgo.vehicle.simulator.complications;

import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;

import io.knowgo.vehicle.simulator.MainActivity;

public class ComplicationTapBroadcastReceiver extends BroadcastReceiver {
    private static final String EXTRA_PROVIDER_COMPONENT =
            "io.knowgo.vehicle.simulator.provider.action.PROVIDER_COMPONENT";
    private static final String EXTRA_COMPLICATION_ID =
            "io.knowgo.vehicle.simulator.provider.action.COMPLICATION_ID";
    public static final String EXTRA_PAGER_DESTINATION =
            "io.knowgo.vehicle.simulator.provider.action.PAGER_DESTINATION";

    static final int MIN_NUMBER = 0;
    static final int MAX_NUMBER = 100;

    /*
     * Launch the main activity on tap
     */
    @Override
    public void onReceive(Context context, Intent intent) {
        Bundle extras = intent.getExtras();
        Intent appIntent = new Intent(context, MainActivity.class);

        appIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);

        if (extras.containsKey(EXTRA_PAGER_DESTINATION)) {
            appIntent.putExtra(EXTRA_PAGER_DESTINATION, intent.getIntExtra(EXTRA_PAGER_DESTINATION, 0));
        }

        context.startActivity(appIntent);
    }

    /**
     * Returns a pending intent, suitable for use as a tap intent, that causes a complication to be
     * toggled and updated.
     */
    static PendingIntent getToggleIntent(
            Context context, ComponentName provider, int complicationId, int destinationView) {
        Intent intent = new Intent(context, ComplicationTapBroadcastReceiver.class);
        intent.putExtra(EXTRA_PROVIDER_COMPONENT, provider);
        intent.putExtra(EXTRA_COMPLICATION_ID, complicationId);
        intent.putExtra(EXTRA_PAGER_DESTINATION, destinationView);

        // Pass complicationId as the requestCode to ensure that different complications get
        // different intents.
        return PendingIntent.getBroadcast(
                context, complicationId, intent, PendingIntent.FLAG_UPDATE_CURRENT);
    }
}
