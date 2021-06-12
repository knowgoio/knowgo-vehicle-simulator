package io.knowgo.vehicle.simulator;

import android.Manifest;
import android.annotation.SuppressLint;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.util.Log;
import android.view.View;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Toast;
import android.widget.ToggleButton;

import androidx.core.app.ActivityCompat;
import androidx.fragment.app.FragmentActivity;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;
import androidx.preference.PreferenceManager;
import androidx.viewpager2.adapter.FragmentStateAdapter;
import androidx.viewpager2.widget.ViewPager2;
import androidx.wear.ambient.AmbientModeSupport;

import com.google.android.gms.wearable.DataClient;
import com.google.android.gms.wearable.DataEvent;
import com.google.android.gms.wearable.DataEventBuffer;
import com.google.android.gms.wearable.DataItem;
import com.google.android.gms.wearable.DataMap;
import com.google.android.gms.wearable.Wearable;
import com.google.android.material.textfield.TextInputEditText;

import org.json.JSONException;
import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.time.Instant;
import java.util.Date;
import java.util.Locale;

import io.knowgo.vehicle.simulator.complications.RiskComplicationProviderService;

import static io.knowgo.vehicle.simulator.complications.ComplicationTapBroadcastReceiver.EXTRA_PAGER_DESTINATION;

public class MainActivity extends FragmentActivity implements SensorEventListener, LocationListener, AmbientModeSupport.AmbientCallbackProvider, DataClient.OnDataChangedListener {
    private static final String TAG = MainActivity.class.getName();
    private Receiver messageReceiver;
    private TextView mNoticeView;
    private ToggleButton mStartStopButton;
    private ToggleButton mHeartRateToggleButton;
    private ToggleButton mGPSToggleButton;
    private ImageView mIconView;
    private View mBackground;
    private int mActiveTextColor;
    private int mHeartRateIconColor;
    private int mGPSIconColor;
    private Sensor mHeartRateSensor;
    private SensorManager mSensorManager;
    private TextView dateText;
    private TextView mHeartRateMeasurement;
    private LocationManager locationManager;
    private ViewPager2 mPager;
    private MqttPublisher mqttPublisher;
    SharedPreferences sharedPreferences;
    SharedPreferences.Editor editor;
    SimpleDateFormat sdf;

    private Locale getLocale(Context context) {
        return context.getResources().getConfiguration().getLocales().get(0);
    }

    private boolean hasGPSPerms() {
        return (checkSelfPermission("android.permission.ACCESS_FINE_LOCATION") ==
                PackageManager.PERMISSION_GRANTED ||
                checkSelfPermission("android.permission.ACCESS_COARSE_LOCATION") ==
                        PackageManager.PERMISSION_GRANTED);
    }

    private boolean hasGPS() {
        return getPackageManager().hasSystemFeature(PackageManager.FEATURE_LOCATION_GPS) && hasGPSPerms();
    }

    private void startLocationUpdates() {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
            ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED ||
            !isRunning()) {
            return;
        }

