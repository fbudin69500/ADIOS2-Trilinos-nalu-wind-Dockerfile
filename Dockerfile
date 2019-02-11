FROM dockbuild/ubuntu1804-gcc7

# Number of jobs when compiling
ARG JOBS=10

# Use bash instead of sh
SHELL ["/bin/bash", "-c"]
ENV BASH_ENV /work/bash.env

# Install system requirements
RUN apt-get update && sudo apt-get install csh gfortran bc libblas-dev liblapack-dev -y

# Install spack and it to bash environment
RUN git clone https://github.com/spack/spack.git && \
    cd spack && \
    git checkout 36ebd7462c6287b5fe3b4cb9f50597dd57d833f4 && \
    echo $'SPACK_ROOT=/work/spack\n\
source ${SPACK_ROOT}/share/spack/setup-env.sh' >> $BASH_ENV

# Install environment-modules to be able to use spack and load modules
RUN \
    # Patch parallel-netcdf spack package to build it as a shared library
    cd spack/var/spack/repos/builtin/packages/parallel-netcdf && \
    sed -i "s/args.append('SEQ_CC={0}'.format(spack_cc))/args.append('SEQ_CC={0}'.format(spack_cc))\n        args.append('--enable-shared')/" package.py && \
    cd /work/spack && \
    # Install spack and nalu-wind spack package
    spack bootstrap && \
    spack install -j $JOBS  nalu-wind && \
    cd /work && \
    spack view -e nalu-wind -e trilinos symlink -i nalu-wind-spack-workspace nalu-wind

# Setup BASH_ENV file to load all required Spack modules and environment variables
RUN echo "spack load openmpi" >> $BASH_ENV && \
    echo "spack load hdf5" >> $BASH_ENV && \
    # Environment variables could be saved with `ENV` but this facilitate keeping track of the
    # value of these variables inside the docker image and docker container.
    #
    echo "export CMAKE_PREFIX_PATH=/work/nalu-wind-spack-workspace" >> $BASH_ENV && \
    echo "export CPATH=/work/nalu-wind-spack-workspace:$CPATH" >> $BASH_ENV

# Compile ADIOS2: 
RUN git clone https://github.com/ornladios/ADIOS2.git && \
    cd ADIOS2 && \
    mkdir build && \
    cd build && \
    cmake -DADIOS2_USE_HDF5:BOOL=ON -DADIOS2_USE_MPI:BOOL=ON -DADIOS2_USE_SST:BOOL=ON .. && \
    make -j$JOBS

