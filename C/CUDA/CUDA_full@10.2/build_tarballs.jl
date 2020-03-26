using BinaryBuilder

include("../../../fancy_toys.jl")

name = "CUDA_full"
version = v"10.2.89"

sources_linux = [
    FileSource("http://developer.download.nvidia.com/compute/cuda/10.2/Prod/local_installers/cuda_10.2.89_440.33.01_linux.run",
               "560d07fdcf4a46717f2242948cd4f92c5f9b6fc7eae10dd996614da913d5ca11", "installer.run")
]
sources_macos = [
    FileSource("http://developer.download.nvidia.com/compute/cuda/10.2/Prod/local_installers/cuda_10.2.89_mac.dmg",
               "51193fff427aad0a3a15223b1a202a6c6f0964fcc6fb0e6c77ca7cd5b6944d20", "installer.dmg")
]
sources_windows = [
    FileSource("http://developer.download.nvidia.com/compute/cuda/10.2/Prod/local_installers/cuda_10.2.89_441.22_win10.exe",
               "b538271c4d9ffce1a8520bf992d9bd23854f0f29cee67f48c6139e4cf301e253", "installer.exe")
]

script = raw"""
cd ${WORKSPACE}/srcdir

# use a temporary directory to avoid running out of tmpfs in srcdir on Travis
temp=${WORKSPACE}/tmpdir
mkdir ${temp}

apk add p7zip

if [[ ${target} == x86_64-linux-gnu ]]; then
    sh installer.run --tmpdir="${temp}" --target "${temp}" --noexec
    cd ${temp}/builds/cuda-toolkit
    find .

    # clean-up
    rm -r libnsight libnvvp nsightee_plugins nsight-compute-2019.5.0 nsight-systems-2019.5.2 doc

    mv * ${prefix}
    cd ${prefix}

    install_license EULA.txt
elif [[ ${target} == x86_64-apple-darwin* ]]; then
    7z x installer.dmg 5.hfs -o${temp}
    cd ${temp}
    7z x 5.hfs
    tar -zxf CUDAMacOSXInstaller/CUDAMacOSXInstaller.app/Contents/Resources/payload/cuda_mac_installer_tk.tar.gz
    cd Developer/NVIDIA/CUDA-*/
    find .

    # clean-up
    rm -r libnsight libnvvp nsightee_plugins nsight-compute-2019.5.0 NsightSystems-2019.5.2.16 doc

    mv * ${prefix}
    cd ${prefix}

    install_license EULA.txt
elif [[ ${target} == x86_64-w64-mingw32 ]]; then
    7z x installer.exe -o${temp}
    cd ${temp}
    find .

    for project in cuobjdump memcheck nvcc cupti nvdisasm curand cusparse npp cufft \
                   cublas cudart cusolver nvrtc nvgraph nvprof nvprune; do
        [[ -d ${project} ]] || { echo "${project} does not exist!"; exit 1; }
        cp -a ${project}/* ${prefix}
    done

    install_license EULA.txt

    # fixup
    chmod +x ${prefix}/bin/*.exe

    # clean-up
    rm ${prefix}/*.nvi
fi
"""

products = Product[
    # this JLL isn't meant for use by Julia packages, but only as build dependency
]

dependencies = []

non_reg_ARGS = filter(arg -> arg != "--register", ARGS)

if should_build_platform("x86_64-linux-gnu")
    build_tarballs(non_reg_ARGS, name, version, sources_linux, script,
                   [Linux(:x86_64)], products, dependencies;
                   skip_audit=true)
end

if should_build_platform("x86_64-apple-darwin14")
    build_tarballs(non_reg_ARGS, name, version, sources_macos, script,
                   [MacOS(:x86_64)], products, dependencies;
                   skip_audit=true)
end

if should_build_platform("x86_64-w64-mingw32")
    build_tarballs(ARGS, name, version, sources_windows, script,
                   [Windows(:x86_64)], products, dependencies;
                   skip_audit=true)
end
