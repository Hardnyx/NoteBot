/*
 * Copyright (C) 2016 Federico Dossena
 * Modifications Copyright (C) 2026 Alonso Roman
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 */
package com.dosse.stickynotes;

import java.awt.Color;
import java.awt.Dimension;
import java.awt.EventQueue;
import java.awt.Font;
import java.awt.GraphicsEnvironment;
import java.awt.Toolkit;
import java.io.EOFException;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.nio.channels.FileChannel;
import java.nio.channels.FileLock;
import java.nio.channels.OverlappingFileLockException;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.nio.file.StandardOpenOption;
import java.text.MessageFormat;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.ResourceBundle;
import java.util.logging.FileHandler;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.logging.SimpleFormatter;
import javax.swing.JOptionPane;
import javax.swing.SwingUtilities;
import javax.swing.Timer;
import javax.swing.UIManager;
import javax.swing.plaf.ColorUIResource;
import javax.swing.plaf.FontUIResource;
import javax.swing.plaf.metal.MetalLookAndFeel;
import javax.swing.plaf.metal.MetalTheme;

/**
 * Coordinates the note windows, local storage and application lifecycle.
 *
 * @author Federico Dossena
 * @author Alonso Roman
 */
public final class Main {

    public static final String VERSION = "1.7.1";

    private static final Logger LOGGER = Logger.getLogger(Main.class.getName());
    private static final ResourceBundle MESSAGES = ResourceBundle.getBundle("com/dosse/stickynotes/locale/locale");
    private static final List<Note> NOTES = new ArrayList<>();
    private static final int MAX_NOTE_COUNT = 10000;

    private static Path appDirectory;
    private static Path storagePath;
    private static Path backupPath;
    private static Path secondBackupPath;
    private static Path lockPath;

    private static FileChannel lockChannel;
    private static FileLock instanceLock;
    private static boolean noAutoCreate;
    private static boolean saveErrorShown;

    private Main() {
    }

    /**
     * Saves all open notes using the storage format from the original releases.
     */
    public static void saveState() {
        synchronized (NOTES) {
            try {
                writeState();
                saveErrorShown = false;
            } catch (IOException exception) {
                LOGGER.log(Level.SEVERE, "Could not save notes", exception);
                if (!saveErrorShown) {
                    saveErrorShown = true;
                    showMessage(MESSAGES.getString("SAVE_ERROR"), JOptionPane.ERROR_MESSAGE);
                }
            }
        }
    }

    private static void writeState() throws IOException {
        Path temporaryPath = storagePath.resolveSibling("sticky.dat.tmp");

        try (ObjectOutputStream output = new ObjectOutputStream(new FileOutputStream(temporaryPath.toFile()))) {
            output.writeObject(SCALE);
            output.writeObject(NOTES.size());
            for (Note note : NOTES) {
                output.writeObject(note.getPreferredLocation());
                output.writeObject(note.getSize());
                output.writeObject(note.getColorScheme());
                output.writeObject(note.getText());
            }
            for (Note note : NOTES) {
                output.writeObject(note.getTextScale());
            }
        }

        moveIfPresent(backupPath, secondBackupPath);
        moveIfPresent(storagePath, backupPath);
        moveReplacing(temporaryPath, storagePath);
    }

    private static void moveIfPresent(Path source, Path destination) throws IOException {
        if (Files.exists(source)) {
            moveReplacing(source, destination);
        }
    }