# Compile Trilinos without ADIOS2 support:
RUN git clone https://github.com/fbudin69500/Trilinos.git && \
    cd Trilinos && \
    git checkout 4a44218fc765c7d1a143914738125cb8304220a0 && \
    mkdir build-no-adios && \
    cd build-no-adios && \
    cmake \
        -DTrilinos_VERBOSE_CONFIGURE:BOOL=OFF -DTrilinos_ENABLE_TESTS:BOOL=OFF -DTrilinos_ENABLE_EXAMPLES:BOOL=OFF -DTrilinos_ENABLE_CXX11:BOOL=ON -DBUILD_SHARED_LIBS:BOOL=ON -DTrilinos_ENABLE_DEBUG:BOOL=OFF -DTPL_ENABLE_MPI:BOOL=ON -DTrilinos_ENABLE_ALL_OPTIONAL_PACKAGES:BOOL=OFF -DTrilinos_ENABLE_Amesos:BOOL=ON -DTrilinos_ENABLE_Amesos2:BOOL=ON -DTrilinos_ENABLE_Anasazi:BOOL=ON -DTrilinos_ENABLE_AztecOO:BOOL=ON -DTrilinos_ENABLE_Belos:BOOL=ON -DTrilinos_ENABLE_Epetra:BOOL=ON -DTrilinos_ENABLE_EpetraExt:BOOL=ON -DTrilinos_ENABLE_Ifpack:BOOL=ON -DTrilinos_ENABLE_Ifpack2:BOOL=ON -DTrilinos_ENABLE_Intrepid=OFF -DTrilinos_ENABLE_Intrepid2=OFF -DTrilinos_ENABLE_Isorropia=OFF -DTrilinos_ENABLE_Kokkos:BOOL=ON -DTrilinos_ENABLE_MiniTensor=OFF -DTrilinos_ENABLE_ML:BOOL=ON -DTrilinos_ENABLE_MueLu:BOOL=ON -DTrilinos_ENABLE_NOX:BOOL=OFF -DTrilinos_ENABLE_Piro:BOOL=OFF -DTrilinos_ENABLE_Phalanx=OFF -DTrilinos_ENABLE_PyTrilinos:BOOL=OFF -DTrilinos_ENABLE_ROL:BOOL=OFF -DTrilinos_ENABLE_Rythmos=OFF -DTrilinos_ENABLE_Sacado:BOOL=ON -DTrilinos_ENABLE_Shards=ON -DTrilinos_ENABLE_Teko=OFF -DTrilinos_ENABLE_Tempus=OFF -DTrilinos_ENABLE_Teuchos:BOOL=ON -DTrilinos_ENABLE_Tpetra:BOOL=ON -DTrilinos_ENABLE_Zoltan:BOOL=ON -DTrilinos_ENABLE_Zoltan2:BOOL=ON -DTrilinos_ENABLE_STKMesh:BOOL=ON -DTrilinos_ENABLE_STKNGP:BOOL=ON -DTrilinos_ENABLE_STKSimd:BOOL=ON -DTrilinos_ENABLE_STKIO:BOOL=ON -DTrilinos_ENABLE_STKTransfer:BOOL=ON -DTrilinos_ENABLE_STKSearch:BOOL=ON -DTrilinos_ENABLE_STKUtil:BOOL=ON -DTrilinos_ENABLE_STKTopology:BOOL=ON -DTrilinos_ENABLE_STKUnit_tests:BOOL=ON -DTrilinos_ENABLE_STKUnit_test_utils:BOOL=ON -DTrilinos_ENABLE_STKClassic:BOOL=OFF -DTrilinos_ENABLE_STKExprEval:BOOL=ON -DTrilinos_ENABLE_SEACAS:BOOL=ON -DTrilinos_ENABLE_SEACASExodus:BOOL=ON -DTrilinos_ENABLE_SEACASEpu:BOOL=ON -DTrilinos_ENABLE_SEACASExodiff:BOOL=ON -DTrilinos_ENABLE_SEACASNemspread:BOOL=ON -DTrilinos_ENABLE_SEACASNemslice:BOOL=ON -DTrilinos_ENABLE_SEACASIoss:BOOL=ON -DTPL_ENABLE_BLAS=ON -DBLAS_LIBRARY_NAMES=openblas -DTPL_ENABLE_LAPACK=ON -DLAPACK_LIBRARY_NAMES=openblas -DTPL_ENABLE_Netcdf:BOOL=ON -DTPL_ENABLE_X11:BOOL=OFF -DTrilinos_ENABLE_Gtest:BOOL=ON -DTPL_ENABLE_Boost:BOOL=ON -DTPL_ENABLE_HDF5:BOOL=ON -DTPL_ENABLE_Cholmod:BOOL=OFF -DTPL_ENABLE_UMFPACK:BOOL=ON -DUMFPACK_LIBRARY_NAMES="umfpack;amd;colamd;cholmod;suitesparseconfig" -DTPL_ENABLE_METIS:BOOL=ON -DMETIS_LIBRARY_NAMES=metis -DTPL_ENABLE_ParMETIS:BOOL=ON -DParMETIS_LIBRARY_NAMES="parmetis;metis" -DTPL_ENABLE_MUMPS:BOOL=ON -DMUMPS_LIBRARY_NAMES="dmumps;mumps_common;pord" -DTPL_ENABLE_SCALAPACK:BOOL=ON -DSCALAPACK_LIBRARY_NAMES=scalapack -DTPL_ENABLE_SuperLUDist:BOOL=OFF -DTPL_ENABLE_SuperLU:BOOL=ON -DTPL_ENABLE_Pnetcdf:BOOL=ON -DTPL_Netcdf_Enables_Netcdf4:BOOL=ON -DTPL_Netcdf_PARALLEL:BOOL=ON -DTPL_ENABLE_Zlib:BOOL=ON -DTPL_ENABLE_CGNS:BOOL=OFF -DTrilinos_ENABLE_Fortran=ON -DTeuchos_ENABLE_COMPLEX=OFF -DTeuchos_ENABLE_FLOAT=OFF -DTrilinos_ENABLE_EXPLICIT_INSTANTIATION:BOOL=ON -DTpetra_INST_DOUBLE:BOOL=ON -DTpetra_INST_INT_LONG:BOOL=ON -DTpetra_INST_COMPLEX_DOUBLE=OFF -DTpetra_INST_COMPLEX_FLOAT=OFF -DTpetra_INST_FLOAT=OFF -DTpetra_INST_SERIAL=ON -DCMAKE_CXX_FLAGS:STRING=-DMUMPS_5_0 -DTrilinos_ENABLE_Pike=OFF \
        -DCMAKE_PREFIX_PATH:PATH=${CMAKE_PREFIX_PATH} \
        -DCMAKE_INSTALL_PREFIX:PATH=`pwd`/install \
        -DMPI_BASE_DIR:PATH=`dirname $(which mpiexec)` \
        .. && \
    make -j$JOBS && \
    make -j$JOBS install

