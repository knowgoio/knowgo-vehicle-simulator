package io.knowgo.vehicle.simulator;

import android.Manifest;
import android.annotation.SuppressLint;
import android.content.BroadcastReceiver;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.content.res.ColorStateList;
import android.database.sqlite.SQLiteDatabase;
import android.graphics.Color;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Bundle;
import android.os.Vibrator;
import android.util.Log;
import android.view.View;
import android.widget.ImageView;
import android.widget.ProgressBar;
import android.widget.Switch;
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
import com.google.android.material.button.MaterialButton;

import org.json.JSONException;
import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.time.Instant;
import java.util.Date;
import java.util.Locale;
import java.util.Objects;
import java.util.UUID;

import io.knowgo.vehicle.simulator.complications.FuelLevelComplicationProviderService;
import io.knowgo.vehicle.simulator.complications.RiskComplicationProviderService;
import io.knowgo.vehicle.simulator.db.DatabaseManager;
import io.knowgo.vehicle.simulator.db.KnowGoDbHelper;
import io.knowgo.vehicle.simulator.db.schemas.DriverEvent;
import io.knowgo.vehicle.simulator.db.schemas.HeartrateMeasurement;
import io.knowgo.vehicle.simulator.db.schemas.LocationMeasurement;

import static io.knowgo.vehicle.simulator.complications.ComplicationTapBroadcastReceiver.EXTRA_PAGER_DESTINATION;

@SuppressLint("UseSwitchCompatOrMaterialCode")
public class MainActivity extends FragmentActivity implements SensorEventListener, LocationListener, AmbientModeSupport.AmbientCallbackProvider, DataClient.OnDataChangedListener, SharedPreferences.OnSharedPreferenceChangeListener {
    private static final String TAG = MainActivity.class.getName();
    private Receiver messageReceiver;
    private TextView mNoticeView;
    private ToggleButton mStartStopButton;
    private ToggleButton mHeartRateToggleButton;
    private ToggleButton mGPSToggleButton;
    private ImageView mIconView;
    private View mBackground;
    private View mHomeView;
    private View mControlsView;
    private int mActiveTextColor;
    private int mHeartRateIconColor;
    private int mGPSIconColor;
    private int minHeartRate, maxHeartRate;
    private Sensor mHeartRateSensor;
    private SensorManager mSensorManager;
    private TextView dateText;
    private TextView mHeartRateMeasurement;
    private LocationManager locationManager;
    private ViewPager2 mPager;
    private SQLiteDatabase db;
    private String journeyId;
    private Vibrator vibrator;
    private final long[] vibrationPattern = {0, 500, 50, 300};
    private final static int VIBRATION_NO_REPEAT = -1;
    private ProgressBar fuelLevelBar;
    private HeartRateRiskScorer heartRateRiskScorer;
    private Instant journeyBegin;
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

        mHomeView = getLayoutInflater().inflate(R.layout.activity_main, null);
        mControlsView = getLayoutInflater().inflate(R.layout.controls_page, null);
        mActiveTextColor = getResources().getColor(R.color.primary, null);

        // Ambient mode support
        AmbientModeSupport.attach(this);

        is24HourFormat = android.text.format.DateFormat.is24HourFormat(this);
        if (is24HourFormat)
            datefmt = "HH:mm";

        sharedPreferences = PreferenceManager.getDefaultSharedPreferences(this);
        sharedPreferences.registerOnSharedPreferenceChangeListener(this);

        KnowGoDbHelper knowGoDbHelper = new KnowGoDbHelper(getApplicationContext());
        DatabaseManager.initializeInstance(knowGoDbHelper);

        fuelLevelBar = mControlsView.findViewById(R.id.fuelLevel);
        fuelLevelBar.setProgress(sharedPreferences.getInt("fuel_level", 100));

        updateVehicleName();

        mIconView = mHomeView.findViewById(R.id.icon);
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

        toggleHeartRateMonitoring(mHomeView);

        mGPSIconColor = mGPSToggleButton.getBackgroundTintList().getDefaultColor();
        mHeartRateIconColor = mHeartRateToggleButton.getBackgroundTintList().getDefaultColor();

