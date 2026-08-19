/*
 * Copyright (C) 2026 Alonso Roman
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */
package com.dosse.stickynotes;

import java.awt.BasicStroke;
import java.awt.Color;
import java.awt.Component;
import java.awt.Graphics;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.Shape;
import java.awt.geom.AffineTransform;
import java.awt.geom.Area;
import java.awt.geom.Line2D;
import java.awt.geom.Rectangle2D;
import java.awt.geom.RoundRectangle2D;
import java.io.Serializable;
import javax.swing.Icon;

/**
 * Pushpin drawn with Java2D so it stays sharp at any scale and always matches the
 * colour scheme of its note. A bundled glyph is avoided on purpose because the button
 * font does not cover the pushpin code points on every system.
 *
 * @author Alonso Roman
 */
final class PinIcon implements Icon, Serializable {

    private static final long serialVersionUID = 1L;

    private static final int DESIGN_SIZE = 100;
    private static final Shape PIN_SHAPE = buildPinShape();

    private final int size;
    private Color color;
    private boolean pinned;

    PinIcon(int size, Color color, boolean pinned) {
        this.size = Math.max(8, size);
        this.color = color;
        this.pinned = pinned;
    }

    void setColor(Color color) {
        this.color = color;
    }

    void setPinned(boolean pinned) {
        this.pinned = pinned;
    }

    @Override
    public int getIconWidth() {
        return size;
    }

    @Override
    public int getIconHeight() {
        return size;
    }

    @Override
    public void paintIcon(Component component, Graphics graphics, int x, int y) {
        Graphics2D canvas = (Graphics2D) graphics.create();
        try {
            canvas.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
            canvas.setRenderingHint(RenderingHints.KEY_STROKE_CONTROL, RenderingHints.VALUE_STROKE_PURE);
            canvas.translate(x, y);
            canvas.scale((double) size / DESIGN_SIZE, (double) size / DESIGN_SIZE);
            canvas.setColor(color == null ? Color.DARK_GRAY : color);

            if (pinned) {
                canvas.fill(PIN_SHAPE);
            } else {
                canvas.setStroke(new BasicStroke(7f, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND));
                canvas.draw(PIN_SHAPE);
            }
        } finally {
            canvas.dispose();
        }
    }

    private static Shape buildPinShape() {
        Area pin = new Area(new RoundRectangle2D.Float(30f, 8f, 40f, 22f, 12f, 12f));
        pin.add(new Area(new Rectangle2D.Float(41f, 26f, 18f, 32f)));
        pin.add(new Area(new RoundRectangle2D.Float(20f, 54f, 60f, 12f, 6f, 6f)));
        pin.add(new Area(new BasicStroke(6f, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND)
                .createStrokedShape(new Line2D.Float(50f, 64f, 50f, 92f))));

        // Centre the artwork inside the design square.
        Area centred = new Area(pin);
        centred.transform(AffineTransform.getTranslateInstance(0d, -2d));
        return centred;
    }
}
