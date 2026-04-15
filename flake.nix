{
  description = "PingOne User Import Tool - Java 8 + Maven build environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "aarch64-darwin" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        jdk = pkgs.jdk8;
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            jdk
            pkgs.maven
          ];

          JAVA_HOME = "${jdk}";

          # Use macOS Keychain as trust store so Netskope's CA cert is trusted
          JAVA_TOOL_OPTIONS = "-Djavax.net.ssl.trustStoreType=KeychainStore";

          shellHook = ''
            echo "Java: $(java -version 2>&1 | head -1)"
            echo "Maven: $(mvn -version 2>&1 | head -1)"
          '';
        };

        packages.default = pkgs.stdenv.mkDerivation {
          pname = "user-import-tool";
          version = "1.0-SNAPSHOT";
          src = ./.;

          buildInputs = [ jdk pkgs.maven ];

          buildPhase = ''
            export JAVA_HOME=${jdk}
            export HOME=$(mktemp -d)

            # Build a custom truststore that includes the Netskope CA certificate.
            # The macOS Nix sandbox allows read access to /Library, so we can reach
            # the cert file directly without relying on the Keychain API.
            TRUSTSTORE="$HOME/truststore.jks"
            JAVA_CACERTS=$(find ${jdk} -name "cacerts" 2>/dev/null | head -1)
            cp "$JAVA_CACERTS" "$TRUSTSTORE"
            chmod u+w "$TRUSTSTORE"
            for cert in \
              "/Library/Application Support/Netskope/STAgent/data/nscacert.pem" \
              "/Library/Application Support/Netskope/STAgent/download/nscacert.pem"; do
              if [ -f "$cert" ]; then
                ${jdk}/bin/keytool -importcert -noprompt -trustcacerts \
                  -alias netskope -file "$cert" \
                  -keystore "$TRUSTSTORE" -storepass changeit
                echo "Imported Netskope cert from: $cert"
                break
              fi
            done

            export JAVA_TOOL_OPTIONS="-Djavax.net.ssl.trustStore=$TRUSTSTORE -Djavax.net.ssl.trustStorePassword=changeit"
            mvn clean package -Dmaven.repo.local=$HOME/.m2
          '';

          installPhase = ''
            mkdir -p $out/bin $out/lib
            cp target/user-import-tool-1.0-SNAPSHOT-jar-with-dependencies.jar $out/lib/

            cat > $out/bin/user-import-tool <<EOF
            #!/bin/sh
            exec ${jdk}/bin/java -jar $out/lib/user-import-tool-1.0-SNAPSHOT-jar-with-dependencies.jar "\$@"
            EOF
            chmod +x $out/bin/user-import-tool
          '';
        };

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/user-import-tool";
        };
      });
}