        minHeartRate = sharedPreferences.getInt("heartrate_min",
                Integer.parseInt(getString(R.string.heartrate_min_default)));
        maxHeartRate = sharedPreferences.getInt("heartrate_max",
                Integer.parseInt(getString(R.string.heartrate_max_default)));

        sdf = new SimpleDateFormat(datefmt, getLocale(this));
        dateText.setText(sdf.format(new Date()));
        vibrator = (Vibrator) getSystemService(VIBRATOR_SERVICE);

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

        boolean gps_available = hasGPS();
        editor = sharedPreferences.edit();
        editor.putBoolean("gps_available", gps_available);
        editor.apply();

        if (gps_available) {
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
        toggleGPS(mHomeView);

        final boolean mqttEnabled = sharedPreferences.getBoolean("mqtt_enabled", false);
        if (mqttEnabled) {
            final String mqttBroker = sharedPreferences.getString("mqtt_broker", getString(R.string.default_mqtt_broker));
            final String mqttTopic = sharedPreferences.getString("mqtt_topic", getString(R.string.default_mqtt_topic));

            mqttPublisher = new MqttPublisher(getApplicationContext(), mqttBroker, mqttTopic);
        }

        mSensorManager = (SensorManager) getSystemService(SENSOR_SERVICE);
        mHeartRateSensor = mSensorManager.getDefaultSensor(Sensor.TYPE_HEART_RATE);

        mPager = findViewById(R.id.pager);
        FragmentStateAdapter pagerAdapter = new ScreenSlidePagerAdapter(this, mHomeView, mControlsView);
        mPager.setAdapter(pagerAdapter);

        // The activity may have been launched by a complication, in which case a pager destination
        // may have been specified. If so, navigate the pager to the specified destination.
        int destinationId = getIntent().getIntExtra(EXTRA_PAGER_DESTINATION, 0);
        if (destinationId != 0) {
            mPager.setCurrentItem(destinationId);
        }
    }

