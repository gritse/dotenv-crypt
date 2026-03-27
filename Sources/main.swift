import ArgumentParser

struct DotenvCrypt: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dotenv-crypt",
        abstract: "Encrypt and decrypt individual values in .env files.",
        subcommands: [InitCommand.self, EncryptCommand.self, DecryptCommand.self, ListCommand.self, RevealCommand.self, ExecCommand.self, SecretCommand.self, AddSecretCommand.self, DockerCommand.self, MoveKeyCommand.self, TagCommand.self]
    )
}

DotenvCrypt.main()
