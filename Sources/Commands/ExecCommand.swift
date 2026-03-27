import ArgumentParser
import Foundation
import Darwin

struct ExecCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "exec",
        abstract: "Decrypt .env values and exec a command with them as environment variables."
    )

    @Option(name: [.short, .long], help: "Path to the .env file.")
    var file: String = ".env"

    @OptionGroup var keychain: KeychainOptions

    @Argument(parsing: .captureForPassthrough, help: "Command and arguments to execute.")
    var command: [String]

    mutating func run() throws {
        if command.first == "--" { command.removeFirst() }
        guard !command.isEmpty else {
            throw ValidationError("No command specified.")
        }

        try Auth.requireTouchID(reason: "Decrypt .env values for \(command[0])")

        let key = try Keychain.loadKey(keychainPath: keychain.resolved)
        let url = URL(fileURLWithPath: file)
        let file = try EnvFile(contentsOf: url)

        // Start with current process environment, overlay with .env values
        var env = ProcessInfo.processInfo.environment
        for (k, v) in file.allEntries() {
            env[k] = Crypto.isEncrypted(v) ? try Crypto.decrypt(v, using: key) : v
        }

        guard let executablePath = resolve(command[0], env: env) else {
            throw ValidationError("Command not found: \(command[0])")
        }

        exec(path: executablePath, args: command, env: env)
    }
}

private func resolve(_ command: String, env: [String: String]) -> String? {
    if command.hasPrefix("/") || command.hasPrefix("./") || command.hasPrefix("../") {
        return FileManager.default.isExecutableFile(atPath: command) ? command : nil
    }
    let paths = (env["PATH"] ?? "").components(separatedBy: ":")
    return paths
        .map { "\($0)/\(command)" }
        .first { FileManager.default.isExecutableFile(atPath: $0) }
}

private func exec(path: String, args: [String], env: [String: String]) -> Never {
    var argv = args.map { strdup($0) as UnsafeMutablePointer<CChar>? }
    argv.append(nil)

    let envStrings = env.map { "\($0.key)=\($0.value)" }
    var envp = envStrings.map { strdup($0) as UnsafeMutablePointer<CChar>? }
    envp.append(nil)

    _ = argv.withUnsafeBufferPointer { argvBuf in
        envp.withUnsafeBufferPointer { envpBuf in
            Darwin.execve(path, argvBuf.baseAddress, envpBuf.baseAddress)
        }
    }

    fputs("execve failed: \(String(cString: strerror(errno)))\n", stderr)
    Darwin.exit(1)
}
