/*
 * Copyright (C) 2026 Alonso Roman
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */
package com.dosse.stickynotes;

import java.awt.Dimension;
import java.awt.GraphicsConfiguration;
import java.awt.GraphicsDevice;
import java.awt.GraphicsEnvironment;
import java.awt.Insets;
import java.awt.MouseInfo;
import java.awt.Point;
import java.awt.PointerInfo;
import java.awt.Rectangle;
import java.awt.Toolkit;
import java.util.ArrayList;
import java.util.List;

final class ScreenBounds {

    private ScreenBounds() {
    }

    static Point pointerLocation(Dimension windowSize, int minimumVisible) {
        try {
            PointerInfo pointer = MouseInfo.getPointerInfo();
            if (pointer != null) {
                return keepVisible(pointer.getLocation(), windowSize, minimumVisible);
            }
        } catch (RuntimeException exception) {
            // Use the primary screen below.
        }

        List<Rectangle> screens = usableScreens();
        if (screens.isEmpty()) {
            return new Point(40, 40);
        }
        Rectangle primary = screens.get(0);
        return new Point(primary.x + 40, primary.y + 40);
    }

    /**
     * Returns the size of the rectangle that encloses every monitor. It is used as the
     * upper limit for a note, so a window can never be asked to grow past the desktop.
     *
     * @return width and height of the whole desktop
     */
    static Dimension desktopSize() {
        List<Rectangle> screens = usableScreens();
        if (screens.isEmpty()) {
            return new Dimension(1024, 768);
        }

        Rectangle union = new Rectangle(screens.get(0));
        for (Rectangle screen : screens) {
            union = union.union(screen);
        }
        return new Dimension(Math.max(1, union.width), Math.max(1, union.height));
    }

    /**
     * Returns the size of the smallest monitor, which is the one that decides how large
     * the text may grow before it stops being usable.
     *
     * @return width and height of the smallest monitor
     */
    static Dimension smallestScreenSize() {
        List<Rectangle> screens = usableScreens();
        if (screens.isEmpty()) {
            return new Dimension(1024, 768);
        }

        Rectangle smallest = screens.get(0);
        long smallestArea = (long) smallest.width * smallest.height;
        for (Rectangle screen : screens) {
            long area = (long) screen.width * screen.height;
            if (area < smallestArea) {
                smallest = screen;
                smallestArea = area;
            }
        }
        return new Dimension(Math.max(1, smallest.width), Math.max(1, smallest.height));
    }

    static Point keepVisible(Point requested, Dimension windowSize, int minimumVisible) {
        return keepVisible(requested, windowSize, minimumVisible, usableScreens());
    }

    static Point keepVisible(Point requested, Dimension windowSize, int minimumVisible, List<Rectangle> screens) {
        if (requested == null || screens.isEmpty()) {
            return requested == null ? new Point(0, 0) : new Point(requested);
        }

        int width = Math.max(1, windowSize.width);
        int height = Math.max(1, windowSize.height);
        int visibleWidth = Math.min(Math.max(1, minimumVisible), width);
        int visibleHeight = Math.min(Math.max(1, minimumVisible), height);
        Rectangle window = new Rectangle(requested.x, requested.y, width, height);

        boolean intersectsScreen = false;
        for (Rectangle screen : screens) {
            Rectangle intersection = window.intersection(screen);
            intersectsScreen |= intersection.width > 0 && intersection.height > 0;
            if (intersection.width >= visibleWidth && intersection.height >= visibleHeight) {
                return new Point(requested);
            }
        }

        Rectangle target = intersectsScreen
                ? screenWithLargestIntersection(window, screens)
                : closestScreen(window, screens);
        int minimumX;
        int maximumX;
        int minimumY;
        int maximumY;

        if (intersectsScreen) {
            minimumX = target.x - width + visibleWidth;
            maximumX = target.x + target.width - visibleWidth;
            minimumY = target.y - height + visibleHeight;
            maximumY = target.y + target.height - visibleHeight;
        } else {
            minimumX = target.x;
            maximumX = target.x + Math.max(0, target.width - width);
            minimumY = target.y;
            maximumY = target.y + Math.max(0, target.height - height);
        }

        return new Point(
                clamp(requested.x, minimumX, maximumX),
                clamp(requested.y, minimumY, maximumY)
        );
    }

    private static Rectangle closestScreen(Rectangle window, List<Rectangle> screens) {
        double windowCenterX = window.getCenterX();
        double windowCenterY = window.getCenterY();
        Rectangle closest = screens.get(0);
        double closestDistance = Double.MAX_VALUE;

        for (Rectangle screen : screens) {
            double horizontalDistance = windowCenterX - screen.getCenterX();
            double verticalDistance = windowCenterY - screen.getCenterY();
            double distance = horizontalDistance * horizontalDistance + verticalDistance * verticalDistance;
            if (distance < closestDistance) {
                closest = screen;
                closestDistance = distance;
            }
        }
        return closest;
    }

    private static Rectangle screenWithLargestIntersection(Rectangle window, List<Rectangle> screens) {
        Rectangle bestMatch = screens.get(0);
        long largestArea = -1;
        for (Rectangle screen : screens) {
            Rectangle intersection = window.intersection(screen);
            long area = (long) Math.max(0, intersection.width) * Math.max(0, intersection.height);
            if (area > largestArea) {
                bestMatch = screen;
                largestArea = area;
            }
        }
        return bestMatch;
    }

    private static int clamp(int value, int minimum, int maximum) {
        if (minimum > maximum) {
            return minimum;
        }
        return Math.max(minimum, Math.min(value, maximum));
    }

    private static List<Rectangle> usableScreens() {
        List<Rectangle> screens = new ArrayList<>();
        try {
            GraphicsEnvironment environment = GraphicsEnvironment.getLocalGraphicsEnvironment();
            GraphicsDevice primary = environment.getDefaultScreenDevice();
            addScreen(screens, primary.getDefaultConfiguration());

            for (GraphicsDevice device : environment.getScreenDevices()) {
                if (!device.equals(primary)) {
                    addScreen(screens, device.getDefaultConfiguration());
                }
            }
        } catch (RuntimeException exception) {
            // An empty list lets callers keep their requested coordinates.
        }
        return screens;
    }

    private static void addScreen(List<Rectangle> screens, GraphicsConfiguration configuration) {
        Rectangle bounds = new Rectangle(configuration.getBounds());
        try {
            Insets insets = Toolkit.getDefaultToolkit().getScreenInsets(configuration);
            bounds.x += insets.left;
            bounds.y += insets.top;
            bounds.width -= insets.left + insets.right;
            bounds.height -= insets.top + insets.bottom;
        } catch (RuntimeException exception) {
            // Full monitor bounds are still safe if insets are unavailable.
        }
        screens.add(bounds);
    }
}
