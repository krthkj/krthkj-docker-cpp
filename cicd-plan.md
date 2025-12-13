# CI/CD Cross-Compilation Plan for C++ Development

## Overview
This plan outlines how to leverage your existing Linux Docker containers (Alpine/Ubuntu) to cross-compile C++ applications for Windows and macOS targets using GitHub Actions.

## Current Assets
- ✅ Linux containers: Alpine and Ubuntu with GCC/Clang
- ✅ Multi-architecture support (amd64/arm64)
- ✅ C++20/23 development environment
- ✅ CMake, Boost, OpenCL, CUDA support

## Phase 1: Cross-Compilation Toolchain Setup

### 1.1 Windows Cross-Compilation
**Target Platforms:**
- Windows x64 (MSVC)
- Windows x64 (MinGW-w64)

**Required Tools:**
```dockerfile
# Add to Ubuntu Dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    mingw-w64 \
    gcc-mingw-w64-x86-64 \
    g++-mingw-w64-x86-64 \
    wine64 \
    && rm -rf /var/lib/apt/lists/*
```

**CMake Toolchain Files:**
- `toolchains/windows-mingw-w64.cmake`
- `toolchains/windows-msvc.cmake` (via wine+cl.exe)

### 1.2 macOS Cross-Compilation
**Target Platforms:**
- macOS x64 (Intel)
- macOS arm64 (Apple Silicon)

**Required Tools:**
```dockerfile
# Add to Ubuntu Dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    clang \
    lld \
    llvm \
    cmake \
    python3 \
    python3-pip \
    && pip3 install --break-system-packages macos-sdk
```

**CMake Toolchain Files:**
- `toolchains/macos-x64.cmake`
- `toolchains/macos-arm64.cmake`

## Phase 2: Enhanced Docker Images

### 2.1 Cross-Compilation Base Image
```dockerfile
# Dockerfile.cross-compilation
FROM ubuntu:24.04

# Install base cross-compilation tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    git \
    wget \
    curl \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Windows cross-compilation
RUN apt-get update && apt-get install -y --no-install-recommends \
    mingw-w64 \
    gcc-mingw-w64-x86-64 \
    g++-mingw-w64-x86-64 \
    gcc-mingw-w64-i686 \
    g++-mingw-w64-i686 \
    && rm -rf /var/lib/apt/lists/*

# macOS cross-compilation dependencies
RUN pip3 install --break-system-packages \
    macos-sdk \
    osxcross

# Install osxcross (simplified approach)
RUN git clone https://github.com/tpoechtrager/osxcross.git /opt/osxcross && \
    cd /opt/osxcross && \
    ./tools/gen_sdk_package.sh && \
    ./build.sh
```

### 2.2 Enhanced Compose Services
```yaml
# Add to compose.yaml
  cross-compile-base:
    image: cpp-cross-compile:${BUILD_TIMESTAMP}
    build:
      context: .
      dockerfile: Dockerfile.cross-compilation
      tags:
        - krthkj/cpp:cross-compile
        - krthkj/cpp:cross-compile-${BUILD_TIMESTAMP}
        - cpp-cross-compile:latest

  windows-builder:
    image: cpp-windows-builder:${BUILD_TIMESTAMP}
    build:
      context: .
      dockerfile: Dockerfile.cross-compilation
      target: windows-builder
      tags:
        - krthkj/cpp:windows-builder
        - cpp-windows-builder:latest

  macos-builder:
    image: cpp-macos-builder:${BUILD_TIMESTAMP}
    build:
      context: .
      dockerfile: Dockerfile.cross-compilation
      target: macos-builder
      tags:
        - krthkj/cpp:macos-builder
        - cpp-macos-builder:latest
```

## Phase 3: CMake Toolchain Files

### 3.1 Windows MinGW Toolchain
```cmake
# toolchains/windows-mingw-w64.cmake
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

# Cross-compilation tools
set(CMAKE_C_COMPILER x86_64-w64-mingw32-gcc)
set(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++)
set(CMAKE_RC_COMPILER x86_64-w64-mingw32-windres)

# Target environment
set(CMAKE_FIND_ROOT_PATH /usr/x86_64-w64-mingw32)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Windows-specific flags
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -static-libgcc -static-libstdc++")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static")
```

### 3.2 macOS Toolchain
```cmake
# toolchains/macos-x64.cmake
set(CMAKE_SYSTEM_NAME Darwin)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

# Cross-compilation tools (using osxcross)
set(CMAKE_C_COMPILER o64-clang)
set(CMAKE_CXX_COMPILER o64-clang++)
set(CMAKE_AR x86_64-apple-darwin-ar)
set(CMAKE_RANLIB x86_64-apple-darwin-ranlib)

# Target environment
set(CMAKE_OSX_SYSROOT /opt/osxcross/target/SDK/MacOSX.sdk)
set(CMAKE_OSX_DEPLOYMENT_TARGET "10.15")

# macOS-specific flags
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libc++")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mmacosx-version-min=10.15")
```

