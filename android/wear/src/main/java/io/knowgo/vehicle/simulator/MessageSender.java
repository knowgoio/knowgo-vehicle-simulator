package io.knowgo.vehicle.simulator;

import android.content.Context;
import android.util.Log;

import com.google.android.gms.tasks.Task;
import com.google.android.gms.tasks.Tasks;
import com.google.android.gms.wearable.Node;
import com.google.android.gms.wearable.Wearable;

import java.util.List;

class MessageSender extends Thread {
    private static final String TAG = "MessageSender";

    String path;
    String message;
    Context context;

    MessageSender(String path, String message, Context context) {
        this.path = path;
        this.message = message;
        this.context = context;
    }

    public void run() {
        try {
            Task<List<Node>> nodeListTask = Wearable.getNodeClient(context.getApplicationContext()).getConnectedNodes();
            List<Node> nodes = Tasks.await(nodeListTask);
            byte[] payload = message.getBytes();

            Log.d(TAG, "Sending message \"" + message + "\" to mobile");
            for (Node node : nodes) {
                String nodeId = node.getId();
                Task<Integer> sendMessageTask = Wearable.getMessageClient(context).sendMessage(nodeId, this.path, payload);

                try {
                    Tasks.await(sendMessageTask);
                } catch (Exception exception) {
                    // TODO: Implement exception handling
                    Log.e(TAG, "Exception thrown");
                }
            }
        } catch (Exception exception) {
            Log.e(TAG, exception.getMessage());
        }
    }
}