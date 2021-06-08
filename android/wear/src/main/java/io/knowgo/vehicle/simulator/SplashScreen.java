package io.knowgo.vehicle.simulator;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.util.Log;

public class SplashScreen extends Activity {
    private static final String TAG = MainActivity.class.getName();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        setContentView(R.layout.splash_screen);
        Log.d(TAG, "Showing splash screen");

        new Handler().postDelayed(this::initMainActivity, 2000);
    }

    private void initMainActivity() {
        Log.d(TAG, "Starting main activity");
        Intent intent = new Intent(this, MainActivity.class);
        startActivity(intent);
        finish();
    }
}