## Phase 4: GitHub Actions Workflow

### 4.1 Main CI/CD Workflow
```yaml
# .github/workflows/cross-compile.yml
name: Cross-Platform Build

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  release:
    types: [ published ]

env:
  BUILD_TYPE: Release

jobs:
  # Linux builds (existing)
  build-linux:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        container: [gcc-alpine, clang-alpine, gcc14, clang20]
        arch: [amd64, arm64]
    steps:
      - uses: actions/checkout@v4
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      - name: Build
        run: |
          docker buildx build \
            --platform linux/${{ matrix.arch }} \
            --build-arg USE_CLANG=${{ matrix.container == 'clang-alpine' || matrix.container == 'clang20' }} \
            -t cpp-${{ matrix.container }}:${{ matrix.arch }} \
            -f amd64/Dockerfile.${{ matrix.container == 'gcc-alpine' || matrix.container == 'clang-alpine' && 'alpine' || 'ubuntu' }} \
            .

  # Windows cross-compilation
  build-windows:
    runs-on: ubuntu-latest
    container: krthkj/cpp:cross-compile
    strategy:
      matrix:
        toolchain: [mingw-w64, msvc]
        arch: [x64, x86]
    steps:
      - uses: actions/checkout@v4
      - name: Configure CMake
        run: |
          cmake -B build \
            -DCMAKE_BUILD_TYPE=${{ env.BUILD_TYPE }} \
            -DCMAKE_TOOLCHAIN_FILE=toolchains/windows-${{ matrix.toolchain }}.cmake \
            -DCMAKE_INSTALL_PREFIX=install
      - name: Build
        run: cmake --build build --config ${{ env.BUILD_TYPE }} --parallel
      - name: Install
        run: cmake --install build --prefix install-${{ matrix.arch }}
      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: windows-${{ matrix.toolchain }}-${{ matrix.arch }}
          path: install-${{ matrix.arch }}/

  # macOS cross-compilation
  build-macos:
    runs-on: ubuntu-latest
    container: krthkj/cpp:cross-compile
    strategy:
      matrix:
        arch: [x64, arm64]
    steps:
      - uses: actions/checkout@v4
      - name: Configure CMake
        run: |
          cmake -B build \
            -DCMAKE_BUILD_TYPE=${{ env.BUILD_TYPE }} \
            -DCMAKE_TOOLCHAIN_FILE=toolchains/macos-${{ matrix.arch }}.cmake \
            -DCMAKE_INSTALL_PREFIX=install
      - name: Build
        run: cmake --build build --config ${{ env.BUILD_TYPE }} --parallel
      - name: Install
        run: cmake --install build --prefix install-${{ matrix.arch }}
      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: macos-${{ matrix.arch }}
          path: install-${{ matrix.arch }}/

  # Release creation
  create-release:
    needs: [build-linux, build-windows, build-macos]
    runs-on: ubuntu-latest
    if: github.event_name == 'release'
    steps:
      - uses: actions/checkout@v4
      - name: Download all artifacts
        uses: actions/download-artifact@v4
        with:
          path: artifacts
      - name: Create release packages
        run: |
          mkdir -p release
          cd artifacts
          
          # Create Windows packages
          for dir in windows-*; do
            tar -czf "../release/${dir}.tar.gz" "$dir"
          done
          
          # Create macOS packages
          for dir in macos-*; do
            tar -czf "../release/${dir}.tar.gz" "$dir"
          done
          
          # Create Linux packages (if needed)
          for dir in linux-*; do
            tar -czf "../release/${dir}.tar.gz" "$dir"
          done
      - name: Upload release assets
        uses: softprops/action-gh-release@v1
        with:
          files: release/*
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Phase 5: Local Development Workflow

### 5.1 Cross-Compilation Scripts
```bash
#!/bin/bash
# scripts/cross-compile.sh

set -e

BUILD_TYPE=${BUILD_TYPE:-Release}
TARGET=${1:-all}

case $TARGET in
  windows)
    echo "Building for Windows..."
    docker run --rm -v $(pwd):/src \
      krthkj/cpp:cross-compile \
      bash -c "
        cd /src && 
        cmake -B build-windows \
          -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
          -DCMAKE_TOOLCHAIN_FILE=toolchains/windows-mingw-w64.cmake &&
        cmake --build build-windows --config $BUILD_TYPE --parallel
      "
    ;;
  macos)
    echo "Building for macOS..."
    docker run --rm -v $(pwd):/src \
      krthkj/cpp:cross-compile \
      bash -c "
        cd /src && 
        cmake -B build-macos \
          -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
          -DCMAKE_TOOLCHAIN_FILE=toolchains/macos-x64.cmake &&
        cmake --build build-macos --config $BUILD_TYPE --parallel
      "
    ;;
  all)
    $0 windows
    $0 macos
    ;;
  *)
    echo "Usage: $0 {windows|macos|all}"
    exit 1
    ;;