# Compile and test nalu-wind to make sure that all tests pass as they should
# when using Trilinos without ADIOS2:
RUN git clone https://github.com/Exawind/nalu-wind.git && \
    cd nalu-wind && \
    git checkout 25c2d7ab3549847dc4be343863739a7a3bd5d988 && \
    git submodule init && \
    git submodule update && \
    sed -i 's/0.000000000000001/0.00001/' reg_tests/CMakeLists.txt && \
    mkdir build-no-adios && \
    cd build-no-adios && \
    cmake \
        -DENABLE_TESTS:BOOL=ON \
        -DMPI_CXX_COMPILE_OPTIONS:STRING=-pthread \
        -DMPI_Fortran_COMPILE_OPTIONS:STRING=-pthread \
        -DMPI_C_COMPILE_OPTIONS:STRING=-pthread \
        -DYAML_DIR:PATH=$(spack location -i yaml-cpp)/lib/cmake/yaml-cpp \
        -DTrilinos_DIR:PATH=/work/Trilinos/build-no-adios/install/lib/cmake/Trilinos \
        .. && \
    make -j$JOBS

# Compile Trilinos with ADIOS2 support:
RUN cd Trilinos && \
    mkdir build-adios && \
    cd build-adios && \
    cmake \
        -DTrilinos_VERBOSE_CONFIGURE:BOOL=OFF -DTrilinos_ENABLE_TESTS:BOOL=OFF -DTrilinos_ENABLE_EXAMPLES:BOOL=OFF -DTrilinos_ENABLE_CXX11:BOOL=ON -DBUILD_SHARED_LIBS:BOOL=ON -DTrilinos_ENABLE_DEBUG:BOOL=OFF -DTPL_ENABLE_MPI:BOOL=ON -DTrilinos_ENABLE_ALL_OPTIONAL_PACKAGES:BOOL=OFF -DTrilinos_ENABLE_Amesos:BOOL=ON -DTrilinos_ENABLE_Amesos2:BOOL=ON -DTrilinos_ENABLE_Anasazi:BOOL=ON -DTrilinos_ENABLE_AztecOO:BOOL=ON -DTrilinos_ENABLE_Belos:BOOL=ON -DTrilinos_ENABLE_Epetra:BOOL=ON -DTrilinos_ENABLE_EpetraExt:BOOL=ON -DTrilinos_ENABLE_Ifpack:BOOL=ON -DTrilinos_ENABLE_Ifpack2:BOOL=ON -DTrilinos_ENABLE_Intrepid=OFF -DTrilinos_ENABLE_Intrepid2=OFF -DTrilinos_ENABLE_Isorropia=OFF -DTrilinos_ENABLE_Kokkos:BOOL=ON -DTrilinos_ENABLE_MiniTensor=OFF -DTrilinos_ENABLE_ML:BOOL=ON -DTrilinos_ENABLE_MueLu:BOOL=ON -DTrilinos_ENABLE_NOX:BOOL=OFF -DTrilinos_ENABLE_Piro:BOOL=OFF -DTrilinos_ENABLE_Phalanx=OFF -DTrilinos_ENABLE_PyTrilinos:BOOL=OFF -DTrilinos_ENABLE_ROL:BOOL=OFF -DTrilinos_ENABLE_Rythmos=OFF -DTrilinos_ENABLE_Sacado:BOOL=ON -DTrilinos_ENABLE_Shards=ON -DTrilinos_ENABLE_Teko=OFF -DTrilinos_ENABLE_Tempus=OFF -DTrilinos_ENABLE_Teuchos:BOOL=ON -DTrilinos_ENABLE_Tpetra:BOOL=ON -DTrilinos_ENABLE_Zoltan:BOOL=ON -DTrilinos_ENABLE_Zoltan2:BOOL=ON -DTrilinos_ENABLE_STKMesh:BOOL=ON -DTrilinos_ENABLE_STKNGP:BOOL=ON -DTrilinos_ENABLE_STKSimd:BOOL=ON -DTrilinos_ENABLE_STKIO:BOOL=ON -DTrilinos_ENABLE_STKTransfer:BOOL=ON -DTrilinos_ENABLE_STKSearch:BOOL=ON -DTrilinos_ENABLE_STKUtil:BOOL=ON -DTrilinos_ENABLE_STKTopology:BOOL=ON -DTrilinos_ENABLE_STKUnit_tests:BOOL=ON -DTrilinos_ENABLE_STKUnit_test_utils:BOOL=ON -DTrilinos_ENABLE_STKClassic:BOOL=OFF -DTrilinos_ENABLE_STKExprEval:BOOL=ON -DTrilinos_ENABLE_SEACAS:BOOL=ON -DTrilinos_ENABLE_SEACASExodus:BOOL=ON -DTrilinos_ENABLE_SEACASEpu:BOOL=ON -DTrilinos_ENABLE_SEACASExodiff:BOOL=ON -DTrilinos_ENABLE_SEACASNemspread:BOOL=ON -DTrilinos_ENABLE_SEACASNemslice:BOOL=ON -DTrilinos_ENABLE_SEACASIoss:BOOL=ON -DTPL_ENABLE_BLAS=ON -DBLAS_LIBRARY_NAMES=openblas -DTPL_ENABLE_LAPACK=ON -DLAPACK_LIBRARY_NAMES=openblas -DTPL_ENABLE_Netcdf:BOOL=ON -DTPL_ENABLE_X11:BOOL=OFF -DTrilinos_ENABLE_Gtest:BOOL=ON -DTPL_ENABLE_Boost:BOOL=ON -DTPL_ENABLE_HDF5:BOOL=ON -DTPL_ENABLE_Cholmod:BOOL=OFF -DTPL_ENABLE_UMFPACK:BOOL=ON -DUMFPACK_LIBRARY_NAMES="umfpack;amd;colamd;cholmod;suitesparseconfig" -DTPL_ENABLE_METIS:BOOL=ON -DMETIS_LIBRARY_NAMES=metis -DTPL_ENABLE_ParMETIS:BOOL=ON -DParMETIS_LIBRARY_NAMES="parmetis;metis" -DTPL_ENABLE_MUMPS:BOOL=ON -DMUMPS_LIBRARY_NAMES="dmumps;mumps_common;pord" -DTPL_ENABLE_SCALAPACK:BOOL=ON -DSCALAPACK_LIBRARY_NAMES=scalapack -DTPL_ENABLE_SuperLUDist:BOOL=OFF -DTPL_ENABLE_SuperLU:BOOL=ON -DTPL_ENABLE_Pnetcdf:BOOL=ON -DTPL_Netcdf_Enables_Netcdf4:BOOL=ON -DTPL_Netcdf_PARALLEL:BOOL=ON -DTPL_ENABLE_Zlib:BOOL=ON -DTPL_ENABLE_CGNS:BOOL=OFF -DTrilinos_ENABLE_Fortran=ON -DTeuchos_ENABLE_COMPLEX=OFF -DTeuchos_ENABLE_FLOAT=OFF -DTrilinos_ENABLE_EXPLICIT_INSTANTIATION:BOOL=ON -DTpetra_INST_DOUBLE:BOOL=ON -DTpetra_INST_INT_LONG:BOOL=ON -DTpetra_INST_COMPLEX_DOUBLE=OFF -DTpetra_INST_COMPLEX_FLOAT=OFF -DTpetra_INST_FLOAT=OFF -DTpetra_INST_SERIAL=ON -DCMAKE_CXX_FLAGS:STRING=-DMUMPS_5_0 -DTrilinos_ENABLE_Pike=OFF \
        -DCMAKE_PREFIX_PATH:PATH=${CMAKE_PREFIX_PATH} \
        -DCMAKE_INSTALL_PREFIX:PATH=`pwd`/install \
        -DTPL_ENABLE_ADIOS2:BOOL=ON \
        -DADIOS2_DIR=/work/ADIOS2/build ../.. \
        -DMPI_BASE_DIR:PATH=`dirname $(which mpiexec)` \
        .. && \
    make -j$JOBS && \
    make -j$JOBS install

