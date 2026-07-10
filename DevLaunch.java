import java.io.File;
import java.io.IOException;
import java.nio.file.*;
import java.nio.file.attribute.BasicFileAttributes;
import java.util.Comparator;

public class DevLaunch {
    public static void main(String[] args) throws Exception {
        String[] foldersToWipe = {"config", "defaultconfigs"};

        String repoPath = System.getProperty("dev.repo.path", System.getenv("DEV_REPO_PATH"));
        if (repoPath == null) {
            System.err.println("Repo path is missing! Launch this instance via Prism.");
            System.exit(1);
        }
        Path repoDir = Paths.get(repoPath);
        Path rootDir = Paths.get(".");
        
        Path commonOverridesDir = repoDir.resolve(".pakku").resolve("overrides");
        Path clientOverridesDir = repoDir.resolve(".pakku").resolve("client-overrides");
        Path pakkuJar = repoDir.resolve(".mise").resolve("pakku.jar");

        System.out.println("Wiping dynamic directories...");
        for (String folder : foldersToWipe) {
            Path target = rootDir.resolve(folder);
            if (Files.exists(target)) {
                Files.walk(target)
                     .sorted(Comparator.reverseOrder())
                     .map(Path::toFile)
                     .forEach(File::delete);
            }
        }

        if (Files.exists(commonOverridesDir)) {
            System.out.println("Applying common overrides...");
            copyDirectory(commonOverridesDir, rootDir);
        } else {
            System.out.println("No common overrides found at " + commonOverridesDir);
        }

        if (Files.exists(clientOverridesDir)) {
            System.out.println("Applying client-specific overrides...");
            copyDirectory(clientOverridesDir, rootDir);
        }

        System.out.println("Syncing Pakku lockfiles from repo...");
        Files.copy(repoDir.resolve("pakku.json"), Paths.get("pakku.json"), StandardCopyOption.REPLACE_EXISTING);
        if (Files.exists(repoDir.resolve("pakku-lock.json"))) {
            Files.copy(repoDir.resolve("pakku-lock.json"), Paths.get("pakku-lock.json"), StandardCopyOption.REPLACE_EXISTING);
        }

        System.out.println("Syncing mods via Pakku...");
        String javaExe = System.getenv("java.home");
        if (javaExe == null || javaExe.isEmpty()) {
            javaExe = "java"; 
        }

        ProcessBuilder pb = new ProcessBuilder(javaExe, "-jar", pakkuJar.toString(), "fetch");
        pb.inheritIO();
        Process p = pb.start();
        
        int exitCode = p.waitFor();
        if (exitCode != 0) {
            System.err.println("Pakku fetch failed!");
            System.exit(exitCode);
        }
        
        System.out.println("Booting pack...");
    }

    private static void copyDirectory(Path source, Path target) throws IOException {
        Files.walkFileTree(source, new SimpleFileVisitor<Path>() {
            @Override
            public FileVisitResult preVisitDirectory(Path dir, BasicFileAttributes attrs) throws IOException {
                Path targetDir = target.resolve(source.relativize(dir));
                if (!Files.exists(targetDir)) {
                    Files.createDirectory(targetDir);
                }
                return FileVisitResult.CONTINUE;
            }

            @Override
            public FileVisitResult visitFile(Path file, BasicFileAttributes attrs) throws IOException {
                Files.copy(file, target.resolve(source.relativize(file)), StandardCopyOption.REPLACE_EXISTING);
                return FileVisitResult.CONTINUE;
            }
        });
    }
}