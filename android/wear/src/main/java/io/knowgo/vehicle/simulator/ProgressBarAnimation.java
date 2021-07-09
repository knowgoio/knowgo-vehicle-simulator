package io.knowgo.vehicle.simulator;

import android.view.animation.Animation;
import android.view.animation.Transformation;
import android.widget.ProgressBar;

/**
 * Animation extension for ProgressBar, adapted from:
 * https://stackoverflow.com/a/18015071/11355043
 */
public class ProgressBarAnimation extends Animation {
    private final ProgressBar progressBar;
    private final float from;
    private final float to;

    public ProgressBarAnimation(ProgressBar progressBar, float from, float to) {
        super();
        this.progressBar = progressBar;
        this.from = from;
        this.to = to;
    }

    @Override
    protected void applyTransformation(float interpolatedTime, Transformation t) {
        super.applyTransformation(interpolatedTime, t);
        float value = from + (to - from) * interpolatedTime;
        progressBar.setProgress((int) value);
    }
}