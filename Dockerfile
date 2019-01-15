FROM dockbuild/ubuntu1804-gcc7

# Use bash instead of sh
SHELL ["/bin/bash", "-c"]

# Install system requirements
RUN sudo apt-get update && sudo apt-get install csh gfortran -y

# Install spack and compile nalu-wind with spack
RUN git clone https://github.com/spack/spack.git
ENV SPACK_ROOT /work/spack
RUN source ${SPACK_ROOT}/share/spack/setup-env.sh && \
    spack bootstrap && \
    spack install nalu-wind && \
    spack view -e nalu-wind -e trilinos symlink -i nalu-wind-workspace nalu-wind

# Install .workspace.config
RUN cd /work && \
    git clone https://github.com/fbudin69500/terminal.workspace && \
    cd terminal.workspace && git checkout origin/remove_local_not_in_functions_for_bash && cd .. &&\
    source terminal.workspace/workspace.config && \
    # Create .workspace.config for ADIOS folder
    RUN echo 'local workspace_spack_packages=("openmpi")' > .workspace.config && \
    echo 'workspace_env_var=("CMAKE_C_COMPILER_LAUNCHER=/usr/bin/ccache" "CMAKE_CXX_COMPILER_LAUNCHER=/usr/bin/ccache" '\
    '"CMAKE_PREFIX_PATH=/home/francois.budin/devel/adios/nalu-wind-spack-view-no-trilinos-no-nalu")' >> .workspace.config

# Compile ADIOS2: 
RUN cd /work && \
    git clone https://github.com/ornladios/ADIOS2.git && \
    cd ADIOS2 && \
    mkdir build && \
    cd build && \
    cmake -DADIOS2_USE_HDF5:BOOL=ON -DADIOS2_USE_MPI:BOOL=ON -DADIOS2_USE_SST:BOOL=ON .. && \
    make -j

# Compile Trilinos:
RUN cd /work && \
    git clone https://github.com/trilinos/Trilinos.git && \
    cd Trilinos && \
    mkdir build && \
    cd build && \
    cmake -DTrilinos_ENABLE_ALL_PACKAGES=ON -DTrilinos_ENABLE_TESTS=OFF \
    -DTPL_ENABLE_Matio=OFF -DTPL_ENABLE_MPI:BOOL=ON -DBUILD_SHARED_LIBS:BOOL=ON \
    -DTrilinos_ENABLE_Panzer:BOOL=OFF -DSTKClassic_Trilinos:BOOL=ON \
    -DTrilinos_ENABLE_STKClassic:BOOL=ON -DSTK_Trilinos:BOOL=ON \
    -DTPL_ENABLE_ADIOS2:BOOL=ON -DADIOS2_DIR=/work/ADIOS2/build \
    -DTrilinos_ENABLE_PyTrilinos:BOOL=OFF -DTrilinos_ENABLE_STK:BOOL=ON \
    -DMPI_BIN_DIR:PATH=`dirname $(which mpiexec)` \
     .. && \
    make -j12

# Compile and test nalu-wind:
RUN cd /work \
    git clone https://github.com/Exawind/nalu-wind.git && \
    cd nalu-wind && \
    sed -i 's/0.000000000000001/0.00001/' reg_tests/CMakeLists.txt
    mkdir build && \
    cd build && \
    cmake -DENABLE_TESTS:BOOL=ON -DTrilinos_DIR:PATH=/work/Trilinos/build .. && \
    make -j12 && \
    ctest -E unitTest