esac
```

### 5.2 Testing Cross-Compiled Binaries
```bash
#!/bin/bash
# scripts/test-cross-compiled.sh

set -e

echo "Testing Windows binaries with Wine..."
docker run --rm -v $(pwd):/src \
  krthkj/cpp:cross-compile \
  bash -c "
    cd /src &&
    wine build-windows/myapp.exe --version
  "

echo "Testing macOS binaries (basic checks)..."
docker run --rm -v $(pwd):/src \
  krthkj/cpp:cross-compile \
  bash -c "
    cd /src &&
    file build-macos/myapp &&
    otool -L build-macos/myapp
  "
```

## Phase 6: Advanced Features

### 6.1 Dependency Management
```yaml
# Add to Dockerfile.cross-compilation
# Windows dependencies
RUN wget -O /tmp/vcpkg.tar.gz https://github.com/Microsoft/vcpkg/archive/master.tar.gz && \
    tar -xf /tmp/vcpkg.tar.gz -C /opt && \
    /opt/vcpkg-master/bootstrap-vcpkg.sh && \
    ln -s /opt/vcpkg-master/vcpkg /usr/local/bin/vcpkg

# macOS dependencies
RUN git clone https://github.com/Homebrew/brew.git /opt/homebrew && \
    /opt/homebrew/bin/brew install --formula=openssl readline sqlite3
```

### 6.2 Automated Testing
```yaml
# .github/workflows/test-cross-compiled.yml
name: Test Cross-Compiled Binaries

on: [push, pull_request]

jobs:
  test-windows:
    runs-on: ubuntu-latest
    container: krthkj/cpp:cross-compile
    steps:
      - uses: actions/checkout@v4
      - name: Build Windows
        run: ./scripts/cross-compile.sh windows
      - name: Test with Wine
        run: wine build-windows/tests.exe

  test-macos:
    runs-on: macos-latest  # Use actual macOS for testing
    steps:
      - uses: actions/checkout@v4
      - name: Build native macOS
        run: |
          cmake -B build -DCMAKE_BUILD_TYPE=Release
          cmake --build build --parallel
      - name: Run tests
        run: ctest --test-dir build --output-on-failure
```

## Implementation Timeline

### Week 1-2: Foundation
- [ ] Create cross-compilation Dockerfile
- [ ] Set up basic CMake toolchain files
- [ ] Test Windows MinGW compilation
- [ ] Test macOS osxcross setup

### Week 3-4: CI/CD Integration
- [ ] Create GitHub Actions workflow
- [ ] Set up artifact management
- [ ] Configure release automation
- [ ] Add basic testing

### Week 5-6: Advanced Features
- [ ] Add dependency management (vcpkg/brew)
- [ ] Implement comprehensive testing
- [ ] Optimize build times
- [ ] Documentation and examples

## Resource Requirements

### Docker Hub Storage
- Cross-compilation base image: ~2GB
- Windows builder image: ~3GB
- macOS builder image: ~4GB
- Total: ~9GB additional storage

### CI/CD Resources
- GitHub Actions: 2000-3000 minutes/month
- Build time: 5-15 minutes per platform
- Storage: 5-10GB for artifacts

### Local Development
- Additional disk space: 10GB for cross-compilation tools
- RAM: 8GB+ recommended for smooth builds
- CPU: Multi-core for parallel compilation

## Success Metrics

1. **Build Success Rate**: >95% across all platforms
2. **Build Time**: <15 minutes for full cross-platform build
3. **Test Coverage**: >80% for cross-compiled binaries
4. **Artifact Size**: Optimized packages <50MB per platform
5. **Developer Experience**: Simple one-command builds

## Maintenance Plan

### Monthly
- Update cross-compilation toolchains
- Refresh base Docker images
- Update dependencies
- Review and optimize workflows

### Quarterly
- Evaluate new cross-compilation tools
- Update target OS versions
- Performance optimization
- Security updates

## Troubleshooting Guide

### Common Issues
1. **Missing Windows DLLs**: Use static linking or bundle dependencies
2. **macOS code signing**: Use ad-hoc signing for development builds
3. **Library compatibility**: Verify target OS compatibility
4. **Build failures**: Check toolchain file paths and versions

### Debug Commands
```bash
# Check cross-compilation tools
docker run --rm krthkj/cpp:cross-compile x86_64-w64-mingw32-gcc --version
docker run --rm krthkj/cpp:cross-compile o64-clang --version

# Verify CMake configuration
docker run --rm -v $(pwd):/src krthkj/cpp:cross-compile \
  cmake --system-information

# Test basic compilation
docker run --rm -v $(pwd):/src krthkj/cpp:cross-compile \
  bash -c "echo 'int main(){return 0;}' | x86_64-w64-mingw32-g++ -x c++ -"
```

This plan provides a comprehensive approach to cross-compilation while leveraging your existing Docker infrastructure. The modular design allows for incremental implementation and easy maintenance.