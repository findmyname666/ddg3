final: prev: {
  terraform = final.buildGoModule rec {
    version = "1.14.4";
    pname = "terraform";

    src = final.fetchFromGitHub {
      owner = "hashicorp";
      repo = "terraform";
      rev = "v${version}";
      hash = "sha256-fEuIAKmR+shKHNldUlU6qvel9tjYFdKnc25JWtxRPHs=";
    };

    doCheck = false;

    vendorHash = "sha256-NDtBLa8vokrSRDCNX10lQyfMDzTrodoEj5zbDanL4bk=";

    ldflags = [ "-s" "-w" ];

    postPatch = ''
      substituteInPlace go.mod \
        --replace-quiet 'godebug tlskyber=0' 'godebug tlsmlkem=0'
    '';

    postConfigure = ''
      # speakeasy hardcodes /bin/stty https://github.com/bgentry/speakeasy/issues/22
      substituteInPlace vendor/github.com/bgentry/speakeasy/speakeasy_unix.go \
        --replace-fail "/bin/stty" "${final.coreutils}/bin/stty"
    '';

    nativeBuildInputs = [ final.installShellFiles ];

    postInstall = ''
      # https://github.com/posener/complete/blob/9a4745ac49b29530e07dc2581745a218b646b7a3/cmd/install/bash.go#L8
      installShellCompletion --bash --name terraform <(echo complete -C terraform terraform)
    '';

    preCheck = ''
      export HOME=$TMPDIR
      export TF_SKIP_REMOTE_TESTS=1
    '';

    subPackages = [ "." ];
  };
}
