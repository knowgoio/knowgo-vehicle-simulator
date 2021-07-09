package io.knowgo.vehicle.simulator;

import org.eclipse.paho.android.service.MqttAndroidClient;
import org.eclipse.paho.client.mqttv3.IMqttActionListener;
import org.eclipse.paho.client.mqttv3.IMqttDeliveryToken;
import org.eclipse.paho.client.mqttv3.IMqttToken;
import org.eclipse.paho.client.mqttv3.MqttCallback;
import org.eclipse.paho.client.mqttv3.MqttConnectOptions;
import org.eclipse.paho.client.mqttv3.MqttException;
import org.eclipse.paho.client.mqttv3.MqttMessage;

import android.content.Context;
import android.util.Log;

public class MqttPublisher {
    private static final String TAG = MqttPublisher.class.getSimpleName();
    private String serverUri;
    private String topic;
    private final MqttAndroidClient mqttAndroidClient;

    public MqttPublisher(Context context, String serverUri, String topic) {
        Log.d(TAG, "Initializing MQTT Publisher at " + serverUri + "/" + topic);
        this.serverUri = serverUri;
        this.topic = topic;
        String clientId = "knowgo-watch";
        mqttAndroidClient = new MqttAndroidClient(context, this.serverUri, clientId);
        mqttAndroidClient.setCallback(new MqttCallback() {
            @Override
            public void connectionLost(Throwable cause) {
                Log.e(TAG, "Connection lost");
            }

            @Override
            public void messageArrived(String topic, MqttMessage message) {
                Log.d(TAG, "topic: " + topic + ", msg: " + new String(message.getPayload()));
            }

            @Override
            public void deliveryComplete(IMqttDeliveryToken token) {
            }
        });

        try {
            mqttAndroidClient.connect(new MqttConnectOptions(), null, new IMqttActionListener() {
                @Override
                public void onSuccess(IMqttToken asyncActionToken) {
                }

                @Override
                public void onFailure(IMqttToken asyncActionToken, Throwable exception) {
                    Log.e(TAG, "connect failed");
                }
            });
        } catch (MqttException e) {
            e.printStackTrace();
        }
    }

    public void setTopic(String mqttTopic) {
        this.topic = mqttTopic;
    }

    public void setServerUri(String serverUri) {
        this.serverUri = serverUri;
    }

    public void publishMessage(String payload) {
        try {
            if (!mqttAndroidClient.isConnected()) {
                mqttAndroidClient.connect();
            }

            MqttMessage message = new MqttMessage();

            message.setPayload(payload.getBytes());
            message.setQos(0);

            if (mqttAndroidClient.isConnected()) {
                mqttAndroidClient.publish(this.topic, message, null, new IMqttActionListener() {
                    @Override
                    public void onSuccess(IMqttToken asyncActionToken) {
                    }

                    @Override
                    public void onFailure(IMqttToken asyncActionToken, Throwable exception) {
                        Log.e(TAG, "publish failed");
                    }
                });
            }
        } catch (MqttException e) {
            Log.e(TAG, e.toString());
            e.printStackTrace();
        }
    }
}
