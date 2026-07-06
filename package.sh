#!/bin/sh
set -e

# compile for version
make
if [ $? -ne 0 ]; then
    echo "make error"
    exit 1
fi

frp_version=`./bin/kube-tunnel-server --version`
echo "build version: $frp_version"

# cross_compiles
make -f ./Makefile.cross-compiles

for file in ./release/frpc_*; do
    [ -e "$file" ] || continue
    mv "$file" "${file%/*}/kube-tunnel-client_${file##*/frpc_}"
done
for file in ./release/frps_*; do
    [ -e "$file" ] || continue
    mv "$file" "${file%/*}/kube-tunnel-server_${file##*/frps_}"
done

rm -rf ./release/packages
mkdir -p ./release/packages

os_all='linux windows darwin freebsd android'
arch_all='386 amd64 arm arm64 mips64 mips64le mips mipsle riscv64 loong64'
extra_all='_ hf'

cd ./release

for os in $os_all; do
    for arch in $arch_all; do
        for extra in $extra_all; do
            suffix="${os}_${arch}"
            if [ "x${extra}" != x"_" ]; then
                suffix="${os}_${arch}_${extra}"
            fi
            frp_dir_name="kube-tunnel_${frp_version}_${suffix}"
            frp_path="./packages/kube-tunnel_${frp_version}_${suffix}"

            if [ "x${os}" = x"windows" ]; then
                if [ ! -f "./kube-tunnel-client_${os}_${arch}.exe" ]; then
                    continue
                fi
                if [ ! -f "./kube-tunnel-server_${os}_${arch}.exe" ]; then
                    continue
                fi
                mkdir ${frp_path}
                mv ./kube-tunnel-client_${os}_${arch}.exe ${frp_path}/kube-tunnel-client.exe
                mv ./kube-tunnel-server_${os}_${arch}.exe ${frp_path}/kube-tunnel-server.exe
            else
                if [ ! -f "./kube-tunnel-client_${suffix}" ]; then
                    continue
                fi
                if [ ! -f "./kube-tunnel-server_${suffix}" ]; then
                    continue
                fi
                mkdir ${frp_path}
                mv ./kube-tunnel-client_${suffix} ${frp_path}/kube-tunnel-client
                mv ./kube-tunnel-server_${suffix} ${frp_path}/kube-tunnel-server
            fi  
            cp ../LICENSE ${frp_path}
            cp -f ../conf/frpc.toml ${frp_path}
            cp -f ../conf/frps.toml ${frp_path}

            # packages
            cd ./packages
            if [ "x${os}" = x"windows" ]; then
                zip -rq ${frp_dir_name}.zip ${frp_dir_name}
            else
                tar -zcf ${frp_dir_name}.tar.gz ${frp_dir_name}
            fi  
            cd ..
            rm -rf ${frp_path}
        done
    done
done

cd -