    private static void moveReplacing(Path source, Path destination) throws IOException {
        try {
            Files.move(source, destination, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
        } catch (AtomicMoveNotSupportedException exception) {
            Files.move(source, destination, StandardCopyOption.REPLACE_EXISTING);
        }
    }

    private static boolean attemptLoad(Path file) {
        if (!Files.isRegularFile(file)) {
            return false;
        }

        List<Note> loadedNotes = new ArrayList<>();
        try (ObjectInputStream input = new ObjectInputStream(new FileInputStream(file.toFile()))) {
            Object storedScaleValue = input.readObject();
            Object noteCountValue = input.readObject();
            if (!(storedScaleValue instanceof Float) || !(noteCountValue instanceof Integer)) {
                throw new IOException("Invalid NoteBot storage header");
            }

            float storedScale = (Float) storedScaleValue;
            int noteCount = (Integer) noteCountValue;
            if (storedScale <= 0 || noteCount < 0 || noteCount > MAX_NOTE_COUNT) {
                throw new IOException("Invalid NoteBot storage values");
            }

            float scaleMultiplier = SCALE / storedScale;
            for (int index = 0; index < noteCount; index++) {
                Object locationValue = input.readObject();
                Object sizeValue = input.readObject();
                Object colorValue = input.readObject();
                Object textValue = input.readObject();

                if (!(locationValue instanceof java.awt.Point)
                        || !(sizeValue instanceof Dimension)
                        || !(colorValue instanceof Color[])
                        || !(textValue instanceof String)
                        || ((Color[]) colorValue).length != 8) {
                    throw new IOException("Invalid note data");
                }

                Dimension storedSize = (Dimension) sizeValue;
                Dimension scaledSize = new Dimension(
                        Math.max(1, Math.round(storedSize.width * scaleMultiplier)),
                        Math.max(1, Math.round(storedSize.height * scaleMultiplier))
                );

                Note note = new Note();
                note.setSize(scaledSize);
                note.setLocation((java.awt.Point) locationValue);
                note.setColorScheme((Color[]) colorValue);
                note.setText((String) textValue);
                loadedNotes.add(note);
            }

            for (Note note : loadedNotes) {
                try {
                    Object textScaleValue = input.readObject();
                    if (textScaleValue instanceof Float) {
                        note.setTextScale((Float) textScaleValue);
                    }
                } catch (EOFException exception) {
                    break;
                }
            }
        } catch (IOException | ClassNotFoundException | RuntimeException exception) {
            disposeNotes(loadedNotes);
            LOGGER.log(Level.WARNING, "Could not read " + file, exception);
            return false;
        }

        synchronized (NOTES) {
            NOTES.addAll(loadedNotes);
            if (NOTES.isEmpty() && !noAutoCreate) {
                NOTES.add(createNote());
            }
            for (Note note : NOTES) {
                note.setVisible(true);
            }
        }
        return true;
    }

    private static void disposeNotes(List<Note> notes) {
        for (Note note : notes) {
            note.setVisible(false);
            note.dispose();
        }
    }

    private static boolean loadState() {
        return attemptLoad(storagePath)
                || attemptLoad(backupPath)
                || attemptLoad(secondBackupPath);
    }

    /**
     * Creates and displays a new empty note.
     *
     * @return the new note
     */
    public static Note newNote() {
        synchronized (NOTES) {
            Note note = createNote();
            NOTES.add(note);
            note.setVisible(true);
            saveState();
            return note;
        }
    }

    private static Note createNote() {
        return new Note();
    }

    /**
     * Deletes a note and closes the application when no notes remain.
     *
     * @param note note to delete
     */
    public static void delete(Note note) {
        synchronized (NOTES) {
            NOTES.remove(note);
            note.setVisible(false);
            note.dispose();
            saveState();
            if (NOTES.isEmpty()) {
                System.exit(0);
            }
        }
    }

    public static void bringToFront(Note note) {
        synchronized (NOTES) {
            NOTES.remove(note);
            NOTES.add(note);
        }
    }

    private static boolean acquireInstanceLock() throws IOException {
        lockChannel = FileChannel.open(lockPath, StandardOpenOption.CREATE, StandardOpenOption.WRITE);
        try {
            instanceLock = lockChannel.tryLock();
        } catch (OverlappingFileLockException exception) {
            instanceLock = null;
        }

        if (instanceLock != null) {
            return true;
        }

        lockChannel.close();
        lockChannel = null;
        return false;
    }

    private static void releaseInstanceLock() {
        try {
            if (instanceLock != null && instanceLock.isValid()) {
                instanceLock.release();
            }
        } catch (IOException exception) {
            LOGGER.log(Level.FINE, "Could not release instance lock", exception);
        }
        try {
            if (lockChannel != null && lockChannel.isOpen()) {
                lockChannel.close();
            }
        } catch (IOException exception) {
            LOGGER.log(Level.FINE, "Could not close instance lock", exception);
        }
    }

    private static Font loadFont(String path, int fallbackStyle) {
        try (InputStream input = Main.class.getResourceAsStream(path)) {
            if (input != null) {
                return Font.createFont(Font.TRUETYPE_FONT, input);
            }
        } catch (Exception exception) {
            LOGGER.log(Level.WARNING, "Could not load font " + path, exception);
        }
        return new Font(Font.SANS_SERIF, fallbackStyle, 12);
    }

    private static float calculateScale() {
        try {
            float dpi = Toolkit.getDefaultToolkit().getScreenResolution();
            return Math.max(64f, dpi) / 80f;
        } catch (RuntimeException exception) {
            return 1f;
        }
    }

    public static final float SCALE = calculateScale();
    public static final float TEXT_SIZE = 12f * SCALE;
    public static final float TEXT_SIZE_SMALL = 11f * SCALE;
    public static final float BUTTON_TEXT_SIZE = 11f * SCALE;

    public static final Font BASE_FONT = loadFont("/com/dosse/stickynotes/fonts/OpenSans-Regular-Twemoji.ttf", Font.PLAIN).deriveFont(TEXT_SIZE);
    public static final Font SMALL_FONT = BASE_FONT.deriveFont(TEXT_SIZE_SMALL);
    public static final Font BUTTON_FONT = loadFont("/com/dosse/stickynotes/fonts/OpenSans-Bold.ttf", Font.BOLD).deriveFont(BUTTON_TEXT_SIZE);

    private static final ColorUIResource METAL_PRIMARY = new ColorUIResource(220, 220, 220);
    private static final ColorUIResource METAL_SECONDARY = new ColorUIResource(240, 240, 240);
    private static final ColorUIResource DEFAULT_BACKGROUND = new ColorUIResource(255, 255, 255);

    public static void main(String[] args) {
        noAutoCreate = containsArgument(args, "-autostartup");

        try {
            initialiseApplicationFiles();
            configureLogging();
            configureUncaughtExceptionHandler();

            if (!acquireInstanceLock()) {
                if (!noAutoCreate) {
                    showMessage(MESSAGES.getString("ALREADY_RUNNING"), JOptionPane.INFORMATION_MESSAGE);
                }
                return;
            }

            Runtime.getRuntime().addShutdownHook(new Thread(Main::releaseInstanceLock, "notebot-shutdown"));
            EventQueue.invokeLater(Main::startApplication);
        } catch (IOException exception) {
            LOGGER.log(Level.SEVERE, "NoteBot could not start", exception);
            showFatalError(exception);
        }
    }

    private static boolean containsArgument(String[] args, String expected) {
        for (String argument : args) {
            if (expected.equalsIgnoreCase(argument)) {
                return true;
            }
        }
        return false;
    }

    private static void initialiseApplicationFiles() throws IOException {
        appDirectory = AppPaths.getDataDirectory();
        storagePath = appDirectory.resolve("sticky.dat");
        backupPath = appDirectory.resolve("sticky.dat.bak");
        secondBackupPath = appDirectory.resolve("sticky.dat.bak.2");
        lockPath = appDirectory.resolve("lock");
    }

    private static void configureLogging() {
        try {
            Path logDirectory = Files.createDirectories(appDirectory.resolve("logs"));
            FileHandler handler = new FileHandler(logDirectory.resolve("notebot.log").toString(), 1024 * 1024, 3, true);
            handler.setFormatter(new SimpleFormatter());
            LOGGER.addHandler(handler);
        } catch (IOException exception) {
            LOGGER.log(Level.WARNING, "File logging is unavailable", exception);
        }
    }

    private static void configureUncaughtExceptionHandler() {
        Thread.setDefaultUncaughtExceptionHandler((thread, error) -> {
            LOGGER.log(Level.SEVERE, "Unexpected error on " + thread.getName(), error);
            EventQueue.invokeLater(() -> showFatalError(error));
        });
    }

    private static void startApplication() {
        applyLookAndFeel();

        boolean storedDataExists = Files.exists(storagePath)
                || Files.exists(backupPath)
                || Files.exists(secondBackupPath);
        boolean loaded = loadState();

        if (!loaded) {
            if (storedDataExists) {
                Path recoveryDirectory = preserveUnreadableStorage();
                String message = MessageFormat.format(
                        MESSAGES.getString("LOAD_ERROR"),
                        recoveryDirectory == null ? appDirectory : recoveryDirectory
                );
                showMessage(message, JOptionPane.WARNING_MESSAGE);
            }
            if (!noAutoCreate) {
                Note note = createNote();
                NOTES.add(note);
                note.setVisible(true);
            }
        }

        if (NOTES.isEmpty()) {
            System.exit(0);
            return;
        }

        saveState();
        startTimers();
    }

    private static Path preserveUnreadableStorage() {
        String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss"));
        Path recoveryDirectory = appDirectory.resolve("recovery").resolve(timestamp);
        try {
            Files.createDirectories(recoveryDirectory);
            copyIfPresent(storagePath, recoveryDirectory.resolve(storagePath.getFileName()));
            copyIfPresent(backupPath, recoveryDirectory.resolve(backupPath.getFileName()));
            copyIfPresent(secondBackupPath, recoveryDirectory.resolve(secondBackupPath.getFileName()));
            return recoveryDirectory;
        } catch (IOException exception) {
            LOGGER.log(Level.SEVERE, "Could not preserve unreadable storage", exception);
            return null;
        }
    }

    private static void copyIfPresent(Path source, Path destination) throws IOException {
        if (Files.isRegularFile(source)) {
            Files.copy(source, destination, StandardCopyOption.REPLACE_EXISTING);
        }
    }

    private static void startTimers() {
        Timer saveTimer = new Timer(60000, event -> saveState());
        saveTimer.setRepeats(true);
        saveTimer.start();

        Timer screenTimer = new Timer(1000, event -> {
            synchronized (NOTES) {
                for (Note note : NOTES) {
                    note.ensureVisible();
                }
            }
        });
        screenTimer.setRepeats(true);
        screenTimer.start();
    }

    private static void applyLookAndFeel() {
        try {
            MetalLookAndFeel.setCurrentTheme(new MetalTheme() {
                private final FontUIResource regularFont = new FontUIResource(BASE_FONT);
                private final FontUIResource smallFont = new FontUIResource(SMALL_FONT);

                @Override
                protected ColorUIResource getPrimary1() {
                    return METAL_PRIMARY;
                }

                @Override
                protected ColorUIResource getPrimary2() {
                    return METAL_PRIMARY;
                }

                @Override
                protected ColorUIResource getPrimary3() {
                    return METAL_PRIMARY;
                }

                @Override
                protected ColorUIResource getSecondary1() {
                    return METAL_SECONDARY;
                }

                @Override
                protected ColorUIResource getSecondary2() {
                    return METAL_SECONDARY;
                }

                @Override
                protected ColorUIResource getSecondary3() {
                    return DEFAULT_BACKGROUND;
                }

                @Override
                public String getName() {
                    return "NoteBot";
                }

                @Override
                public FontUIResource getControlTextFont() {
                    return regularFont;
                }

                @Override
                public FontUIResource getSystemTextFont() {
                    return regularFont;
                }

                @Override
                public FontUIResource getUserTextFont() {
                    return regularFont;
                }

                @Override
                public FontUIResource getMenuTextFont() {
                    return smallFont;
                }

                @Override
                public FontUIResource getWindowTitleFont() {
                    return regularFont;
                }

                @Override
                public FontUIResource getSubTextFont() {
                    return regularFont;
                }
            });
            UIManager.setLookAndFeel("javax.swing.plaf.metal.MetalLookAndFeel");
        } catch (Exception exception) {
            LOGGER.log(Level.WARNING, "Could not apply the NoteBot look and feel", exception);
        }
    }

    private static void showMessage(String message, int messageType) {
        if (GraphicsEnvironment.isHeadless()) {
            System.err.println(message);
            return;
        }
        Runnable task = () -> JOptionPane.showMessageDialog(
                null,
                message,
                MESSAGES.getString("APPNAME"),
                messageType
        );
        if (SwingUtilities.isEventDispatchThread()) {
            task.run();
        } else {
            EventQueue.invokeLater(task);
        }
    }

    private static void showFatalError(Throwable error) {
        String detail = error.getMessage();
        if (detail == null || detail.isBlank()) {
            detail = error.getClass().getSimpleName();
        }
        String message = MessageFormat.format(MESSAGES.getString("STARTUP_ERROR"), detail);
        showMessage(message, JOptionPane.ERROR_MESSAGE);
    }
}
