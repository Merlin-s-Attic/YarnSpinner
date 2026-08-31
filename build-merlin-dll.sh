#!/bin/bash
# Builds the Merlin's Attic fork of the Yarn Spinner runtime assembly and copies
# it over the stock YarnSpinner.dll in a Yarn Spinner for Unity package.
#
# Only YarnSpinner.dll is rebuilt: this fork patches nothing in the compiler, and
# the stock YarnSpinner.Compiler.dll binds to this assembly by name and version.
# ASSEMBLY_VERSION must therefore stay equal to the version the shipped
# YarnSpinner.Compiler.dll references, or Unity will fail to resolve the assembly.
#
# Usage: ./build-merlin-dll.sh {PATH TO dev.yarnspinner.unity PACKAGE}

set -e

ASSEMBLY_VERSION=3.2.2.0
UPSTREAM_VERSION=3.2.2

YARNSPINNER_FOLDER=$(readlink -f "$(dirname "$0")")
DLLS_DIR="$1/Runtime/DLLs"

if [ ! -d "$DLLS_DIR" ]; then
    echo "Can't copy YarnSpinner.dll to $DLLS_DIR because this directory does not exist"
    exit 1
fi

cd "$YARNSPINNER_FOLDER"

SHA=$(git log -1 --format=%H)
BRANCH=$(git rev-parse --abbrev-ref HEAD)
INFO_VERSION="$UPSTREAM_VERSION-merlin+Branch.$BRANCH.Sha.$SHA"

INFO_FILE=YarnSpinner/AssemblyInfo.cs
perl -pi -e "s/AssemblyVersion\(\".*\"\)/AssemblyVersion(\"$ASSEMBLY_VERSION\")/" $INFO_FILE
perl -pi -e "s/AssemblyInformationalVersion\(\".*\"\)/AssemblyInformationalVersion(\"$INFO_VERSION\")/" $INFO_FILE
perl -pi -e "s/AssemblyFileVersion\(\".*\"\)/AssemblyFileVersion(\"$ASSEMBLY_VERSION\")/" $INFO_FILE

rm -rf .build-tmp
mkdir -p .build-tmp

dotnet build -p:UseVendoredProtobuf=true --configuration Release YarnSpinner/YarnSpinner.csproj
cp -v YarnSpinner/bin/Release/netstandard2.1/YarnSpinner.dll .build-tmp/
cp -v YarnSpinner/bin/Release/netstandard2.1/YarnSpinner.xml .build-tmp/ || true
cp -v YarnSpinner/Dependencies/Google.Protobuf.dll .build-tmp/

git checkout $INFO_FILE

# Rewrite the Google.Protobuf reference to the aliased name the Unity package ships.
# assemblyalias 0.4.3 targets net6.0; roll forward to whatever runtime is installed.
DOTNET_ROLL_FORWARD=LatestMajor assemblyalias --target-directory ".build-tmp" --prefix "Yarn." --assemblies-to-alias "Google*"

cp -v .build-tmp/YarnSpinner.dll "$DLLS_DIR/"
cp -v .build-tmp/YarnSpinner.xml "$DLLS_DIR/" || true

rm -rf .build-tmp

echo "Built YarnSpinner.dll ($INFO_VERSION) into $DLLS_DIR"
