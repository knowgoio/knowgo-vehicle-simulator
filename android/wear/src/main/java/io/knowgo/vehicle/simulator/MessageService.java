package io.knowgo.vehicle.simulator;

import android.content.Intent;

import androidx.localbroadcastmanager.content.LocalBroadcastManager;

import com.google.android.gms.wearable.MessageEvent;
import com.google.android.gms.wearable.WearableListenerService;

public class MessageService extends WearableListenerService {
    @Override
    public void onMessageReceived(MessageEvent messageEvent) {
        if (messageEvent.getPath().equals("/events")) {
            final String msg = new String(messageEvent.getData());
            Intent messageIntent = new Intent();

            messageIntent.setAction(Intent.ACTION_SEND);
            messageIntent.putExtra("message", msg);
            LocalBroadcastManager.getInstance(this).sendBroadcast(messageIntent);
        } else {
            super.onMessageReceived(messageEvent);
        }
    }
}