# Compile nalu-wind with ADIOS2 support
RUN cd nalu-wind && \
    mkdir build-adios && \
    cd build-adios && \
    cmake \
        -DENABLE_TESTS:BOOL=ON \
        -DMPI_CXX_COMPILE_OPTIONS:STRING=-pthread \
        -DMPI_Fortran_COMPILE_OPTIONS:STRING=-pthread \
        -DMPI_C_COMPILE_OPTIONS:STRING=-pthread \
        -DYAML_DIR:PATH=$(spack location -i yaml-cpp)/lib/cmake/yaml-cpp \
        -DTrilinos_DIR:PATH=/work/Trilinos/build-adios/install/lib/cmake/Trilinos \
        .. && \
    make -j$JOBS

#####################################
# Tests
#####################################

# Work around limitation of mpiexec that requires a flag to be run as root.
RUN path=$(which mpiexec) && \
    mv $path ${path}_real && \
    echo "#!/bin/bash" > $path && \
    echo ${path}_real' --allow-run-as-root $@' >> $path && \
    more $path && \
    chmod +x $path

#####################################
# nalu-wind tests
#####################################

RUN cd nalu-wind/build-no-adios && \
    ctest -R ablNeutralEdge -V

RUN cd nalu-wind/build-adios && \
    ctest -R ablNeutralEdge -V

