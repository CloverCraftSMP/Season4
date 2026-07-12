import java.io.File;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Scanner;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.zip.ZipFile;

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
        
        runPakkuFetch(repoDir, pakkuJar);

        Set<String> validClientMods = generateClientWhitelist(repoDir, pakkuJar);
        
        if (!validClientMods.isEmpty()) {
            syncClientMods(repoDir, rootDir, validClientMods);
        }

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

    private static void runPakkuFetch(Path repoDir, Path pakkuJar) throws Exception {
        System.out.println("Syncing mods via Pakku...");
        var javaExe = Paths.get(System.getProperty("java.home"), "bin", "java");

        var pb = new ProcessBuilder(javaExe.toString(), "-jar", pakkuJar.toString(), "fetch");
        pb.directory(repoDir.toFile());
        pb.inheritIO();
        
        int exitCode = pb.start().waitFor();
        if (exitCode != 0) {
            System.err.println("Pakku fetch failed! Halting launch.");
            System.exit(exitCode);
        }
    }

    private static Set<String> generateClientWhitelist(Path repoDir, Path pakkuJar) throws Exception {
        System.out.println("Determining client-only mods...");
        var javaExe = Paths.get(System.getProperty("java.home"), "bin", "java");
        
        ProcessBuilder pb = new ProcessBuilder(
            javaExe.toString(), "-jar", pakkuJar.toString(), "export", "--no-server"
        );
        pb.directory(repoDir.toFile());
        pb.start().waitFor();
        
        Path modrinthBuildDir = repoDir.resolve("build").resolve("modrinth");
        if (!Files.exists(modrinthBuildDir)) return Set.of();
        
        Path mrpackPath = null;
        try (var stream = Files.list(modrinthBuildDir)) {
            mrpackPath = stream.filter(p -> p.toString().endsWith(".mrpack")).findFirst().orElse(null);
        }
        
        if (mrpackPath == null) return Set.of();
        
        Set<String> validMods = new HashSet<>();
        try (ZipFile zip = new ZipFile(mrpackPath.toFile())) {
            var entry = zip.getEntry("modrinth.index.json");
            if (entry != null) {
                try (var is = zip.getInputStream(entry);
                     var scanner = new Scanner(is, StandardCharsets.UTF_8)) {
                    String content = scanner.useDelimiter("\\A").next();
                    Matcher m = Pattern.compile("\"path\"\\s*:\\s*\"mods/([^\"]+\\.jar)\"").matcher(content);
                    while (m.find()) {
                        String fullPath = m.group(1);
                        validMods.add(Paths.get(fullPath).getFileName().toString());
                    }
                }
            }
        }
        return validMods;
    }

    private static void syncClientMods(Path repoDir, Path rootDir, Set<String> validClientMods) throws IOException {
        Path repoModsDir = repoDir.resolve("mods");
        Path prismModsDir = rootDir.resolve("mods");
        
        if (!Files.exists(prismModsDir)) {
            Files.createDirectory(prismModsDir);
        }

        System.out.println("Syncing whitelisted mods to Prism...");
        
        for (String modName : validClientMods) {
            Path sourceJar = repoModsDir.resolve(modName);
            Path destJar = prismModsDir.resolve(modName);
            
            if (Files.exists(sourceJar) && !Files.exists(destJar)) {
                Files.copy(sourceJar, destJar, StandardCopyOption.REPLACE_EXISTING);
            }
        }

        try (var stream = Files.list(prismModsDir)) {
            stream.filter(p -> p.toString().endsWith(".jar"))
                  .forEach(p -> {
                      String fileName = p.getFileName().toString();
                      if (!validClientMods.contains(fileName)) {
                          System.out.println("❯❯❯  Purged invalid/server mod: " + fileName);
                          try {
                              Files.delete(p);
                          } catch (IOException e) {
                              System.err.println("❯❯❯  Failed to delete: " + fileName);
                          }
                      }
                  });
        }
    }
}