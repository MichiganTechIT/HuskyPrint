# Changelog for HuskyPrint

## unreleased

## v2.5.0.0

- Windows [Issue 43](https://github.com/MichiganTechIT/HuskyPrint/issues/43)
  - Updated `PaperCut` to `22.1.3`
  - Updated `PSADT` to `3.9.3`
  - Updated `Xerox Desktop Print Experience` to `8.110.9.0`
  - Updated Documentation

## v2.4.0.0

- Windows [Issue 41](https://github.com/MichiganTechIT/HuskyPrint/issues/41)
  - Updated `PSADT` to `3.8.4`
  - Updated `Xerox Desktop Print Experience` to `7.250.9.0`

## v2.3.0.0

- Updated `PaperCut` to version `21.0.1` for Windows - [Issue 36](https://github.com/MichiganTechIT/HuskyPrint/issues/36)

## v2.2.0.0

- fixed duplicate ids in workflow - [Issue 34](https://github.com/MichiganTechIT/HuskyPrint/issues/34)
- moved to use `main` as the default branch instead of `master`
- Updated `Xerox Desktop Print Experience` to latest version - [Issue 31](https://github.com/MichiganTechIT/HuskyPrint/issues/31)
- Added github actions to upload assets on release

## Version **2.1.0.0** _[2020/08/28]_

- Added `Xerox Desktop Experience` installation for Windows - [Issue 28](https://github.com/MichiganTechIT/HuskyPrint/issues/28)

## Version **2.0.0.0** _[2020/08/24]_

- Updated for Linux
  - Updated HuskyPrint drivers
  - Updated papercut files to version 19.2.3
- Updated for Windows
  - **Breaking Change** Removed Windows 7 support
  - Updated PSADT files to version 3.8.2 - [Issue 18](https://github.com/MichiganTechIT/HuskyPrint/issues/18)
  - Updated PaperCut installer to version 19.2.3 - [Issue 19](https://github.com/MichiganTechIT/HuskyPrint/issues/19)
- Updated for MacOs
  - Updated Xerox drivers - [Issue 21](https://github.com/MichiganTechIT/HuskyPrint/issues/21)
  - Updated PaperCut to version 19.2.3 - [Issue 21](https://github.com/MichiganTechIT/HuskyPrint/issues/21)

## Version **1.2.1.0** _[2019/09/19]_

- Changed Linux PaperCut configuration file to use unix line endings

## Version **1.2.0.0** _[2019/08/05]_

- Updated PaperCut installer version to 19.0.3
- Updated for Windows
  - Updated PSDAT to version 3.7.0
  - Updated printer drivers
    - Xerox AltaLink C80xx and B80xx versions
      - Class 3 (Windows 7) -> 5.639.3.0
      - Class 4 (Windows 10) -> 7.76.0.0

## Version **1.1.0.0** _[2018/08/31]_

- Updated for Windows
  - Removed printer conversion from legacy servers
  - Updated drivers for husky-color and husky-bw
  - Updated PaperCut version
  - Moved to zip files for drivers and PaperCut installer
- Updated for Mac
  - Initial upload of instal files

## Version **1.0.0.0** _[2017/08/09]_

- Added existing printers to be converted to point to the new servers
- Added Windows 7 support
- Added PaperCut install, and removing previous installation
- Added prompt to ask if PaperCut should autostart
- Added the creation of husky-color and husky-bw printers
