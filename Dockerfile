FROM arm64v8/debian:buster

ARG DEBIAN_FRONTEND="noninteractive"
ARG TENSORFLOW_COMMIT="a0043f9262dc1b0e7dc4bdf3a7f0ef0bebc4891e"
ARG SRC_DIR="/src"

ENV TERM "xterm-256color"
SHELL ["/bin/bash", "-c"]

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    apt-utils \
    ca-certificates

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    vim \
    cmake \
    asciidoc \
    git \
    curl \
    wget \
    autoconf \
    autogen \
    automake \
    libtool \
    scons \
    make \
    gcc \
    g++ \
    unzip \
    bzip2 \
    pkg-config \
    libgtk2.0-dev \
    libavcodec-dev \
    libavformat-dev \
    libavresample-dev \
    libswscale-dev \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libopenblas-dev \
    liblapack-dev \
    libeigen3-dev \
    gstreamer
    python3 \
    python3-pip \
    python3-scipy \
    python3-zmq \
    python3-sklearn \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p ${SRC_DIR}

RUN start_time="$(date -u +%s)" && \
    echo -e "\e[32mInstalling cppzmq\e[0m" && \
    cd ${SRC_DIR} && \
    git clone --depth 1 https://github.com/zeromq/libzmq.git && \
    cd libzmq && mkdir build && cd build && \
    cmake .. && make -j$(nproc) install && \
    cd ${SRC_DIR} && \
    git clone --depth 1 https://github.com/zeromq/cppzmq.git && \
    cd cppzmq && mkdir build && cd build && \
    cmake .. && make -j$(nproc) install && \
    rm -rfv ${SRC_DIR}/libzmq ${SRC_DIR}/cppzmq && \
    end_time="$(date -u +%s)" && \
    elapsed="$(($end_time-$start_time))" && \
    echo -e "\e[33mInstalling cppzmq took $elapsed seconds.\e[0m"

RUN start_time="$(date -u +%s)" && \
    echo -e "\e[32mInstalling boost\e[0m" && \
    cd ${SRC_DIR} && \
    wget https://dl.bintray.com/boostorg/release/1.64.0/source/boost_1_64_0.tar.bz2 && \
    tar -xf boost_1_64_0.tar.bz2 && \
    cd boost_1_64_0 && \
    ./bootstrap.sh && \
    cp tools/build/example/user-config.jam project-config.jam && \
    sed -i 's/# using gcc ;/using gcc : arm : aarch64-linux-gnu-g++ ;/g' project-config.jam && \
    ./b2 install link=static cxxflags=-fPIC toolset=gcc-arm \
    --with-filesystem --with-test --with-log --with-program_options \
    --j$(nproc) && \
    end_time="$(date -u +%s)" && \
    elapsed="$(($end_time-$start_time))" && \
    echo -e "\e[33mInstalling boost took $elapsed seconds.\e[0m"

