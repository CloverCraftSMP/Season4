import java.io.File;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.*;
import java.util.Comparator;
import java.util.List;

public class DevLaunch {
    public static void main(String[] args) throws Exception {
        String repoPath = System.getProperty("dev.repo.path", System.getenv("DEV_REPO_PATH"));
        if (repoPath == null) {
            System.err.println("Repo path is missing! Launch this instance via Prism.");
            System.exit(1);
        }
        
        Path repoDir = Paths.get(repoPath);
        Path rootDir = Paths.get(".");
        Path pakkuJar = repoDir.resolve(".mise").resolve("pakku.jar");
        
        Path commonOverridesDir = repoDir.resolve(".pakku").resolve("overrides");
        Path clientOverridesDir = repoDir.resolve(".pakku").resolve("client-overrides");

        wipeOldPaths(rootDir, List.of("config", "fancymenu_data", "local", "options.txt"));
        
        System.out.println("Syncing overrides and Pakku files...");
        copy(commonOverridesDir, rootDir);
        copy(clientOverridesDir, rootDir);
        copy(repoDir.resolve("pakku.json"), rootDir);
        copy(repoDir.resolve("pakku-lock.json"), rootDir);
        
        runPakkuFetch(pakkuJar);

        System.out.println("Booting pack...");
    }

    private static void wipeOldPaths(Path rootDir, List<String> paths) throws IOException {
        System.out.println("Wiping dynamic paths...");
        for (String path : paths) {
            var target = rootDir.resolve(path);
            if (Files.exists(target)) {
                try (var stream = Files.walk(target)) {
                    stream.sorted(Comparator.reverseOrder())
                          .map(Path::toFile)
                          .forEach(File::delete);
                }
            }
        }
    }

    private static void copy(Path source, Path targetDir) throws IOException {
        if (!Files.exists(source)) return;
 
        // single file guard clause
        if (Files.isRegularFile(source)) {
            Files.copy(source, targetDir.resolve(source.getFileName()), StandardCopyOption.REPLACE_EXISTING);
            return;
        }
        
        try (var stream = Files.walk(source)) {
            stream.forEach(file -> {
                try {
                    var resolved = targetDir.resolve(source.relativize(file));
                    if (Files.isDirectory(file)) {
                        if (!Files.exists(resolved)) Files.createDirectory(resolved);
                    } else {
                        Files.copy(file, resolved, StandardCopyOption.REPLACE_EXISTING);
                    }
                } catch (IOException e) {
                    throw new UncheckedIOException(e);
                }
            });
        }
    }

    private static void runPakkuFetch(Path pakkuJar) throws Exception {
        System.out.println("Syncing mods via Pakku...");
        var javaExe = Paths.get(System.getProperty("java.home"), "bin", "java");

        var pb = new ProcessBuilder(javaExe.toString(), "-jar", pakkuJar.toString(), "fetch");
        pb.inheritIO();
        
        int exitCode = pb.start().waitFor();
        if (exitCode != 0) {
            System.err.println("Pakku fetch failed! Halting launch.");
            System.exit(exitCode);
        }
    }
}