    @Override
    public void onStart() {
        db = DatabaseManager.getInstance().openDatabase();

        // Register local broadcast receiver
        IntentFilter newFilter = new IntentFilter(Intent.ACTION_SEND);
        messageReceiver = new Receiver();
        LocalBroadcastManager.getInstance(this).registerReceiver(messageReceiver, newFilter);

        heartRateRiskScorer = new HeartRateRiskScorer(minHeartRate, maxHeartRate, this);

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
        DatabaseManager.getInstance().closeDatabase();
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

            final int heart_rate = (int) event.values[0];
            final String timestamp = Instant.now().toString();
            ContentValues values = new ContentValues();

            // Don't log events if there's no active journey
            if (heart_rate == 0 || !isRunning()) {
                return;
            }

            values.put(HeartrateMeasurement.HeartrateMeasurementEntry.COLUMN_NAME_HEART_RATE, heart_rate);
            values.put(HeartrateMeasurement.HeartrateMeasurementEntry.COLUMN_NAME_TIMESTAMP, timestamp);
            values.put(HeartrateMeasurement.HeartrateMeasurementEntry.COLUMN_NAME_JOURNEYID, journeyId);

            db.insert(HeartrateMeasurement.HeartrateMeasurementEntry.TABLE_NAME, null, values);

            if (heart_rate > maxHeartRate || heart_rate < minHeartRate) {
                ContentValues driverEventValues = new ContentValues();

                driverEventValues.put(DriverEvent.DriverEventEntry.COLUMN_NAME_JOURNEYID, journeyId);
                driverEventValues.put(DriverEvent.DriverEventEntry.COLUMN_NAME_HR_THRESHOLD_EXCEEDED,
                        heartRateRiskScorer.calculatePercentageExceeded(heart_rate));
                driverEventValues.put(DriverEvent.DriverEventEntry.COLUMN_NAME_TIMESTAMP, timestamp);

                db.insert(DriverEvent.DriverEventEntry.TABLE_NAME, null, driverEventValues);
            }

            try {
                final JSONObject object = new JSONObject();
                object.put("journeyId", journeyId);
                object.put("heart_rate", heart_rate);
                object.put("timestamp", timestamp);

                if (mqttPublisher != null) {
                    mqttPublisher.publishMessage(object.toString());
                }

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

    private double lastLongitude = 0.0;
    private double lastLatitude = 0.0;
    private float lastBearing = 0;

    @Override
    public void onLocationChanged(Location location) {
        if (!mGPSToggleButton.isChecked() || !isRunning()) {
            return;
        }

        final double longitude = location.getLongitude();
        final double latitude = location.getLatitude();
        final float bearing = location.getBearing();

        // If there are no updates in the position, do not emit an update.
        if (longitude == lastLongitude && latitude == lastLatitude && bearing == lastBearing) {
            return;
        } else {
            lastBearing = bearing;
            lastLatitude = latitude;
            lastLongitude = longitude;
        }

        final String timestamp = Instant.now().toString();
        ContentValues values = new ContentValues();

        values.put(LocationMeasurement.LocationMeasurementEntry.COLUMN_NAME_LATITUDE, latitude);
        values.put(LocationMeasurement.LocationMeasurementEntry.COLUMN_NAME_LONGITUDE, longitude);
        values.put(LocationMeasurement.LocationMeasurementEntry.COLUMN_NAME_BEARING, bearing);
        values.put(LocationMeasurement.LocationMeasurementEntry.COLUMN_NAME_TIMESTAMP, timestamp);
        values.put(LocationMeasurement.LocationMeasurementEntry.COLUMN_NAME_JOURNEYID, journeyId);

        db.insert(LocationMeasurement.LocationMeasurementEntry.TABLE_NAME, null, values);

        try {
            final JSONObject object = new JSONObject();
            object.put("journeyId", journeyId);
            object.put("longitude", longitude);
            object.put("latitude", latitude);
            object.put("bearing", bearing);
            object.put("timestamp", timestamp);

            if (mqttPublisher != null) {
                mqttPublisher.publishMessage(object.toString());
            }

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

                    // Persist vehicle ID
                    if (info.containsKey("AutoID")) {
                        final int vehicleId = info.getInt("AutoID", 0);
                        editor = sharedPreferences.edit();
                        editor.putInt("vehicleId", vehicleId);
                        editor.apply();
                    }

                    if (info.containsKey("DriverID")) {
                        final int driverId = info.getInt("DriverID", 0);
                        editor = sharedPreferences.edit();
                        editor.putInt("driverId", driverId);
                        editor.apply();
                    }

                    if (info.containsKey("Name")) {
                        final String vehicleName = info.getString("Name", "My Car");
                        editor = sharedPreferences.edit();
                        editor.putString("vehicle_name", vehicleName);
                        editor.apply();
                    }
                } else if (item.getUri().getPath().compareTo("/knowgo/vehicle/journey") == 0) {
                    byte[] rawData = event.getDataItem().getData();
                    DataMap state = DataMap.fromByteArray(rawData);
                    Log.i(TAG, "Journey: " + state.toString());
                } else if (item.getUri().getPath().compareTo("/knowgo/vehicle/state") == 0) {
                    byte[] rawData = event.getDataItem().getData();
                    DataMap state = DataMap.fromByteArray(rawData);
                    Log.i(TAG, "Vehicle State: " + state.toString());

                    if (state.containsKey("fuel_level")) {
                        final double fuel_level = Objects.requireNonNull(state.get("fuel_level"));

                        // Persist last known fuel level
                        editor = sharedPreferences.edit();
                        editor.putInt("fuel_level", (int) fuel_level);
                        editor.apply();

                        // Update the progress bar in the controls view
                        fuelLevelBar.setProgress((int) fuel_level);

                        // Force complication to redraw
                        FuelLevelComplicationProviderService.requestComplicationDataUpdate(this);
                    }
                }
            }
        }
    }

