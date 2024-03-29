# Building C/C++ libs for Xcode

The ultimate goal is to have 5 libs that you can import into an Xcode project: libjpeg, libpng, libtiff, liblept, and libtesseract.  To build those, you'll first need to build some tools from GNU.

[`Scripts/Build_All.sh`](./Build_All.sh) makes the GNU tools and the Xcode libs by calling these two scripts, in order:

```none
gnu-tools/Build_All.sh
xcode-libs/Build_All.sh
```

After `Scripts/Build_All.sh` completes, you need to run [`test_tesseract.sh`](./test_tesseract.sh).  It downloads the reqiured language data from the Tesseract project, and then runs the command-line tesseract program with that langauge data against some test images.

After `test_tesseract.sh` completes, with passing image-tests, you can confidently move on to [using the C/C++ libs in Xcode](../iOCR/README.md).

Read on if you want to learn more about the build scripts, and configuring a C/C++ project.

([⬆️ _return to The Guide_](../README.md))

## The build scripts

Above, you saw that the top Build_All script calls two other Build_All scripts, one for the GNU Tools and the other for the Xcode libs.  Those two call a sequence of `build_*.sh` scripts:

```none
gnu-tools/Build_All.sh:    xcode-libs/Build_All.sh:
  1. build_autoconf.sh       5. build_libjpeg.sh
  2. build_automake.sh       6. build_libpng.sh
  3. build_pkgconfig.sh      7. build_libtiff.sh
  4. build_libtool.sh        8. build_leptonica.sh
                             9. build_tesseract.sh
```

Each `build_*.sh` script can download its source from the web, untar it, and start running its config-make-install process to create the tool or the lib.

The build scripts for the GNU tools are very simple.  They only target one architecture, and contain a very short and simple config-make-install process.

The build scrips for the Xcode libs are more complex.  They target multiple architectures, and have a number of config flags/options.  All that would make for a very long script with lots of duplication.  For that reason I split up the build process for each Xcode lib.

The parent `build_name.sh` handles its cleans/donwloads/untars, taking care of the basic groundwork (same as the GNU-tools script).  It then, for each of its targets, exports four env vars and calls its own `config-make-install_name.sh` script.

The config-make-install script reads those four exported env vars, which includes the target's platform/OS and architecture. It then runs the `./configure`, `make`, and `make install` commands.  After each `make install` completes, it uses the `lipo` tool to verify the libs were created with the proper architecture and installed in the correct location.

With all that done, the parent `build_name.sh` script finishes by using `lipo` to combine like libs into a single "fat" lib, for example, joining macos_x86_64 and macos_arm64 into a single 'macos' lib.

### set_env.sh

https://unix.stackexchange.com/questions/126223/practical-usage-of-set-k-option-in-bash
https://unix.stackexchange.com/questions/130985/if-processes-inherit-the-parents-environment-why-do-we-need-export

`set_env.sh` creates all the project-level environment variables that build scripts need to know, like downloading and extracting tarballs, verifying files exist, or setting up folders for all the build targets.  Every build and config script sources `set_env.sh` when it starts up; `test_tesseract.sh` also sources it.

When I need to debug a build process or pathing issue, it helps if I can interact with the environment: calling individual builds, exploring paths, etc...  `./Scripts/set_env.sh` really helps with this.  I made set_env so we can call it directly, too:

```sh
% source Scripts/set_env.sh
(TBE) %
```

It adds that nice `(TBE)` prompt (**T**esseract **B**uild **E**nvironment) to let us know we're ready to start making builds happen.  To see what's available in the TBE, we can call a simple help function:

```none
(TBE) % tbe-help

Directory vars required for config-make-install and build scripts:
$TBE_PROJECTDIR:  /home/user/develop/TesseractBuild
$DOWNLOADS:   /home/user/develop/TesseractBuild/Downloads
$LOGS:        /home/user/develop/TesseractBuild/Logs
$ROOT:        /home/user/develop/TesseractBuild/Root
$SCRIPTSDIR:  /home/user/develop/TesseractBuild/Scripts
$SOURCES      /home/user/develop/TesseractBuild/Sources

Scripts you can run:
$SCRIPTSDIR/Build_All.sh             clean|run all build/configue scripts
$SCRIPTSDIR/gnu-tools/Build_All.sh   clean|run all GNU-prerequisite build scripts
$SCRIPTSDIR/xcode-libs/Build_All.sh  clean|run all Xcode libs build/configue scripts
$SCRIPTSDIR/test_tesseract.sh        after build, run a quick test of tesseract

Functions you can call:
tbe-help                 print this description of the project environment
```

There are many other functions, but they're only meant to be called by the build and config-make-install scripts.



## ZSH things

I designed the scripts for ZSH, which should be available on modern Macs.

Here are some things I've found along the way, developing these scripts:

