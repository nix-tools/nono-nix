# Run all flake checks.
check:
	nix flake check

# Format the repository with treefmt.
fmt:
	nix fmt