RUN start_time="$(date -u +%s)" && \
    echo -e "\e[32mInstalling Arm Compute Library\e[0m" && \
    cd ${SRC_DIR} && \
    git clone --depth 1 https://github.com/ARM-software/ComputeLibrary.git && \
    cd ComputeLibrary && \
    scons arch="arm64-v8a" neon=1 opencl=0 embed_kernels=0 Werror=0 \
        extra_cxx_flags="-fPIC" benchmark_tests=0 examples=0 validation_tests=0 \
        os=linux -j $(nproc) && \
    cp -r arm_compute /usr/lib && \
    cp build/*.a build/*.so /usr/lib && \
    end_time="$(date -u +%s)" && \
    elapsed="$(($end_time-$start_time))" && \
    echo -e "\e[33mInstalling Arm Compute Library took $elapsed seconds.\e[0m"

RUN start_time="$(date -u +%s)" && \
    echo -e "\e[32mInstalling Tensorflow\e[0m" && \
    cd ${SRC_DIR} && \
    git clone https://github.com/tensorflow/tensorflow.git && \
    cd tensorflow && \
    git checkout ${TENSORFLOW_COMMIT} && \
    end_time="$(date -u +%s)" && \
    elapsed="$(($end_time-$start_time))" && \
    echo -e "\e[33mInstalling Tensorflow took $elapsed seconds.\e[0m"

RUN start_time="$(date -u +%s)" && \
    echo -e "\e[32mInstalling Protobuf\e[0m" && \
    cd ${SRC_DIR} && \
    git clone --branch 3.5.x https://github.com/protocolbuffers/protobuf.git && \
    cd protobuf && \
    ./autogen.sh && \
    mkdir build && \
    cd build && \
    ../configure && \
    make -j$(nproc) install && \
    make clean && \
    end_time="$(date -u +%s)" && \
    elapsed="$(($end_time-$start_time))" && \
    echo -e "\e[33mInstalling Protobuf took $elapsed seconds.\e[0m"

RUN start_time="$(date -u +%s)" && \
    echo -e "\e[32mInstalling Flatbuffers\e[0m" && \
    cd ${SRC_DIR} && \
    git clone --depth 1 https://github.com/google/flatbuffers.git && \
    cd flatbuffers && \
    mkdir build && cd build && \
    cmake -G "Unix Makefiles" .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_FLAGS=-fPIC \
        -DFLATBUFFERS_BUILD_TESTS=OFF && \
    make -j$(nproc) install && \
    end_time="$(date -u +%s)" && \
    elapsed="$(($end_time-$start_time))" && \
    echo -e "\e[33mInstalling Flatbuffers took $elapsed seconds.\e[0m"

RUN start_time="$(date -u +%s)" && \
    echo -e "\e[32mInstalling ArmNN\e[0m" && \
    cd ${SRC_DIR} && \
    git clone --depth 1 https://github.com/ARM-software/armnn.git && \
    cd ${SRC_DIR}/tensorflow && \
    ${SRC_DIR}/armnn/scripts/generate_tensorflow_protobuf.sh ${SRC_DIR}/generated_tensorflow_protobufs /usr/local && \
    cd ${SRC_DIR}/armnn && \
    mkdir -p build && cd build && \
    cmake ..  \
    -DCMAKE_CXX_FLAGS="-Wno-error=sign-conversion" \
    -DCMAKE_BUILD_TYPE=Release \
    -DARMCOMPUTE_ROOT=${SRC_DIR}/ComputeLibrary \
    -DARMCOMPUTE_BUILD_DIR=${SRC_DIR}/ComputeLibrary/build \
    -DBOOST_ROOT=/usr \
    -DTF_GENERATED_SOURCES=${SRC_DIR}/generated_tensorflow_protobufs  \
    -DBUILD_TF_PARSER=1 \
    -DPROTOBUF_ROOT=/usr/local \
    -DPROTOBUF_INCLUDE_DIRS=/usr/local/include \
    -DARMCOMPUTENEON=1  \
    -DARMCOMPUTECL=0 \
    -DPROTOBUF_LIBRARY_DEBUG=/usr/local/lib/libprotobuf.so \
    -DPROTOBUF_LIBRARY_RELEASE=/usr/local/lib/libprotobuf.so \
    -DBUILD_TF_LITE_PARSER=1 \
    -DFLATBUFFERS_ROOT=${SRC_DIR}/flatbuffers \
    -DFLATBUFFERS_LIBRARY=${SRC_DIR}/flatbuffers/build/libflatbuffers.a \
    -DTF_LITE_GENERATED_PATH=${SRC_DIR}/tensorflow/tensorflow/lite/schema && \
    make -j $(nproc) install && \
    end_time="$(date -u +%s)" && \
    elapsed="$(($end_time-$start_time))" && \
    echo -e "\e[33mInstalling ArmNN took $elapsed seconds.\e[0m"

RUN start_time="$(date -u +%s)" && \
    echo -e "\e[32mInstalling Tensorflow Lite\e[0m" && \
    cd ${SRC_DIR}/tensorflow && \
    git checkout master && \
    ./tensorflow/lite/tools/make/download_dependencies.sh && \
    ./tensorflow/lite/tools/make/build_aarch64_lib.sh && \
    cp tensorflow/lite/tools/make/gen/aarch64_armv8-a/lib/libtensorflow-lite.a /usr/local/lib && \
    cp -r tensorflow /usr/include && \
    find /usr/include/tensorflow -type f  ! -name "*.h"  -delete && \
    find /usr/include/tensorflow -type d -empty -delete && \
    git checkout ${TENSORFLOW_COMMIT} && \
    end_time="$(date -u +%s)" && \
    elapsed="$(($end_time-$start_time))" && \
    echo -e "\e[33mInstalling Tensorflow Lite took $elapsed seconds.\e[0m"

RUN echo "deb http://deb.debian.org/debian testing main contrib non-free" >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    libopencv-dev \
    python3-opencv && \
    pip3 install flatbuffers && \
    rm -rf /var/lib/apt/lists/*

RUN rm -rf ${SRC_DIR} && \
    echo "\e[33mInstallation completed successfully.\e[0m"
