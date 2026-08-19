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

import java.awt.BorderLayout;
import java.awt.Dimension;
import java.awt.FlowLayout;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.text.MessageFormat;
import java.util.ResourceBundle;
import javax.swing.BorderFactory;
import javax.swing.Box;
import javax.swing.JButton;
import javax.swing.JDialog;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JSlider;
import javax.swing.JSpinner;
import javax.swing.SpinnerNumberModel;
import javax.swing.WindowConstants;

/**
 * Lets the user pick any zoom level inside the range NoteBot considers usable.
 * The change is previewed on the note while the dialog is open and is undone if the
 * user cancels.
 *
 * @author Alonso Roman
 */
final class ZoomDialog extends JDialog {

    private static final long serialVersionUID = 1L;

    private static final ResourceBundle MESSAGES = ResourceBundle.getBundle("com/dosse/stickynotes/locale/locale");

    /** Slider positions. The slider is logarithmic so the whole range stays usable. */
    private static final int SLIDER_RESOLUTION = 1000;

    private final Note note;
    private final float originalScale;
    private final JSlider slider;
    private final JSpinner spinner;
    private final int minimumPercent;
    private final int maximumPercent;

    private boolean accepted;
    private boolean synchronising;

    private ZoomDialog(Note note) {
        super(note, MESSAGES.getString("ZOOM_TITLE"), true);
        this.note = note;
        this.originalScale = note.getTextScale();

        minimumPercent = Math.max(1, Math.round(Main.MIN_TEXT_SCALE * 100f));
        maximumPercent = Math.max(minimumPercent + 1, Math.round(Main.MAX_TEXT_SCALE * 100f));
        int currentPercent = clampPercent(Math.round(originalScale * 100f), minimumPercent, maximumPercent);

        setDefaultCloseOperation(WindowConstants.DISPOSE_ON_CLOSE);
        addWindowListener(new WindowAdapter() {
            @Override
            public void windowClosed(WindowEvent event) {
                if (!accepted) {
                    ZoomDialog.this.note.setTextScale(originalScale);
                }
            }
        });

        slider = new JSlider(0, SLIDER_RESOLUTION, percentToSlider(currentPercent));
        slider.setMajorTickSpacing(SLIDER_RESOLUTION / 5);
        slider.setPaintTicks(true);
        slider.setPreferredSize(new Dimension((int) (320 * Main.SCALE), slider.getPreferredSize().height));

        spinner = new JSpinner(new SpinnerNumberModel(currentPercent, minimumPercent, maximumPercent, 5));
        spinner.setPreferredSize(new Dimension((int) (80 * Main.SCALE), (int) (26 * Main.SCALE)));

        slider.addChangeListener(event -> {
            if (synchronising) {
                return;
            }
            synchronising = true;
            try {
                int percent = sliderToPercent(slider.getValue());
                spinner.setValue(percent);
                applyPercent(percent);
            } finally {
                synchronising = false;
            }
        });

        spinner.addChangeListener(event -> {
            if (synchronising) {
                return;
            }
            synchronising = true;
            try {
                int value = clampPercent((Integer) spinner.getValue(), minimumPercent, maximumPercent);
                slider.setValue(percentToSlider(value));
                applyPercent(value);
            } finally {
                synchronising = false;
            }
        });

        JLabel range = new JLabel(MessageFormat.format(
                MESSAGES.getString("ZOOM_RANGE"),
                minimumPercent,
                maximumPercent
        ));
        range.setFont(Main.SMALL_FONT);

        JPanel controls = new JPanel(new FlowLayout(FlowLayout.LEFT, (int) (8 * Main.SCALE), 0));
        controls.add(new JLabel(MESSAGES.getString("ZOOM_LABEL")));
        controls.add(spinner);
        controls.add(new JLabel("%"));

        JPanel content = new JPanel();
        content.setLayout(new BorderLayout((int) (8 * Main.SCALE), (int) (8 * Main.SCALE)));
        content.setBorder(BorderFactory.createEmptyBorder(
                (int) (12 * Main.SCALE), (int) (12 * Main.SCALE),
                (int) (12 * Main.SCALE), (int) (12 * Main.SCALE)));
        content.add(controls, BorderLayout.NORTH);
        content.add(slider, BorderLayout.CENTER);
        content.add(range, BorderLayout.SOUTH);

        JButton reset = new JButton(MESSAGES.getString("ZOOM_RESET"));
        reset.addActionListener(event -> {
            int value = clampPercent(100, minimumPercent, maximumPercent);
            synchronising = true;
            try {
                slider.setValue(percentToSlider(value));
                spinner.setValue(value);
            } finally {
                synchronising = false;
            }
            applyPercent(value);
        });

        JButton accept = new JButton(MESSAGES.getString("ZOOM_OK"));
        accept.addActionListener(event -> {
            accepted = true;
            Main.saveState();
            dispose();
        });

        JButton cancel = new JButton(MESSAGES.getString("ZOOM_CANCEL"));
        cancel.addActionListener(event -> dispose());

        JPanel buttons = new JPanel(new FlowLayout(FlowLayout.RIGHT, (int) (8 * Main.SCALE), (int) (8 * Main.SCALE)));
        buttons.add(reset);
        buttons.add(Box.createHorizontalStrut((int) (16 * Main.SCALE)));
        buttons.add(accept);
        buttons.add(cancel);

        getContentPane().setLayout(new BorderLayout());
        getContentPane().add(content, BorderLayout.CENTER);
        getContentPane().add(buttons, BorderLayout.SOUTH);
        getRootPane().setDefaultButton(accept);

        setResizable(false);
        // A pinned note stays above other windows, so its own dialog has to follow it.
        setAlwaysOnTop(note.isAlwaysOnTop());
        pack();
        setLocationRelativeTo(note);
    }

    private void applyPercent(int percent) {
        note.setTextScale(percent / 100f);
    }

    private int percentToSlider(int percent) {
        double position = Math.log((double) percent / minimumPercent)
                / Math.log((double) maximumPercent / minimumPercent);
        return Math.max(0, Math.min(SLIDER_RESOLUTION, (int) Math.round(position * SLIDER_RESOLUTION)));
    }

    private int sliderToPercent(int position) {
        double ratio = (double) position / SLIDER_RESOLUTION;
        double percent = minimumPercent * Math.pow((double) maximumPercent / minimumPercent, ratio);
        return clampPercent((int) Math.round(percent), minimumPercent, maximumPercent);
    }

    private static int clampPercent(int value, int minimum, int maximum) {
        return Math.max(minimum, Math.min(value, maximum));
    }

    /**
     * Opens the zoom dialog for a note.
     *
     * @param note note whose text size is being changed
     */
    static void display(Note note) {
        new ZoomDialog(note).setVisible(true);
    }
}
