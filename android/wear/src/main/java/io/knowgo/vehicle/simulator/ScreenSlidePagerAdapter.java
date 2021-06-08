package io.knowgo.vehicle.simulator;

import android.view.View;

import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentActivity;
import androidx.viewpager2.adapter.FragmentStateAdapter;

public class ScreenSlidePagerAdapter extends FragmentStateAdapter {
    private final ScreenSlidePageFragment[] fragments;

    public ScreenSlidePagerAdapter(FragmentActivity fa, View ... allViews) {
        super(fa);
        this.fragments = new ScreenSlidePageFragment[allViews.length];
        for (int i = 0; i < allViews.length; i++) {
            this.fragments[i] = new ScreenSlidePageFragment(allViews[i]);
        }
    }

    @NonNull
    @Override
    public Fragment createFragment(int position) {
        return this.fragments[position];
    }

    @Override
    public int getItemCount() {
        return this.fragments.length;
    }
}