package io.knowgo.vehicle.simulator;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;

public class ScreenSlidePageFragment extends Fragment {
    private final View view;
    public ScreenSlidePageFragment(View view) {
        this.view = view;
    }

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        return view;
    }
}
