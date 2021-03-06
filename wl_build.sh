#!/bin/bash

. $HOME/.config/wayland-build-tools/wl_defines.sh

if [ ! -e $WLROOT ]; then
	exit 1
fi

# Bail if errors
set -e

gen() {
	pkg=$1
	shift
	echo
	echo $pkg
	cd $WLROOT/$pkg
	echo "./autogen.sh --prefix=$WLD $*"
	./autogen.sh --prefix=$WLD $*
}

compile() {
	make -j32 && make install
	if [ $? != 0 ]; then
		echo "Build Error.  Terminating"
		exit
	fi
}

distcheck() {
	make distcheck
}

# TODO: Check if tree doesn't exist
# TODO: Log output
# TODO: If it's been a while since we last ran successfully, then
#       delete $WLD

mkdir -p $WLD/share/aclocal

gen wayland
compile

gen wayland-protocols
compile

gen drm --disable-libkms
compile

gen proto
compile

gen macros
compile

gen libxcb
compile

gen presentproto
compile

gen dri3proto
compile

gen libxshmfence
compile

gen libxkbcommon \
	--with-xkb-config-root=/usr/share/X11/xkb \
	--with-x-locale-root=/usr/share/X11/locale \
	--disable-x11
compile

llvm_drivers=swrast,nouveau,r300
vga_pci=$(lspci | grep VGA | head -n1)
vga_name=${vga_pci#*controller: }
vga_manu=${vga_name%% *}
if [ "${vga_manu}" = "NVIDIA" ]; then
	llvm_drivers=swrast,nouveau
fi

echo
echo "mesa"
cd $WLROOT/mesa
git clean -xfd
./autogen.sh --prefix=$WLD \
	--enable-gles2 \
	--with-egl-platforms=x11,wayland,drm \
	--enable-gbm \
	--enable-shared-glapi \
	--disable-llvm-shared-libs \
	--disable-dri3 \
	--with-gallium-drivers=$llvm_drivers
compile


gen pixman
compile

gen cairo --enable-xcb --enable-gl
compile

echo
echo "libunwind"
cd $WLROOT/libunwind
autoreconf -i
./configure --prefix=$WLD
compile

gen libevdev
compile

gen wayland-protocols
compile

gen libwacom
compile

echo
echo libinput
cd $WLROOT/libinput
rm -rf $WLROOT/libinput/builddir/
mkdir $WLROOT/libinput/builddir/
echo "meson --prefix=$WLD builddir/"
meson --prefix=$WLD -Ddebug-gui=false builddir/
ninja -C builddir/
ninja -C builddir/ install
# sudo udevadm hwdb --update


if [ ${INCLUDE_XWAYLAND} ]; then
	if [ ${WL_BITS} = 32 ]; then
		gen libxtrans
		compile
	fi

	gen xproto
	compile

	rm -rf $WLROOT/libepoxy/m4
	gen libepoxy
	compile

	gen glproto
	compile

	gen xcmiscproto
	compile

	gen libxtrans
	compile

	gen bigreqsproto
	compile

	gen xextproto
	compile

	gen fontsproto
	compile

	gen videoproto
	compile

	gen recordproto
	compile

	gen resourceproto
	compile

	gen xf86driproto
	compile

	gen randrproto
	compile

	gen libxkbfile
	compile

	gen libXfont
	compile

	echo
	echo "xserver"
	cd $WLROOT/xserver
	./autogen.sh --prefix=$WLD --disable-docs --disable-devel-docs \
		--enable-xwayland --disable-xorg --disable-xvfb --disable-xnest \
		--disable-xquartz --disable-xwin
	compile

	echo
	echo "Paths"
	mkdir -p $WLD/share/X11/xkb/rules
	if [ ! -e $WLD/share/X11/xkb/rules/evdev ]; then
		ln -s /usr/share/X11/xkb/rules/evdev $WLD/share/X11/xkb/rules/
	fi
	if [ ! -e $WLD/bin/xkbcomp ]; then
		ln -s /usr/bin/xkbcomp $WLD/bin/
	fi
fi

echo
echo "weston"
cd $WLROOT/weston
git clean -xfd
./autogen.sh --prefix=$WLD \
	--with-cairo=image \
	--with-xserver-path=$WLD/bin/Xwayland \
	--enable-setuid-install=no \
	--enable-clients \
	--enable-headless-compositor \
	--enable-demo-clients-install
compile
#distcheck

# Set up config file if it isn't there already
if [ ! -e $HOME/.config/weston.ini ]; then
	cp weston.ini $HOME/.config/
fi

cd $WLROOT
