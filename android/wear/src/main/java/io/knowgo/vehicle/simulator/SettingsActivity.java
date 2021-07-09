package io.knowgo.vehicle.simulator;

import android.annotation.SuppressLint;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.Switch;
import android.widget.ToggleButton;

import androidx.annotation.Nullable;
import androidx.fragment.app.FragmentActivity;
import androidx.preference.PreferenceManager;

import com.google.android.material.textfield.TextInputEditText;

import java.util.Objects;

@SuppressLint("UseSwitchCompatOrMaterialCode")
public class SettingsActivity extends FragmentActivity {
    private final static String TAG = SettingsActivity.class.getSimpleName();
    private View mSettingsView;
    private View mHomeView;
    private Switch mHeartRateSwitch;
    private Switch mNotificationsSwitch;
    private Switch mGPSSwitch;
    private int minHeartRate, maxHeartRate;
    private TextInputEditText mMqttBroker;
    private TextInputEditText mMqttTopic;
    private Switch mMqttSettingsSwitch;
    SharedPreferences sharedPreferences;
    SharedPreferences.Editor editor;

    @SuppressLint("InflateParams")
    @Override
    public void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        mSettingsView = getLayoutInflater().inflate(R.layout.settings_page, null);
        setContentView(mSettingsView);

        mHomeView = getLayoutInflater().inflate(R.layout.activity_main, null);

        sharedPreferences = PreferenceManager.getDefaultSharedPreferences(getApplicationContext());
        mNotificationsSwitch = mSettingsView.findViewById(R.id.switchNotifications);
        final boolean notificationsOpt = sharedPreferences.getBoolean("notifications_enabled", true);
        mNotificationsSwitch.setChecked(notificationsOpt);

        mGPSSwitch = mSettingsView.findViewById(R.id.switchWatchTelemetry);
        final boolean gpsOpt = sharedPreferences.getBoolean("gps_enabled", true);
        mGPSSwitch.setChecked(gpsOpt);
        toggleGPS(mSettingsView);

        mHeartRateSwitch = mSettingsView.findViewById(R.id.switchHeartRate);
        TextInputEditText mMinHeartRate = mSettingsView.findViewById(R.id.minHeartRate);
        TextInputEditText mMaxHeartRate = mSettingsView.findViewById(R.id.maxHeartRate);

        if (mHeartRateSwitch.isChecked()) {
            minHeartRate = sharedPreferences.getInt("heartrate_min", Integer.parseInt(Objects.requireNonNull(mMinHeartRate.getText()).toString()));
            maxHeartRate = sharedPreferences.getInt("heartrate_max", Integer.parseInt(Objects.requireNonNull(mMaxHeartRate.getText()).toString()));

            mMinHeartRate.setText(String.valueOf(minHeartRate));
            mMaxHeartRate.setText(String.valueOf(maxHeartRate));
        }

        toggleHeartRateSettings(mSettingsView);

        mMinHeartRate.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {
            }

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
            }

            @Override
            public void afterTextChanged(Editable s) {
                try {
                    int newMinValue = Integer.parseInt(s.toString());
                    editor = sharedPreferences.edit();
                    editor.putInt("heartrate_min", newMinValue);
                    editor.apply();

                    minHeartRate = newMinValue;
                } catch (NumberFormatException ignored) {}
            }
        });

        mMaxHeartRate.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {
            }

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
            }

            @Override
            public void afterTextChanged(Editable s) {
                try {
                    int newMaxValue = Integer.parseInt(s.toString());
                    editor = sharedPreferences.edit();
                    editor.putInt("heartrate_max", newMaxValue);
                    editor.apply();

                    maxHeartRate = newMaxValue;
                } catch (NumberFormatException ignored) {}
            }
        });

        mMqttSettingsSwitch = mSettingsView.findViewById(R.id.switchMqttSettings);

        final boolean mqttEnabled = sharedPreferences.getBoolean("mqtt_enabled", mMqttSettingsSwitch.isChecked());
        mMqttSettingsSwitch.setChecked(mqttEnabled);
        mMqttBroker = mSettingsView.findViewById(R.id.mqttBroker);
        mMqttTopic = mSettingsView.findViewById(R.id.mqttTopic);
        toggleMqttSettings(mSettingsView);
        
        mMqttBroker.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {
            }

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
            }

            @Override
            public void afterTextChanged(Editable s) {
                editor = sharedPreferences.edit();
                editor.putString("mqtt_broker", s.toString());
                editor.apply();
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
                editor = sharedPreferences.edit();
                editor.putString("mqtt_topic", s.toString());
                editor.apply();
            }
        });
    }

    // Collapse/expand the MQTT Settings depending on the switch position
    public void toggleMqttSettings(View view) {
        final LinearLayout mMqttBrokerSetting = mSettingsView.findViewById(R.id.mqttBrokerSetting);
        final LinearLayout mMqttTopicSetting = mSettingsView.findViewById(R.id.mqttTopicSetting);

        if (mMqttSettingsSwitch.isChecked()) {
            final String mqttBroker = sharedPreferences.getString("mqtt_broker", Objects.requireNonNull(mMqttBroker.getText()).toString());
            final String mqttTopic = sharedPreferences.getString("mqtt_topic", Objects.requireNonNull(mMqttTopic.getText()).toString());

            mMqttBroker.setText(mqttBroker);
            mMqttTopic.setText(mqttTopic);

            mMqttBrokerSetting.setVisibility(View.VISIBLE);
            mMqttTopicSetting.setVisibility(View.VISIBLE);
        } else {
            mMqttBrokerSetting.setVisibility(View.GONE);
            mMqttTopicSetting.setVisibility(View.GONE);
        }

        editor = sharedPreferences.edit();
        editor.putBoolean("mqtt_enabled", mMqttSettingsSwitch.isChecked());
        editor.apply();
    }

    // Collapse/expand the heart rate monitoring settings depending on the switch position
    public void toggleHeartRateSettings(View view) {
        final LinearLayout mMinHeartRateSetting = mSettingsView.findViewById(R.id.minHeartRateSetting);
        final LinearLayout mMaxHeartRateSetting = mSettingsView.findViewById(R.id.maxHearRateSetting);

        if (mHeartRateSwitch.isChecked()) {
            mMinHeartRateSetting.setVisibility(View.VISIBLE);
            mMaxHeartRateSetting.setVisibility(View.VISIBLE);
        } else {
            mMinHeartRateSetting.setVisibility(View.GONE);
            mMaxHeartRateSetting.setVisibility(View.GONE);
        }

        editor = sharedPreferences.edit();
        editor.putBoolean("heartrate_monitoring_enabled", mHeartRateSwitch.isChecked());
        editor.apply();
    }

    // Toggle global GPS telemetry setting
    public void toggleGPS(View view) {
        ToggleButton mGPSToggleButton = mHomeView.findViewById(R.id.gpsToggleButton);

        if (mGPSSwitch.isChecked()) {
            mGPSToggleButton.setChecked(true);
            mGPSToggleButton.setEnabled(true);
            mGPSToggleButton.setVisibility(View.VISIBLE);
        } else {
            mGPSToggleButton.setChecked(false);
            mGPSToggleButton.setEnabled(false);
            mGPSToggleButton.setVisibility(View.INVISIBLE);
        }

        editor = sharedPreferences.edit();
        editor.putBoolean("gps_enabled", mGPSSwitch.isChecked());
        editor.apply();
    }

    // Toggle notifications
    public void toggleNotifications(View view) {
        editor = sharedPreferences.edit();
        editor.putBoolean("notifications_enabled", mNotificationsSwitch.isChecked());
        editor.apply();
    }
}
