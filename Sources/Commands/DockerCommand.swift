import ArgumentParser
import Foundation
import Darwin

struct DockerCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "docker",
        abstract: "Run docker, automatically decrypting .env values when compose is used."
    )

    @OptionGroup var keychain: KeychainOptions

    @Argument(parsing: .captureForPassthrough, help: "Arguments to pass to docker.")
    var args: [String] = []

    mutating func run() throws {
        // Docker global flags and compose flags that consume a value
        let parser = ArgParser(valueFlags: [
            "--context", "--host", "-H", "--log-level", "--config",
            "-f", "--file", "--env-file", "--project-directory",
            "-p", "--project-name"
        ])
        let tokens = parser.parse(args)

        guard let composeIdx = tokens.firstPositionalIndex(of: "compose") else {
            execDocker(args: args, env: ProcessInfo.processInfo.environment)
        }

        let composeTokens = Array(tokens[composeIdx...])
        let envFilePath = resolveEnvFile(from: composeTokens)

        guard FileManager.default.fileExists(atPath: envFilePath),
              let contents = try? String(contentsOfFile: envFilePath, encoding: .utf8),
              contents.contains("enc:v1:") else {
            execDocker(args: args, env: ProcessInfo.processInfo.environment)
        }

        try Auth.requireTouchID(reason: "Decrypt \(envFilePath) for docker compose")

        let key = try Keychain.loadKey(keychainPath: keychain.resolved)
        let envFile = try EnvFile(contentsOf: URL(fileURLWithPath: envFilePath))

        var env = ProcessInfo.processInfo.environment
        for (k, v) in envFile.allEntries() {
            env[k] = Crypto.isEncrypted(v) ? try Crypto.decrypt(v, using: key) : v
        }

        execDocker(args: args, env: env)
    }
}

private func resolveEnvFile(from composeTokens: [ArgParser.Token]) -> String {
    if let f = composeTokens.firstOption(named: "--env-file") { return f }
    if let d = composeTokens.firstOption(named: "--project-directory") { return "\(d)/.env" }
    if let f = composeTokens.firstOption(named: "-f", "--file") {
        return "\(URL(fileURLWithPath: f).deletingLastPathComponent().path)/.env"
    }
    return ".env"
}

private func execDocker(args: [String], env: [String: String]) -> Never {
    let paths = (env["PATH"] ?? "").components(separatedBy: ":")
    guard let dockerPath = paths.map({ "\($0)/docker" }).first(where: {
        FileManager.default.isExecutableFile(atPath: $0)
    }) else {
        fputs("docker not found in PATH\n", stderr)
        Darwin.exit(1)
    }

    var argv = (["docker"] + args).map { strdup($0) as UnsafeMutablePointer<CChar>? }
    argv.append(nil)
    let envStrings = env.map { "\($0.key)=\($0.value)" }
    var envp = envStrings.map { strdup($0) as UnsafeMutablePointer<CChar>? }
    envp.append(nil)

    _ = argv.withUnsafeBufferPointer { argvBuf in
        envp.withUnsafeBufferPointer { envpBuf in
            Darwin.execve(dockerPath, argvBuf.baseAddress, envpBuf.baseAddress)
        }
    }
    fputs("execve failed: \(String(cString: strerror(errno)))\n", stderr)
    Darwin.exit(1)
}