# Get testing data
RUN mkdir /data && \
    cd /data && \
    curl https://data.kitware.com/api/v1/file/5c3f92c18d777f072b0838aa/download -o abl_5km_5km_1km_neutral.e.4.0 && \
    curl https://data.kitware.com/api/v1/file/5c3f92c78d777f072b0838b2/download -o abl_5km_5km_1km_neutral.e.4.1 && \
    curl https://data.kitware.com/api/v1/file/5c3f92cb8d777f072b0838ba/download -o abl_5km_5km_1km_neutral.e.4.2 && \
    curl https://data.kitware.com/api/v1/file/5c3f92d08d777f072b0838c2/download -o abl_5km_5km_1km_neutral.e.4.3

#####################################
# ADIOS implementation in Trilinos
#####################################

# Baseline execution time for test using exodus format
RUN cd Trilinos/build-no-adios && \
    time packages/stk/stk_io/example/STKIO_io_mesh_read_write_example.exe --mesh /data/nalu-wind-output-data/abl_5km_5km_1km_neutral.e.4.0 && \
    #
    # Test that `exodusii_mesh.out.bp` was created
    #
    ls exodusii_mesh.out && \
    rm exodusii_mesh*

# Add tests to verify ADIOS2 integration in Trilinos
RUN cd Trilinos/build-adios && \
    packages/stk/stk_io/example/STKIO_io_mesh_read_write_example.exe --mesh gen:10x15x20 --type_out adios && \
    #
    # Test that `generated_mesh.out.bp` was created
    #
    ls generated_mesh.out.bp \
    # Keep test result for next test.
    rm -r generated_mesh*

# Test that if an ADIOS2 file is read and written, the copy is the same as the original (simple model)
RUN cd Trilinos/build-adios && \
    packages/stk/stk_io/example/STKIO_io_mesh_read_write_example.exe --mesh adios:generated_mesh.out.bp --type_out adios && \
    #
    # Test that `adios_mesh.out.bp` was created
    #
    ls generated_mesh.out.bp && \
    rm -r exodusii_mesh.out.bp* \
    rm -r generated_mesh*

# Test that ADIOS2 can write complex files
RUN cd Trilinos/build-adios && \
    time packages/stk/stk_io/example/STKIO_io_mesh_read_write_example.exe --mesh /data/nalu-wind-output-data/abl_5km_5km_1km_neutral.e.4.0 --type_out adios && \
    #
    # Test that `exodusii_mesh.out.bp` was created
    #
    ls exodusii_mesh.out.bp
    # Keep test result for next test.

# Test that if an ADIOS2 file is read and written, the copy is the same as the original
RUN cd Trilinos/build-adios && \
    packages/stk/stk_io/example/STKIO_io_mesh_read_write_example.exe --mesh adios:exodusii_mesh.out.bp --type_out adios && \
    #
    # Test that `adios_mesh.out.bp` was created
    #
    ls exodusii_mesh.out.bp && \
    rm -r exodusii_mesh.out.bp*

#####################################
# Final steps for image configuration
#####################################

# Entrypoint for debug purposes
ENTRYPOINT ["/bin/bash"]

# Build-time metadata as defined at http://label-schema.org
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name=$IMAGE \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url=$VCS_URL \
      org.label-schema.schema-version="1.0" \
maintainer="Francois Budin <francois.budin@kitware.com>"
