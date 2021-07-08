package io.knowgo.vehicle.simulator.util;

/**
 * Simple implementation of the Haversine Formula for calculating the distance between two
 * sets of coordinates.
 *
 * Cribbed from https://github.com/jasonwinn/haversine, (C) 2013 Jason Winn
 *
 * Call in a static context:
 * HaversineDistance.distance(47.6788206, -122.3271205,
 *                            47.6788206, -122.5271205)
 * --> 14.973211163437774 [km]
 */
public class HaversineDistance {
    private static final double EARTH_RADIUS = 6371.0088;

    public static double haversin(double val) {
        return Math.pow(Math.sin(val / 2), 2);
    }

    public static double distance(double startLat, double startLng,
                                  double endLat, double endLng) {
        double dLat = Math.toRadians((endLat - startLat));
        double dLng = Math.toRadians((endLng - startLng));

        startLat = Math.toRadians(startLat);
        endLat   = Math.toRadians(endLat);

        double a = haversin(dLat) + Math.cos(startLat) * Math.cos(endLat) * haversin(dLng);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

        return EARTH_RADIUS * c;
    }

}
