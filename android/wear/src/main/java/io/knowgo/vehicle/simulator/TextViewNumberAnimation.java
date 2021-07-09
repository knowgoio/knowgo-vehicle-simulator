package io.knowgo.vehicle.simulator;

import android.view.animation.Animation;
import android.view.animation.Transformation;
import android.widget.TextView;

/**
 * Animation extension for TextView with a numerical value
 */
public class TextViewNumberAnimation extends Animation {
    private final TextView textView;
    private final float from;
    private final float to;

    public TextViewNumberAnimation(TextView textView, float from, float to) {
        super();
        this.textView = textView;
        this.from = from;
        this.to = to;
    }

    @Override
    protected void applyTransformation(float interpolatedTime, Transformation t) {
        super.applyTransformation(interpolatedTime, t);
        float value = from + (to - from) * interpolatedTime;
        textView.setText(String.valueOf((int) value));
    }
}