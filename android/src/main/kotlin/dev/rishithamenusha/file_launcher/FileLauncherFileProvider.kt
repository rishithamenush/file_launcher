package dev.rishithamenusha.file_launcher

import androidx.core.content.FileProvider

/** Separate provider class and authority to avoid collisions with other plugins. */
class FileLauncherFileProvider : FileProvider()
