#!/bin/bash

# Install gqlgen
go get github.com/99designs/gqlgen

# Generate GraphQL code
go run github.com/99designs/gqlgen generate

echo "GraphQL code generation complete!"
echo "You can now run the server with '-d' flag to enable GraphQL playground:"
echo "go run cmd/myapp/main.go -d" 