    @Override
    public void onSharedPreferenceChanged(SharedPreferences sharedPreferences, String key) {
        switch (key) {
            case "gps_enabled":
                toggleGPS(mHomeView);
                break;
            case "heartrate_monitoring_enabled":
                toggleHeartRateMonitoring(mHomeView);
                break;
            case "mqtt_broker":
                mqttPublisher.setServerUri(sharedPreferences.getString("mqtt_broker", getString(R.string.default_mqtt_broker)));
                break;
            case "mqtt_topic":
                mqttPublisher.setTopic(sharedPreferences.getString("mqtt_topic", getString(R.string.default_mqtt_topic)));
                break;
            case "vehicle_name":
                updateVehicleName();
                break;
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
        if (notificationsEnabled()) {
            vibrator.vibrate(vibrationPattern, VIBRATION_NO_REPEAT);
            Toast.makeText(context, text, Toast.LENGTH_SHORT).show();
        }
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

    // Check if notifications are enabled
    private boolean notificationsEnabled() {
        return sharedPreferences.getBoolean("notifications_enabled", true);
    }

    // Check if a journey is in progress
    private boolean isRunning() {
        return mStartStopButton.isChecked();
    }

    // Start a new Journey, either from button click or backend notification
    private void onStartJourney() {
        Log.d(TAG, "Starting journey...");
        journeyBegin = Instant.now();
        mStartStopButton.setChecked(true);
        mNoticeView.setText(getResources().getText(R.string.stop_journey));
        startLocationUpdates();
    }

    // Stop a Journey, either from button click or backend notification
    private void onStopJourney() {
        Log.d(TAG, "Stopping journey...");
        stopLocationUpdates();
        mNoticeView.setText(getResources().getText(R.string.start_journey));
        mStartStopButton.setChecked(false);

        Instant journeyEnd = Instant.now();
        Intent intent = new Intent(getApplicationContext(), JourneySummaryActivity.class);
        intent.putExtra("journeyId", journeyId);
        intent.putExtra("journeyBegin", journeyBegin);
        intent.putExtra("journeyEnd", journeyEnd);
        startActivity(intent);
    }

    // Handle journey start/stop from button click
    public void onStartStopJourney(View view) {
        final JSONObject object = new JSONObject();

        try {
            if (isRunning()) {
                // Generate a new JourneyID
                journeyId = UUID.randomUUID().toString();

                onStartJourney();

                object.put("journeyId", journeyId);
                object.put("ignition_status", "run");
                object.put("notification", "Starting simulation from watch");

                // Notify app of journey start event
                new MessageSender("/MessageChannel", object.toString(), getApplicationContext()).start();
            } else {
                object.put("journeyId", journeyId);
                object.put("ignition_status", "stop");
                object.put("notification", "Stopping simulation from watch");

                // Notify app of journey stop event
                new MessageSender("/MessageChannel", object.toString(), getApplicationContext()).start();

                onStopJourney();
            }
        } catch (JSONException e) {
            Log.e(TAG, "Unable to encode JSON object");
        }
    }

    public void navigateToAboutView(View view) {
        mPager.setCurrentItem(R.layout.about_page);
    }

    public void navigateToSettingsView(View view) {
        Intent intent = new Intent(getApplicationContext(), SettingsActivity.class);
        startActivity(intent);
    }

    public void ignitionOn(View view) {
        final TextView ignitionStatus = mControlsView.findViewById(R.id.ignitionStatus);
        final MaterialButton onButton = mControlsView.findViewById(R.id.ignitionOnButton);
        final MaterialButton offButton = mControlsView.findViewById(R.id.ignitionOffButton);

        ignitionStatus.setText(R.string.ignition_on);

        onButton.setBackgroundColor(Color.parseColor("#d7f0cc"));
        onButton.setIconTint(ColorStateList.valueOf(Color.BLACK));
        offButton.setBackgroundColor(Color.WHITE);
        offButton.setIconTint(ColorStateList.valueOf(Color.LTGRAY));
    }

    public void ignitionOff(View view) {
        final TextView ignitionStatus = mControlsView.findViewById(R.id.ignitionStatus);
        final MaterialButton onButton = mControlsView.findViewById(R.id.ignitionOnButton);
        final MaterialButton offButton = mControlsView.findViewById(R.id.ignitionOffButton);

        ignitionStatus.setText(R.string.ignition_off);

        offButton.setBackgroundColor(Color.parseColor("#d7f0cc"));
        offButton.setIconTint(ColorStateList.valueOf(Color.BLACK));
        onButton.setBackgroundColor(Color.WHITE);
        onButton.setIconTint(ColorStateList.valueOf(Color.LTGRAY));
    }

    public void doorsLock(View view) {
        final TextView lockStatus = mControlsView.findViewById(R.id.lockStatus);
        final MaterialButton lockButton = mControlsView.findViewById(R.id.doorLockButton);
        final MaterialButton unlockButton = mControlsView.findViewById(R.id.doorUnlockButton);

        lockStatus.setText(R.string.doors_locked);

        lockButton.setBackgroundColor(Color.parseColor("#d7f0cc"));
        lockButton.setIconTint(ColorStateList.valueOf(Color.BLACK));
        unlockButton.setBackgroundColor(Color.WHITE);
        unlockButton.setIconTint(ColorStateList.valueOf(Color.LTGRAY));
    }

    public void doorsUnlock(View view) {
        final TextView lockStatus = mControlsView.findViewById(R.id.lockStatus);
        final MaterialButton lockButton = mControlsView.findViewById(R.id.doorLockButton);
        final MaterialButton unlockButton = mControlsView.findViewById(R.id.doorUnlockButton);

        lockStatus.setText(R.string.doors_unlocked);

        unlockButton.setBackgroundColor(Color.parseColor("#d7f0cc"));
        unlockButton.setIconTint(ColorStateList.valueOf(Color.BLACK));
        lockButton.setBackgroundColor(Color.WHITE);
        lockButton.setIconTint(ColorStateList.valueOf(Color.LTGRAY));
    }

    public void headlampOn(View view) {
        final TextView headlampStatus = mControlsView.findViewById(R.id.headlampStatus);
        final MaterialButton onButton = mControlsView.findViewById(R.id.headlampOnButton);
        final MaterialButton offButton = mControlsView.findViewById(R.id.headlampOffButton);

        headlampStatus.setText(R.string.headlamp_on);

        onButton.setBackgroundColor(Color.parseColor("#d7f0cc"));
        onButton.setIconTint(ColorStateList.valueOf(Color.BLACK));
        offButton.setBackgroundColor(Color.WHITE);
        offButton.setIconTint(ColorStateList.valueOf(Color.LTGRAY));
    }

    public void headlampOff(View view) {
        final TextView headlampStatus = mControlsView.findViewById(R.id.headlampStatus);
        final MaterialButton onButton = mControlsView.findViewById(R.id.headlampOnButton);
        final MaterialButton offButton = mControlsView.findViewById(R.id.headlampOffButton);

        headlampStatus.setText(R.string.headlamp_off);

        offButton.setBackgroundColor(Color.parseColor("#d7f0cc"));
        offButton.setIconTint(ColorStateList.valueOf(Color.BLACK));
        onButton.setBackgroundColor(Color.WHITE);
        onButton.setIconTint(ColorStateList.valueOf(Color.LTGRAY));
    }

    private void toggleHeartRateMonitoring(View view) {
        final boolean heartrateMonitoringEnabled = sharedPreferences.getBoolean("heartrate_monitoring_enabled", true);
        if (heartrateMonitoringEnabled) {
            mHeartRateToggleButton.setVisibility(View.VISIBLE);
            mHeartRateMeasurement.setVisibility(View.VISIBLE);
        } else {
            mHeartRateToggleButton.setVisibility(View.GONE);
            mHeartRateMeasurement.setVisibility(View.GONE);
        }
    }

    private void toggleGPS(View view) {
        ToggleButton mGPSToggleButton = mHomeView.findViewById(R.id.gpsToggleButton);
        boolean gps_enabled = sharedPreferences.getBoolean("gps_enabled", true);
        boolean gps_available = sharedPreferences.getBoolean("gps_available", false);

        if (gps_available && gps_enabled) {
            mGPSToggleButton.setChecked(true);
            mGPSToggleButton.setEnabled(true);
            mGPSToggleButton.setVisibility(View.VISIBLE);
        } else {
            mGPSToggleButton.setChecked(false);
            mGPSToggleButton.setEnabled(false);
            mGPSToggleButton.setVisibility(View.INVISIBLE);
        }
    }

    private void updateVehicleName() {
        final TextView mVehicleName = mControlsView.findViewById(R.id.vehicle_name);
        final String vehicleName = sharedPreferences.getString("vehicle_name", getString(R.string.vehicle_name_title));

        mVehicleName.setText(vehicleName);
    }
}