        Location loc = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER);
        if (loc != null) {
            this.onLocationChanged(loc);
            locationManager.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000, 0, this);
        }
    }

    private void stopLocationUpdates() {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
            ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            return;
        }

        locationManager.removeUpdates(this);
    }

    @SuppressLint("InflateParams")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        boolean is24HourFormat;
        String datefmt = "hh:mm a";

        super.onCreate(savedInstanceState);

        setContentView(R.layout.activity_screen_slide);

        View mAboutView = getLayoutInflater().inflate(R.layout.about_page, null);
        View mHomeView = getLayoutInflater().inflate(R.layout.activity_main, null);
        View mSettingsView = getLayoutInflater().inflate(R.layout.settings_page, null);
        mActiveTextColor = getResources().getColor(R.color.primary, null);

        // Ambient mode support
        AmbientModeSupport.attach(this);

        is24HourFormat = android.text.format.DateFormat.is24HourFormat(this);
        if (is24HourFormat)
            datefmt = "HH:mm";

        sharedPreferences = PreferenceManager.getDefaultSharedPreferences(this);

        mIconView = mHomeView.findViewById(R.id.icon);

        mIconView.setOnClickListener(v -> mPager.setCurrentItem(R.layout.about_page));

        mNoticeView = mHomeView.findViewById(R.id.notice);
        mStartStopButton = mHomeView.findViewById(R.id.journeyToggleButton);
        mHeartRateToggleButton = mHomeView.findViewById(R.id.heartRateToggleButton);
        mGPSToggleButton = mHomeView.findViewById(R.id.gpsToggleButton);
        mBackground = mHomeView.findViewById(R.id.boxlayout);
        mHeartRateMeasurement = mHomeView.findViewById(R.id.heartRateMeasurement);
        dateText = mHomeView.findViewById(R.id.date);

        // Clear the cached heart rate reading if monitoring has been disabled
        mHeartRateToggleButton.setOnClickListener(v -> {
            if (!mHeartRateToggleButton.isChecked()) {
                mHeartRateMeasurement.setText("--");
            }
        });

        // Update the app version
        try {
            Context context = getApplicationContext();
            PackageInfo pInfo = context.getPackageManager().getPackageInfo(context.getPackageName(), 0);
            final TextView appVersion = mAboutView.findViewById(R.id.appVersion);
            appVersion.setText(pInfo.versionName);
        } catch (PackageManager.NameNotFoundException e) {
            e.printStackTrace();
        }

        mGPSIconColor = mGPSToggleButton.getBackgroundTintList().getDefaultColor();
        mHeartRateIconColor = mHeartRateToggleButton.getBackgroundTintList().getDefaultColor();

        sdf = new SimpleDateFormat(datefmt, getLocale(this));
        dateText.setText(sdf.format(new Date()));

        TextInputEditText mMqttBroker = mSettingsView.findViewById(R.id.mqttBroker);
        TextInputEditText mMqttTopic = mSettingsView.findViewById(R.id.mqttTopic);

        // Verify internet permissions, try to obtain at run-time.
        if ((ActivityCompat.checkSelfPermission(this, Manifest.permission.INTERNET) != PackageManager.PERMISSION_GRANTED) ||
            (ActivityCompat.checkSelfPermission(this,Manifest.permission.ACCESS_NETWORK_STATE) != PackageManager.PERMISSION_GRANTED)) {
            requestPermissions(new String[]{
                    "android.permission.ACCESS_NETWORK_STATE",
                    "android.permission.INTERNET"}, 0);
        }

        // Verify body sensor permissions, try to obtain at run-time.
        if (checkSelfPermission("android.permission.BODY_SENSORS") == PackageManager.PERMISSION_DENIED) {
            requestPermissions(new String[]{"android.permission.BODY_SENSORS"}, 0);
        }

        if (!hasGPSPerms()) {
            requestPermissions(new String[]{
                    "android.permission.ACCESS_FINE_LOCATION",
                    "android.permission.ACCESS_COARSE_LOCATION"}, 0);
        }

        if (hasGPS()) {
            Log.i(TAG, "GPS available");
            locationManager = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
        } else {
            // As GPS is unavailable on this watch, disable the icon completely
            Log.i(TAG, "GPS unavailable");
            mGPSToggleButton.setChecked(false);
            mGPSToggleButton.setEnabled(false);
            mGPSIconColor = getColor(R.color.knowgo_default_grey);
            mGPSToggleButton.setBackgroundTintList(ColorStateList.valueOf(mGPSIconColor));
        }

        mSensorManager = (SensorManager) getSystemService(SENSOR_SERVICE);
        mHeartRateSensor = mSensorManager.getDefaultSensor(Sensor.TYPE_HEART_RATE);

        mPager = findViewById(R.id.pager);
        FragmentStateAdapter pagerAdapter = new ScreenSlidePagerAdapter(this, mHomeView, mSettingsView, mAboutView);
        mPager.setAdapter(pagerAdapter);

        int destinationId = getIntent().getIntExtra(EXTRA_PAGER_DESTINATION, 0);
        if (destinationId != 0) {
            mPager.setCurrentItem(destinationId);
        }

        mqttPublisher = new MqttPublisher(getApplicationContext(),
                mMqttBroker.getText().toString(),
                mMqttTopic.getText().toString());

        mMqttBroker.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {
            }

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
            }

            @Override
            public void afterTextChanged(Editable s) {
                mqttPublisher.setServerUri(s.toString());
            }
        });

        mMqttTopic.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {
            }

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
            }

            @Override
            public void afterTextChanged(Editable s) {
                mqttPublisher.setTopic(s.toString());
            }
        });
    }

    @Override
    public void onStart() {
        // Register local broadcast receiver
        IntentFilter newFilter = new IntentFilter(Intent.ACTION_SEND);
        messageReceiver = new Receiver();
        LocalBroadcastManager.getInstance(this).registerReceiver(messageReceiver, newFilter);

        Wearable.getDataClient(this).addListener(this);
        mSensorManager.registerListener(this, mHeartRateSensor,
                SensorManager.SENSOR_DELAY_NORMAL);

        super.onStart();
    }

    @Override
    protected void onStop() {
        Wearable.getDataClient(this).removeListener(this);
        LocalBroadcastManager.getInstance(this).unregisterReceiver(messageReceiver);
        mSensorManager.unregisterListener(this);
        super.onStop();
    }

    @Override
    public void onSensorChanged(SensorEvent event) {
        if (event.sensor.getType() == Sensor.TYPE_HEART_RATE) {
            if (!mHeartRateToggleButton.isChecked()) {
                return;
            }

            String updatedMeasurement = String.valueOf((int)event.values[0]);
            if (mHeartRateMeasurement.getText() == updatedMeasurement) {
                // No change compared to previous reading.
                return;
            }

            mHeartRateMeasurement.setText(updatedMeasurement);

            try {
                final JSONObject object = new JSONObject();
                object.put("heart_rate", (int) event.values[0]);
                object.put("timestamp", Instant.now().toString());
                mqttPublisher.publishMessage(object.toString());
                new MessageSender("/MessageChannel", object.toString(), getApplicationContext()).start();
            } catch (JSONException e) {
                Log.e(TAG, "Failed to create JSON object");
            }
        } else {
            Log.e(TAG, "Unknown sensor type");
        }
    }

    @Override
    public void onAccuracyChanged(Sensor sensor, int accuracy) {
    }

    @Override
    public void onLocationChanged(Location location) {
        if (!mGPSToggleButton.isChecked()) {
            return;
        }

        try {
            double longitude = location.getLongitude();
            double latitude = location.getLatitude();
            float bearing = location.getBearing();
            final JSONObject object = new JSONObject();
            object.put("longitude", longitude);
            object.put("latitude", latitude);
            object.put("bearing", bearing);
            object.put("timestamp", Instant.now().toString());
            mqttPublisher.publishMessage(object.toString());
            new MessageSender("/MessageChannel", object.toString(), getApplicationContext()).start();
        } catch (JSONException e) {
            Log.e(TAG, "Failed to create JSON object");
        }
    }

    @Override
    public void onStatusChanged(String provider, int status, Bundle extras) {
    }

    @Override
    public void onProviderEnabled(String provider) {

    }

    @Override
    public void onProviderDisabled(String provider) {

    }

    @Override
    public AmbientModeSupport.AmbientCallback getAmbientCallback() {
        return new MyAmbientCallback();
    }

    @Override
    public void onDataChanged(DataEventBuffer dataEventBuffer) {
        for (DataEvent event : dataEventBuffer) {
            DataItem item = event.getDataItem();
            if (event.getType() == DataEvent.TYPE_DELETED) {
                Log.d(TAG, "DataItem deleted: " + item.getUri());
            } else if (event.getType() == DataEvent.TYPE_CHANGED) {
                if (item.getUri().getPath().compareTo("/knowgo/vehicle/info") == 0) {
                    byte[] rawData = event.getDataItem().getData();
                    DataMap info = DataMap.fromByteArray(rawData);
                    Log.i(TAG, "Vehicle Info: " + info.toString());
                } else if (item.getUri().getPath().compareTo("/knowgo/vehicle/state") == 0) {
                    byte[] rawData = event.getDataItem().getData();
                    DataMap state = DataMap.fromByteArray(rawData);
                    Log.i(TAG, "Vehicle State: " + state.toString());
                }
            }
        }
    }

    // Ambient mode callbacks
    private class MyAmbientCallback extends AmbientModeSupport.AmbientCallback {
        @Override
        public void onEnterAmbient(Bundle ambientDetails) {
            Log.d(TAG, "Entering Ambient mode");
            super.onEnterAmbient(ambientDetails);

            mBackground.setBackgroundColor(Color.BLACK);
            mNoticeView.setVisibility(View.GONE);

            dateText.setText(sdf.format(new Date()));
            dateText.setTextColor(Color.WHITE);

            mHeartRateToggleButton.setBackgroundTintList(ColorStateList.valueOf(Color.WHITE));
            mStartStopButton.setBackgroundTintList(ColorStateList.valueOf(Color.WHITE));
            mGPSToggleButton.setBackgroundTintList(ColorStateList.valueOf(Color.WHITE));

            mIconView.setImageTintList(ColorStateList.valueOf(Color.WHITE));
        }

        @Override
        public void onExitAmbient() {
            Log.d(TAG, "Exiting Ambient mode");
            super.onExitAmbient();

            mNoticeView.setVisibility(View.VISIBLE);
            dateText.setTextColor(mActiveTextColor);
            mBackground.setBackgroundColor(Color.WHITE);

            mHeartRateToggleButton.setBackgroundTintList(ColorStateList.valueOf(mHeartRateIconColor));
            mStartStopButton.setBackgroundTintList(ColorStateList.valueOf(mActiveTextColor));
            mGPSToggleButton.setBackgroundTintList(ColorStateList.valueOf(mGPSIconColor));
            mIconView.setImageTintList(ColorStateList.valueOf(mActiveTextColor));
        }

        @Override
        public void onUpdateAmbient() {
            super.onUpdateAmbient();
            dateText.setText(sdf.format(new Date()));
        }
    }

    // Handle start/stop notifications to the Wearable
    private void handleStartStopNotification(JSONObject jsonObject) throws JSONException {
        String simulatorState = jsonObject.getString("simulator");
        if (simulatorState.equals("start")) {
            onStartJourney();
        } else if (simulatorState.equals("stop")) {
            onStopJourney();
        } else {
            Log.e(TAG, "Received invalid simulator control message: " + simulatorState);
        }
    }

    // Handle text notifications to the Wearable
    private void handleTextNotification(Context context, JSONObject jsonObject) throws JSONException {
        String text = jsonObject.getString("text");
        Log.d(TAG, "Received a text notification from the handheld: " + text);
        Toast.makeText(context, text, Toast.LENGTH_SHORT).show();
    }

    // Handle notifications of risk scores to the Wearable
    private void handleRiskScoreNotification(Context context, JSONObject jsonObject) throws JSONException {
        int score = jsonObject.getInt("score");
        Log.d(TAG, "Received a risk score from the handheld: " + score);

        // If the message payload contains a risk score, first persist it
        editor = sharedPreferences.edit();
        editor.putInt("score", score);
        editor.apply();

        // Then notify the complication to redraw
        RiskComplicationProviderService.requestComplicationDataUpdate(context);
    }

    /*
     * Handle all messages from the Mobile/Handheld to the Wearable
     */
    public class Receiver extends BroadcastReceiver {
        @Override
        public void onReceive(Context context, Intent intent) {
            try {
                /*
                 * All messages are JSON payloads wrapped in an intent bundle by the MessageService.
                 * Unpack the bundle and briefly look at the JSON payload to determine which
                 * handlers need to be invoked.
                 */
                String jsonMsg = intent.getStringExtra("message");
                JSONObject jsonObject = new JSONObject(jsonMsg);

                if (jsonObject.has("simulator")) {
                    handleStartStopNotification(jsonObject);
                }

                if (jsonObject.has("text")) {
                    handleTextNotification(context, jsonObject);
                }

                if (jsonObject.has("score")) {
                    handleRiskScoreNotification(context, jsonObject);
                }
            } catch (JSONException e) {
                Log.e(TAG, "Unable to decode message from handheld");
            }
        }
    }

    public boolean isRunning() {
        return mStartStopButton.isChecked();
    }

    private void onStartJourney() {
        Log.d(TAG, "Starting journey...");
        mStartStopButton.setChecked(true);
        mNoticeView.setText(getResources().getText(R.string.stop_journey));
        startLocationUpdates();
    }

    private void onStopJourney() {
        Log.d(TAG, "Stopping journey...");
        stopLocationUpdates();
        mNoticeView.setText(getResources().getText(R.string.start_journey));
        mStartStopButton.setChecked(false);
    }

    public void onStartStopJourney(View view) {
        if (mStartStopButton.isChecked()) {
            onStartJourney();
        } else {
            onStopJourney();
        }
    }
}
