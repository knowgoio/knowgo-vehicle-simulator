/*
 * Copyright (C) 2017 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package io.knowgo.vehicle.simulator;

import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.support.wearable.complications.ProviderUpdateRequester;

/**
 * Simple {@link BroadcastReceiver} subclass for asynchronously incrementing an integer for any
 * complication id triggered via TapAction on complication. Also, provides static method to create
 * a {@link PendingIntent} that triggers this receiver.
 */
public class ComplicationTapBroadcastReceiver extends BroadcastReceiver {

    private static final String EXTRA_PROVIDER_COMPONENT =
            "io.knowgo.vehicle.simulator.provider.action.PROVIDER_COMPONENT";
    private static final String EXTRA_COMPLICATION_ID =
            "io.knowgo.vehicle.simulator.provider.action.COMPLICATION_ID";

    static final int MIN_NUMBER = 0;
    static final int MAX_NUMBER = 100;
    static final String COMPLICATION_PROVIDER_PREFERENCES_FILE_KEY =
            "io.knowgo.vehicle.simulator.COMPLICATION_PROVIDER_PREFERENCES_FILE_KEY";

    @Override
    public void onReceive(Context context, Intent intent) {
        Bundle extras = intent.getExtras();
        ComponentName provider = extras.getParcelable(EXTRA_PROVIDER_COMPONENT);
        int complicationId = extras.getInt(EXTRA_COMPLICATION_ID);

        // Retrieve data via SharedPreferences.
        String preferenceKey = getPreferenceKey(provider, complicationId);
        SharedPreferences sharedPreferences =
                context.getSharedPreferences(COMPLICATION_PROVIDER_PREFERENCES_FILE_KEY, 0);

        int value = sharedPreferences.getInt(preferenceKey, MIN_NUMBER);

        // TODO: Fetch the actual risk score and persist this with shared preferences

        // Update data for complication.
        value = (value + 1) % MAX_NUMBER;

        SharedPreferences.Editor editor = sharedPreferences.edit();
        editor.putInt(preferenceKey, value);
        editor.apply();

        // Request an update for the complication that has just been tapped.
        ProviderUpdateRequester requester = new ProviderUpdateRequester(context, provider);
        requester.requestUpdate(complicationId);
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

    /**
     * Returns the key for the shared preference used to hold the current state of a given
     * complication.
     */
    static String getPreferenceKey(ComponentName provider, int complicationId) {
        return provider.getClassName() + complicationId;
    }
}