-   **`$0:A` or `${0:A}`**: to get the absolute pathname of the running script.  From the Unix-StackExchange [Q](https://unix.stackexchange.com/q/76505/366399), there's a comment at the bottom of this [A](https://unix.stackexchange.com/a/115431/366399) comparing `:a` to `:A`, and the accepted [A](https://unix.stackexchange.com/a/136565/366399).

-   **`$functrace`**: (https://zsh.sourceforge.io/Doc/Release/Zsh-Modules.html)

## Intractable issues

I've run into two main issues I can't really resolve and have resorted to hackery:

-   GNU's config.sub and iOS Simulator
-   This arcane `-lrt` linker flag for Tesseract

### config.sub

All the `configure` scripts for _top-level libraries_ run config.sub, which takes a target and produces "a validated and canonicalized configuration type", or, in practical terms:

```sh
./config.sub arm64-apple-ios15.2
aarch64-apple-ios15.2
```

'arm64' was "canonicalized" to 'aarch64'.

That's fine, it doesn't affect the actual build and the flags/opts passed to Clang.  I'm not sure config.sub has any bearing on the built products.  But it's thoroughly a part of these C/C++ libraries, so there's no getting rid of it... and that's very relevant because I've found these two issues using config.sub:

-   all the projects are using a dated version of config.sub
-   even the latest config.sub, which does recognize iOS, doesn't recognize iOS-Simulator

```sh
./config.sub arm64-apple-ios15.2-simulator
Invalid configuration `arm64-apple-ios15.2-simulator': Kernel `ios15.2' not known to work with OS `simulator'.
```

My solution is to download the latest config.sub from GNU and, for now, patch in a hack that allows 'simulator' to be passed through by just cutting it out of the input argument.

[$TBE_PROJECTDIR/Scripts/download_config.sub_and_patch.sh](./download_config.sub_and_patch.sh) handles those three steps.

### `-lrt`

Tesseract's `autogen.sh` or `configure` scripts are adding the linker flag for the RT library.  It's not needed for building in Darwin, and doesn't exist, so when when the flag is added the make/compilation fails when the lib is not found.

I called it "arcane" earlier, based on this StackOverflow from 2019, [ld: library not found for -lrt](https://stackoverflow.com/a/47703372/246801):

> BTW, removing -lrt should also fit for recent Linux distributions.

I have spent hours in the autogen and (espeically) configure scripts trying to see where/how the (pre)configure process determines this is needed.  From everything I see and understand, configure correctly exists thinking this shouldn't be set, but it somehow it's (still) added to Makefile.

My solution is to just comment out the line in the Makefile that adds the flag, after the configure step, but before the make step.  Tesseract's config-make-install script handles this:

```sh
sed 's/am__append_46 = -lrt/# am__append_46 = -lrt/' Makefile > tmp || { echo "Error: could not sed/comment-out '-lrt' flag to tmp file"; exit 1 }
mv tmp Makefile || { echo 'Error: could not move tmp file back on top of Makefile'; exit 1 }
```

## libtiff header

**tiffconf.h** has one value with two different definitions between **arm64** and **x86_64**, and might affect you if you are building for macOS.

```sh
% diff -r Root/ios_arm64/include Root/macos_x86_64/include
diff -r Root/ios_arm64/include/tiffconf.h Root/macos_x86_64/include/tiffconf.h
48c48
< #define HOST_FILLORDER FILLORDER_MSB2LSB
---
> #define HOST_FILLORDER FILLORDER_LSB2MSB
```

From, <https://www.awaresystems.be/imaging/tiff/tifftags/fillorder.html>:

> LibTiff defines these values:
>
> FILLORDER_MSB2LSB = 1;
> FILLORDER_LSB2MSB = 2;
>
> In practice, the use of FillOrder=2 is very uncommon, and is not recommended.

From, <http://www.libtiff.org/internals.html>:

> Native CPU byte order is determined on the fly by the library and does not need to be specified. The HOST_FILLORDER and HOST_BIGENDIAN definitions are not currently used, but may be employed by codecs for optimization purposes.

As **ios_arm64** seems the more important library, by default those headers will be used.

*If you are making a macOS app and have problems linking/referencing the API, consider adjusting this final copy.*

## Troubleshooting

The errors coming out of the configure step can be difficult to understand if you only read the **Step#_config.err** in the **Logs** directory.

The key to debugging configure errors is to check the **config.log** for a given build in that build's **Sources** directory.

Given this error running build_all.sh:

```none
macos_x86_64: configuring... ERROR running ../configure CC=...
...
...
ERROR see ~/$TBE_PROJECTDIR/Logs/tesseract-4.1.1/3_config_macos_x86_64.err for more details
```

Looking at **Logs/tesseract-4.1.1/3_config_macos_x86_64.err**:

```none
configure: error: in `~/$TBE_PROJECTDIR/Sources/tesseract-4.1.1/macos_x86_64':
configure: error: C++ compiler cannot create executables
See `config.log' for more details
```

The last line, *See `config.log' for more details* is the true clue.

Here's the telling error message from **Sources/tesseract-4.1.1/macos_x86_64/config.log**:

```none
...
ld: library not found for -lpng
clang: error: linker command failed with exit code 1 (use -v to see invocation)
...
```

In this case, I had just clobbered all macos_x86_64 binaries/libraries including **macos_x86_64/lib/libpng16.a**.  And this is what `./configure` failed on.

Other "errors" like the following may not really be errors, it's just configure trying out different configurations:

```none
configure:2663: /Applications/Xcode.app/Contents/Developer/usr/bin/g++ -V >&5
clang: error: unsupported option '-V -Wno-objc-signed-char-bool-implicit-int-conversion'
clang: error: no input files
```

and:

```none
configure:2663: /Applications/Xcode.app/Contents/Developer/usr/bin/g++ -qversion >&5
clang: error: unknown argument '-qversion'; did you mean '--version'?
clang: error: no input files
```

## Miscelaneous links

-   (https://kakyoism.github.io/2019/10/17/Build-a-GNU-Autotools-based-project-for-iOS-Part-1/)
-   (https://stackoverflow.com/questions/22986302/compiling-libical-for-arm64-and-x86-64-for-ios)
-   (https://www.gnu.org/software/gettext/manual/html_node/config_002eguess.html)
-   (https://github.com/conan-io/conan/pull/6748)
-   (https://github.com/react-native-community/discussions-and-proposals/issues/295)
-   **AArch64** is the ["ARM 64-bit Architecture"](https://developer.apple.com/documentation/xcode/writing-arm64-code-for-apple-platforms).
