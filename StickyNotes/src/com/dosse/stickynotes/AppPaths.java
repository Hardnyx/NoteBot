/*
 * Copyright (C) 2026 Alonso Roman
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */
package com.dosse.stickynotes;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;

final class AppPaths {

    private AppPaths() {
    }

    static Path getDataDirectory() throws IOException {
        String operatingSystem = System.getProperty("os.name", "").toLowerCase(Locale.ROOT);
        Path directory;

        if (operatingSystem.startsWith("windows")) {
            String localAppData = System.getenv("LOCALAPPDATA");
            if (localAppData != null && !localAppData.isBlank()) {
                directory = Path.of(localAppData, "NoteBot");
            } else {
                directory = Path.of(System.getProperty("user.home"), "AppData", "Local", "NoteBot");
            }
        } else {
            directory = Path.of(System.getProperty("user.home"), ".notebot");
        }

        Files.createDirectories(directory);
        if (!Files.isDirectory(directory) || !Files.isWritable(directory)) {
            throw new IOException("The NoteBot data directory is not writable: " + directory);
        }
        return directory;
    }
}
